import 'package:aura_quest/core/theme/app_colors.dart';
import 'package:aura_quest/core/theme/app_theme.dart';
import 'package:aura_quest/core/theme/design_tokens.dart';
import 'package:aura_quest/core/theme/motion.dart';
import 'package:aura_quest/core/widgets/app_states.dart';
import 'package:aura_quest/core/widgets/theme_scope.dart';
import 'package:aura_quest/features/auth/application/auth_providers.dart';
import 'package:aura_quest/features/auth/presentation/screens/login_screen.dart';
import 'package:aura_quest/features/challenges/application/challenge_providers.dart';
import 'package:aura_quest/features/challenges/presentation/screens/challenges_screen.dart';
import 'package:aura_quest/features/challenges/presentation/screens/challenge_detail_screen.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/challenge_shop_sheet.dart';
import 'package:aura_quest/features/challenges/domain/challenge.dart';
import 'package:aura_quest/features/challenges/domain/benefit.dart';
import 'package:aura_quest/features/challenges/domain/duel.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/dice_duel.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/quest_party_section.dart';
import 'package:aura_quest/features/friends/domain/social_models.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/create_challenge_sheet.dart';
import 'package:aura_quest/features/friends/application/friends_providers.dart';
import 'package:aura_quest/features/friends/presentation/screens/friends_screen.dart';
import 'package:aura_quest/features/profile/application/profile_providers.dart';
import 'package:aura_quest/features/profile/data/profile_repository.dart';
import 'package:aura_quest/features/profile/domain/profile.dart';
import 'package:aura_quest/features/profile/presentation/widgets/emoji_picker_sheet.dart';
import 'package:aura_quest/features/profile/presentation/screens/profile_screen.dart';
import 'package:aura_quest/features/profile/presentation/widgets/notification_settings_section.dart';
import 'package:aura_quest/features/home/presentation/screens/home_screen.dart';
import 'package:aura_quest/features/home/application/home_providers.dart';
import 'package:aura_quest/features/home/domain/home_agenda.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ProfileRepo implements ProfileRepository {
  @override
  String? get currentEmail => 'tester@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Challenge _quest() => Challenge(
    id: 'q',
    creatorId: 'a',
    title: 'Morning movement',
    description: 'Make time for yourself.',
    startsOn: DateTime.now().toUtc(),
    createdAt: DateTime.now().toUtc(),
    durationDays: 30,
    auraGain: 100,
    auraPenalty: 25,
    maxStrikes: 3,
    myAura: 200);

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (_) async => true);
  });
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('Neo text and status foregrounds remain readable in both modes', () {
    for (final mode in AppThemeMode.values) {
      final p = paletteFor(AppThemeType.neoBrutalist, mode);
      for (final fill in [p.background, p.surface]) {
        for (final ink in [
          p.textPrimary,
          p.textSecondary,
          p.accentText,
          p.successText,
          p.warningText,
          p.danger
        ]) {
          expect(contrast(ink, fill), greaterThanOrEqualTo(4.5),
              reason: '$mode $ink on $fill');
        }
      }
      for (final fill in [
        p.neonCyan,
        p.neonPink,
        p.neonPurple,
        p.neonGreen,
        p.danger
      ]) {
        expect(contrast(readableOn(fill), fill), greaterThanOrEqualTo(4.5));
      }
    }
  });

  for (final mode in AppThemeMode.values) {
    for (final scale in [1.0, 1.6]) {
      for (final (label, page) in <(String, Widget)>[
        ('login', const LoginScreen()),
        ('quests', const ChallengesScreen()),
        ('populated quests', const ChallengesScreen()),
        (
          'avatar',
          const Scaffold(
              body:
                  EmojiPickerSheet(initialEmoji: '⚡', username: 'Test player'))
        ),
        ('friends', const FriendsScreen()),
        ('profile', const ProfileScreen()),
        ('create', const Scaffold(body: CreateChallengeSheet())),
        ('home', const HomeScreen()),
        ('detail', const ChallengeDetailScreen(challengeId: 'q')),
        (
          'duel',
          Scaffold(
              body: DuelSheet(
                  duel: IncomingDuel(
                      id: 'd',
                      questTitle: 'Morning movement',
                      challengerName: 'Test challenger',
                      challengerAvatar: null,
                      stake: 50,
                      createdAt: DateTime(2026))))
        ),
        ('shop', Scaffold(body: ChallengeShopSheet(challenge: _quest()))),
      ]) {
        testWidgets('$label at 320px / $mode / text $scale', (tester) async {
          final errorHandler = FlutterError.onError;
          FlutterError.onError = (details) {
            FlutterError.dumpErrorToConsole(details, forceReport: true);
            errorHandler?.call(details);
          };
          addTearDown(() => FlutterError.onError = errorHandler);
          SharedPreferences.setMockInitialValues(
              {'selected_theme': 0, 'selected_theme_mode': mode.index});
          AppColors.apply(AppThemeType.neoBrutalist, mode);
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(ProviderScope(
              overrides: [
                currentUserProvider.overrideWithValue(null),
                myChallengesProvider.overrideWith((ref) => [
                      'home',
                      'detail',
                      'shop',
                      'populated quests'
                    ].contains(label)
                        ? [_quest()]
                        : []),
                myCheckInsProvider.overrideWith((ref) => {}),
                checkInsProvider.overrideWith((ref, id) => {}),
                questMembersProvider.overrideWith((ref, id) => []),
                questDuelsProvider.overrideWith((ref, id) => []),
                questActivityProvider.overrideWith((ref, id) => []),
                questReminderProvider.overrideWith((ref, id) => null),
                benefitsProvider.overrideWith((ref, id) => [
                      const Benefit(
                          id: 'b',
                          challengeId: 'q',
                          title: 'Streak Shield',
                          description: 'Absorbs one missed unit.',
                          cost: 100)
                    ]),
                myBlackoutProvider.overrideWith((ref, id) => null),
                incomingDuelsProvider.overrideWith((ref) => []),
                unseenNudgesProvider.overrideWith((ref) => []),
                targetedRoastsProvider.overrideWith((ref) => []),
                robbedNoticesProvider.overrideWith((ref) => []),
                unseenBlackoutsProvider.overrideWith((ref) => []),
                pokeBacksProvider.overrideWith((ref) => []),
                settlementEventsProvider.overrideWith((ref) => []),
                weeklyRecapProvider.overrideWith((ref) => null),
                myFriendsProvider.overrideWith((ref) => []),
                friendRequestsProvider.overrideWith((ref) => []),
                myInvitesProvider.overrideWith((ref) => []),
                myNudgesProvider.overrideWith((ref) => []),
                profileRepositoryProvider.overrideWithValue(_ProfileRepo()),
                currentProfileProvider.overrideWith((ref) => Profile(
                    id: 'a',
                    username: 'Test player',
                    createdAt: DateTime(2026))),
                myStatsProvider.overrideWith((ref) => const PlayerStats(
                    questsJoined: 4,
                    activeQuests: 2,
                    totalCheckins: 30,
                    totalAura: 1200,
                    gearOwned: 3,
                    friends: 2,
                    lifetimeXp: 1200)),
                trophiesProvider.overrideWith((ref) => []),
                activityByDayProvider.overrideWith((ref) => {}),
                questRemindersProvider.overrideWith((ref) => {}),
                notificationSettingsProvider
                    .overrideWith((ref) => const NotificationSettings()),
              ],
              child: MaterialApp(
                  theme: AppTheme.build(AppThemeType.neoBrutalist, mode),
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(scale),
                          disableAnimations: true),
                      child: child!),
                  home: page)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final scroll = find.byType(Scrollable).first;
          for (var i = 0; i < (label == 'create' ? 12 : 8); i++) {
            await tester.drag(scroll, const Offset(0, -500));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  testWidgets('pressable responds to keyboard with reduced motion',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: Scaffold(
            body: Pressable(
                onTap: () => tapped++, child: const Text('Open quest')))));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(tapped, 1);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        Duration.zero);
  });
  testWidgets('changing appearance keeps the open input draft', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            home: ThemeScope(builder: (_) => Scaffold(body: TextField())))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Keep this draft');
    container.read(themeProvider.notifier).setMode(AppThemeMode.dark);
    await tester.pumpAndSettle();
    expect(find.text('Keep this draft'), findsOneWidget);
  });
  testWidgets('long confirmation remains actionable above the keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => AppDialog(
                                title: const Text('Reset life stats?'),
                                content: Text('Long explanation. ' * 50),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('CANCEL'))
                                ])),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('CANCEL').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('activity badge highlights pending quest invites',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppColors.apply(AppThemeType.neoBrutalist, AppThemeMode.light);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          currentProfileProvider.overrideWith((ref) => Profile(
              id: 'a', username: 'Test player', createdAt: DateTime(2026))),
          homeAgendaProvider.overrideWith((ref) async =>
              const HomeAgenda(open: [], done: [], upcoming: [])),
          myChallengesProvider.overrideWith((ref) => []),
          myCheckInsProvider.overrideWith((ref) => {}),
          myInvitesProvider.overrideWith((ref) => [
                QuestInvite(
                    id: 'invite',
                    questTitle: 'Morning movement',
                    inviterName: 'friend',
                    createdAt: DateTime(2026))
              ]),
          friendRequestsProvider.overrideWith((ref) => []),
          incomingDuelsProvider.overrideWith((ref) => []),
          unseenNudgesProvider.overrideWith((ref) => []),
          targetedRoastsProvider.overrideWith((ref) => []),
          robbedNoticesProvider.overrideWith((ref) => []),
          unseenBlackoutsProvider.overrideWith((ref) => []),
          pokeBacksProvider.overrideWith((ref) => []),
          settlementEventsProvider.overrideWith((ref) => []),
          weeklyRecapProvider.overrideWith((ref) => null),
        ],
        child: MaterialApp(
            theme:
                AppTheme.build(AppThemeType.neoBrutalist, AppThemeMode.light),
            home: const HomeScreen())));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity-unread-badge')), findsOneWidget);
    expect(find.bySemanticsLabel('1 new activities'), findsOneWidget);
    expect(find.text('1 to review · invites, friends and quest events'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quest invite dialog renders its content', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppColors.apply(AppThemeType.neoBrutalist, AppThemeMode.light);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          myFriendsProvider.overrideWith((ref) => []),
          questMembersProvider.overrideWith((ref, id) => []),
        ],
        child: MaterialApp(
          theme: AppTheme.build(AppThemeType.neoBrutalist, AppThemeMode.light),
          home: Scaffold(body: QuestPartySection(challenge: _quest())),
        )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('INVITE'));
    await tester.pumpAndSettle();
    expect(find.text('INVITE A FRIEND'), findsOneWidget);
    expect(find.text('OR BY USERNAME'), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);
  });

  testWidgets('quest invite dialog renders friend choices', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppColors.apply(AppThemeType.neoBrutalist, AppThemeMode.light);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          myFriendsProvider.overrideWith((ref) => [
                Friend(
                    userId: 'friend',
                    username: 'friend',
                    friendsSince: DateTime(2026))
              ]),
          questMembersProvider.overrideWith((ref, id) => []),
        ],
        child: MaterialApp(
          theme: AppTheme.build(AppThemeType.neoBrutalist, AppThemeMode.light),
          home: Scaffold(body: QuestPartySection(challenge: _quest())),
        )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('INVITE'));
    await tester.pumpAndSettle();
    expect(find.text('INVITE A FRIEND'), findsOneWidget);
    expect(find.text('@friend'), findsOneWidget);
    expect(find.text('OR BY USERNAME'), findsOneWidget);
  });
}
