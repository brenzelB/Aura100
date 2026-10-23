import 'package:aura_quest/core/theme/app_colors.dart';
import 'package:aura_quest/core/theme/app_theme.dart';
import 'package:aura_quest/features/auth/application/auth_providers.dart';
import 'package:aura_quest/features/auth/presentation/screens/login_screen.dart';
import 'package:aura_quest/features/challenges/data/quest_draft_store.dart';
import 'package:aura_quest/features/challenges/domain/challenge.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/create_challenge_sheet.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/slip_widgets.dart';
import 'package:aura_quest/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:aura_quest/features/friends/application/friends_providers.dart';
import 'package:aura_quest/features/home/application/activity_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final user = User(
    id: 'draft-owner',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-10-23T00:00:00Z');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    AppColors.apply(AppThemeType.neoBrutalist, AppThemeMode.light);
  });
  tearDown(
      () => AppColors.apply(AppThemeType.neoBrutalist, AppThemeMode.light));

  test('drafts survive a new store but cannot cross accounts or clearing',
      () async {
    final store = QuestDraftStore();
    final pending =
        store.save('alice', {'title': 'Read every day', 'unit': 'Pages'});
    final cleared = store.clear('alice');
    await Future.wait([pending, cleared]);
    expect(await QuestDraftStore().load('alice'), isNull);
    await store.save('alice', {'title': 'New draft'});
    expect((await QuestDraftStore().load('alice'))?['title'], 'New draft');
    expect(await store.load('bob'), isNull);
  });

  test('invalid or future draft formats are safely ignored', () async {
    SharedPreferences.setMockInitialValues({
      'quest_draft_v1:broken': '{',
      'quest_draft_v1:newer': '{"version":2,"title":"Not ours"}',
    });
    expect(await QuestDraftStore().load('broken'), isNull);
    expect(await QuestDraftStore().load('newer'), isNull);
  });

  test('safe and near-limit slip text contrast meets 4.5 in every appearance',
      () {
    final now = DateTime.now().toUtc();
    for (final theme in AppThemeType.values) {
      for (final mode in AppThemeMode.values) {
        AppColors.apply(theme, mode);
        for (final slips in [0, 1]) {
          final quest = Challenge(
              id: 'q',
              creatorId: 'a',
              title: 'Less scrolling',
              description: '',
              durationDays: 7,
              auraGain: 100,
              auraPenalty: 25,
              maxStrikes: 3,
              startsOn: now,
              createdAt: now,
              goalType: GoalType.avoid,
              dailyAllowance: 2,
              slipsInPeriod: slips);
          final ink = slipColor(quest).computeLuminance();
          final bg = AppColors.surface.computeLuminance();
          final ratio =
              ((ink > bg ? ink : bg) + .05) / ((ink > bg ? bg : ink) + .05);
          expect(ratio, greaterThanOrEqualTo(4.5),
              reason: '$theme/$mode/$slips');
        }
      }
    }
  });

  testWidgets('quest steps validate, keep inputs, and restore an account draft',
      (tester) async {
    Future<void> mount() async {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(user),
            myFriendsProvider.overrideWith((ref) => []),
          ],
          child: MaterialApp(
              theme:
                  AppTheme.build(AppThemeType.neoBrutalist, AppThemeMode.light),
              home: const Scaffold(body: CreateChallengeSheet()))));
      await tester.pumpAndSettle();
    }

    await mount();
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('Give your quest a name'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Quest name'), 'Read at lunch');
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 3 · Your rhythm'), findsOneWidget);
    expect(find.text('BALANCE'), findsNothing);
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('CREATE QUEST'), findsOneWidget);
    await tester.ensureVisible(find.text('BALANCE'));
    expect(find.text('Classic'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await mount();
    expect(find.text('Read at lunch'), findsOneWidget);
    expect(find.textContaining('Draft restored.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'editorial sign-in methods are above email without duplicate branding',
      (tester) async {
    AppColors.apply(AppThemeType.editorial, AppThemeMode.light);
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: AppTheme.build(AppThemeType.editorial, AppThemeMode.light),
            home: const LoginScreen())));
    await tester.pumpAndSettle();
    expect(find.text('AURA\nQUEST'), findsNothing);
    expect(
        tester.getTopLeft(find.text('CONTINUE WITH GOOGLE')).dy,
        lessThan(
            tester.getTopLeft(find.widgetWithText(TextFormField, 'Email')).dy));
    expect(tester.getBottomLeft(find.text('CONTINUE WITH GOOGLE')).dy,
        lessThan(780));
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1000.0]) {
    testWidgets(
        'navigation adapts at $width and retains branch state and badges',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(initialLocation: '/home', routes: [
        StatefulShellRoute.indexedStack(
            builder: (_, __, shell) => DashboardShell(navigationShell: shell),
            branches: [
              for (final route in ['home', 'quests', 'friends', 'profile'])
                StatefulShellBranch(routes: [
                  GoRoute(
                      path: '/$route',
                      builder: (_, __) => Scaffold(
                          appBar: AppBar(title: Text('Screen $route')),
                          body: const TextField(
                              decoration:
                                  InputDecoration(labelText: 'Kept input'))))
                ]),
            ]),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(overrides: [
        activitySummaryProvider
            .overrideWithValue(const ActivitySummary(count: 3, invitations: 1)),
      ], child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail),
          width >= 840 ? findsOneWidget : findsNothing);
      expect(find.byType(NavigationBar),
          width < 840 ? findsOneWidget : findsNothing);
      expect(find.byType(Badge), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'Keep me');
      await tester.tap(find.text('Quests').last);
      await tester.pumpAndSettle();
      expect(find.text('Screen quests'), findsOneWidget);
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(find.text('Keep me'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
