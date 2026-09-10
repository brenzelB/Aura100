import 'dart:async';

import 'package:aura_quest/core/offline/offline_check_in_queue.dart';
import 'package:aura_quest/core/offline/pending_check_in.dart';
import 'package:aura_quest/core/widgets/action_feedback.dart';
import 'package:aura_quest/features/auth/application/auth_providers.dart';
import 'package:aura_quest/features/challenges/application/challenge_providers.dart';
import 'package:aura_quest/features/challenges/data/challenge_repository.dart';
import 'package:aura_quest/features/challenges/domain/blackout.dart';
import 'package:aura_quest/features/challenges/domain/challenge.dart';
import 'package:aura_quest/features/challenges/domain/progress_entry.dart';
import 'package:aura_quest/features/challenges/domain/progress_presets.dart';
import 'package:aura_quest/features/challenges/domain/settlement.dart';
import 'package:aura_quest/features/challenges/domain/weekly_recap.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/quick_progress_actions.dart';
import 'package:aura_quest/features/friends/application/friends_providers.dart';
import 'package:aura_quest/features/home/presentation/screens/home_screen.dart';
import 'package:aura_quest/features/home/application/home_providers.dart';
import 'package:aura_quest/features/home/domain/home_agenda.dart';
import 'package:aura_quest/features/profile/application/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _ownerProvider = StateProvider<String>((ref) => 'alice');

Challenge _quest(
        {double progress = 0, bool daily = false, bool critical = false}) =>
    Challenge(
      id: 'q',
      creatorId: 'alice',
      title: 'Morning movement',
      description: '',
      startsOn: DateTime.now().toUtc(),
      createdAt: DateTime.now().toUtc(),
      durationDays: 30,
      auraGain: 100,
      auraPenalty: 50,
      maxStrikes: critical ? 0 : 2,
      goalType: daily ? GoalType.check : GoalType.progress,
      targetValue: daily ? null : 10,
      unit: daily ? null : 'Reps',
      progressInPeriod: progress,
    );

class _Repository implements ChallengeRepository {
  final calls = <double>[];
  Completer<ProgressResult> reply = Completer<ProgressResult>();
  double total = 0;

  @override
  Future<ProgressResult> addProgress(
      {required String challengeId, required double amount}) async {
    calls.add(amount);
    final result = await reply.future;
    total = result.total;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> _overrides(
  _Repository repo, {
  bool daily = false,
  bool critical = false,
  bool checked = false,
  bool freezeAgenda = false,
  List<SettlementEvent> events = const [],
  Blackout? blackout,
}) =>
    [
      if (freezeAgenda)
        homeAgendaProvider.overrideWith((ref) => HomeAgenda.build(
            challenges: [_quest(daily: daily)],
            checkInsByQuest: const {},
            today: DateTime.now().toUtc())),
      currentUserProvider.overrideWith((ref) => User(
          id: ref.watch(_ownerProvider),
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-09-08T00:00:00Z')),
      currentProfileProvider.overrideWith((ref) => null),
      challengeRepositoryProvider.overrideWithValue(repo),
      myChallengesProvider.overrideWith((ref) =>
          [_quest(progress: repo.total, daily: daily, critical: critical)]),
      myCheckInsProvider.overrideWith((ref) async {
        final quests = await ref.watch(myChallengesProvider.future);
        // Reproduce the real provider's optimistic offline day marker.
        final pending = ref.watch(pendingCheckInsProvider);
        final now = DateTime.now().toUtc();
        final day = DateTime.utc(now.year, now.month, now.day);
        return {
          if (checked ||
              quests.single.progressInPeriod >= 10 ||
              pending.isNotEmpty)
            'q': {day: now},
        };
      }),
      myInvitesProvider.overrideWith((ref) => []),
      friendRequestsProvider.overrideWith((ref) => []),
      incomingDuelsProvider.overrideWith((ref) => []),
      unseenNudgesProvider.overrideWith((ref) => []),
      targetedRoastsProvider.overrideWith((ref) => []),
      robbedNoticesProvider.overrideWith((ref) => []),
      unseenBlackoutsProvider.overrideWith((ref) => []),
      pokeBacksProvider.overrideWith((ref) => []),
      settlementEventsProvider.overrideWith((ref) => events),
      myBlackoutProvider.overrideWith((ref, id) => blackout),
      weeklyRecapProvider.overrideWith((ref) => WeeklyRecap(
          weekStart: DateTime.utc(2026, 8, 31),
          weekEnd: DateTime.utc(2026, 9, 6),
          checkIns: 4,
          activeDays: 3,
          auraGained: 400,
          auraLost: 0,
          strikes: 0,
          questsFinished: 1,
          duelsWon: 0,
          duelsLost: 0,
          previousCheckIns: 2)),
    ];

Future<void> _mount(
  WidgetTester tester,
  _Repository repo, {
  bool home = false,
  double width = 360,
  double scale = 1,
  bool daily = false,
  bool critical = false,
  bool checked = false,
  bool freezeAgenda = false,
  List<SettlementEvent> events = const [],
  Blackout? blackout,
}) async {
  tester.view.physicalSize = Size(width, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: _overrides(repo,
        daily: daily,
        critical: critical,
        checked: checked,
        freezeAgenda: freezeAgenda,
        events: events,
        blackout: blackout),
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: home
          ? const HomeScreen()
          : Scaffold(body: QuickProgressActions(challenge: _quest())),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async => true);
  });
  setUp(() => SharedPreferences.setMockInitialValues({
        'push_prompt_dismissed': true,
        'celebration_acked_at': '2020-01-01T00:00:00Z',
        'loss_roast_acked_at': '2020-01-01T00:00:00Z',
      }));

  test('presets preserve fractional units and reject invalid targets', () {
    expect(progressPresets(10), [1, 2.5, 5]);
    expect(progressPresets(2.5), [0.25, 0.63, 1.5]);
    expect(progressPresets(0.01), [0.01]);
    expect(progressPresets(0), isEmpty);
    expect(progressPresets(double.nan), isEmpty);
  });

  testWidgets('quick action locks all buttons and only shows the server reward',
      (tester) async {
    final repo = _Repository();
    await _mount(tester, repo);
    await tester.tap(find.text('+5'));
    await tester.tap(find.text('+5'));
    await tester.pump();
    expect(repo.calls, [5]);
    expect(
        tester
            .widgetList<OutlinedButton>(find.byType(OutlinedButton))
            .every((b) => b.onPressed == null),
        isTrue);
    expect(find.byType(ConfirmedAuraAmount), findsNothing);
    repo.reply.complete(const ProgressResult(
        total: 10, target: 10, completed: true, overshoot: false, gained: 37));
    await tester.pumpAndSettle();
    expect(find.text('+37 ⚡'), findsOneWidget);
    expect(find.text('+100 ⚡'), findsNothing);
    expect(find.text('Goal reached · 10 Reps'), findsOneWidget);
  });

  testWidgets('failure exposes retry without awarding aura', (tester) async {
    final repo = _Repository();
    await _mount(tester, repo);
    await tester.tap(find.text('+1'));
    repo.reply.completeError(
        const PostgrestException(message: 'Connection lost. Try again.'));
    await tester.pumpAndSettle();
    expect(find.text('Connection lost. Try again.'), findsOneWidget);
    expect(find.byType(ConfirmedAuraAmount), findsNothing);
    repo.reply = Completer<ProgressResult>();
    await tester.tap(find.text('+1'));
    expect(repo.calls, [1, 1]);
    repo.reply.complete(const ProgressResult(
        total: 1,
        target: 10,
        completed: false,
        overshoot: false,
        gained: null));
    await tester.pumpAndSettle();
  });

  testWidgets('a reply from the previous account does not show a reward',
      (tester) async {
    final repo = _Repository();
    await _mount(tester, repo);
    await tester.tap(find.text('+5'));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(QuickProgressActions)));
    container.read(_ownerProvider.notifier).state = 'bob';
    await tester.pump();
    repo.reply.complete(const ProgressResult(
        total: 10, target: 10, completed: true, overshoot: false, gained: 100));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(ConfirmedAuraAmount), findsNothing);
  });

  testWidgets('active blackout has no quick action bypass', (tester) async {
    final repo = _Repository();
    await _mount(tester, repo,
        blackout: Blackout(
            id: 'b',
            challengeId: 'q',
            attackerId: 'bob',
            targetId: 'alice',
            daypart: 'morning',
            startsAt: DateTime.now().subtract(const Duration(minutes: 1)),
            endsAt: DateTime.now().add(const Duration(hours: 1)),
            cost: 200));
    expect(find.byType(OutlinedButton), findsNothing);
    expect(repo.calls, isEmpty);
  });

  for (final critical in [false, true]) {
    testWidgets(
        'Today remains actionable at 320px and large text (critical=$critical)',
        (tester) async {
      await _mount(tester, _Repository(),
          home: true, width: 320, scale: 1.6, critical: critical);
      expect(tester.takeException(), isNull);
      expect(find.text('+1').hitTestable(), findsOneWidget);
      expect(find.text('Finish (10)').hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(find.text('TODAY')).dy,
          lessThan(tester.getTopLeft(find.text('ACTIVITY')).dy));
      expect(find.text('LAST WEEK'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'Home updates the remainder in place and confirms a completed quest',
      (tester) async {
    final repo = _Repository();
    await _mount(tester, repo, home: true);
    await tester.tap(find.text('+5'));
    repo.reply.complete(const ProgressResult(
        total: 5,
        target: 10,
        completed: false,
        overshoot: false,
        gained: null));
    await tester.pumpAndSettle();
    expect(find.text('Finish (5)'), findsOneWidget);
    expect(find.text('5 / 10 Reps'), findsOneWidget);
    expect(find.byType(ConfirmedAuraAmount), findsNothing);
    repo.reply = Completer<ProgressResult>();
    await tester.tap(find.text('Finish (5)'));
    repo.reply.complete(const ProgressResult(
        total: 10, target: 10, completed: true, overshoot: false, gained: 100));
    await tester.pumpAndSettle();
    expect(repo.calls, [5, 5]);
    expect(find.text('+100 ⚡'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('Finish (5)'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pending check-in is saved but not counted as confirmed',
      (tester) async {
    final now = DateTime.now().toUtc();
    const queue = OfflineCheckInQueue(userId: 'alice');
    await queue.enqueue(PendingCheckIn(
        challengeId: 'q',
        questTitle: 'Morning movement',
        timestamp: now,
        date: DateTime.utc(now.year, now.month, now.day)));
    // The agenda still holds its last server snapshot while offline reads wait.
    await _mount(tester, _Repository(),
        home: true, daily: true, freezeAgenda: true);
    expect(find.text('0/1'), findsOneWidget);
    expect(find.text('Waiting to sync'), findsOneWidget);
    expect(find.text('All check-ins done. Come back tomorrow.'), findsNothing);
    expect(find.byType(ConfirmedAuraAmount), findsNothing);
    expect(find.text('CHECK-IN'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'an event with a hidden quest remains readable without a broken link',
      (tester) async {
    final event = SettlementEvent.fromJson({
      'kind': 'failed',
      'amount': 50,
      'challenge_id': 'old',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'challenges': null,
    });
    expect(event.canOpenQuest, isFalse);
    await _mount(tester, _Repository(), home: true, events: [event]);
    await tester.ensureVisible(find.text('ACTIVITY'));
    await tester.tap(find.text('ACTIVITY'));
    await tester.pumpAndSettle();
    final eventRow = find.textContaining('Unavailable quest');
    await tester.ensureVisible(eventRow);
    await tester.tap(eventRow);
    await tester.pumpAndSettle();
    expect(
        find.text('This quest is no longer available to you.'), findsOneWidget);
    expect(find.text('OPEN QUEST'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('events do not interrupt Home and celebration opens on demand',
      (tester) async {
    final event = SettlementEvent(
        kind: 'completed',
        amount: 100,
        challengeId: 'old',
        questTitle: 'Finished quest',
        createdAt: DateTime.now().toUtc());
    await _mount(tester, _Repository(), home: true, events: [event]);
    expect(find.byType(Dialog), findsNothing);
    expect(find.textContaining('Finished quest'), findsNothing);
    await tester.ensureVisible(find.text('ACTIVITY'));
    await tester.tap(find.text('ACTIVITY'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'Activity must fit the viewport');
    final eventRow = find.textContaining('Finished quest');
    await tester.ensureVisible(eventRow);
    await tester.tap(eventRow);
    await tester.pumpAndSettle();
    expect(find.text('QUEST COMPLETE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'pending feedback has no reward or success haptic; reduced motion shows the final confirmed amount',
      (tester) async {
    final messenger = GlobalKey<ScaffoldMessengerState>();
    final haptics = <MethodCall>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: messenger,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: const Scaffold()));
    showActionFeedback(messenger.currentState!,
        message: 'Waiting to sync', pending: true, confirmedAura: 100);
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmedAuraAmount), findsNothing);
    expect(haptics, isEmpty);
    messenger.currentState!.removeCurrentSnackBar();
    showActionFeedback(messenger.currentState!,
        message: 'Confirmed', confirmedAura: 100);
    await tester.pump();
    expect(find.text('+100 ⚡'), findsOneWidget);
    expect(haptics.single.arguments, 'HapticFeedbackType.lightImpact');
  });
}
