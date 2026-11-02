import 'package:aura_quest/core/text/durations.dart';
import 'package:aura_quest/features/challenges/application/challenge_providers.dart';
import 'package:aura_quest/features/challenges/domain/challenge.dart';
import 'package:aura_quest/features/challenges/domain/clock_session.dart';
import 'package:aura_quest/features/challenges/domain/progress_entry.dart';
import 'package:aura_quest/features/challenges/presentation/quest_amount.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/quick_progress_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CLOCK quests: a stopwatch fills a progress quest.
///
/// The thing most likely to break here is not the timer — it is the
/// FORMATTING. A clock quest stores minutes, so every number that
/// reaches a player has to be converted. One missed call site shows
/// "970" where "16h 10m" belongs, and nothing crashes to tell you.
Challenge _quest({
  bool clock = true,
  double target = 960, // 16h
  double progress = 0,
  CheckinPeriod period = CheckinPeriod.daily,
}) =>
    Challenge(
      id: 'q',
      creatorId: 'u',
      title: 'Fasting',
      description: '',
      durationDays: 30,
      auraGain: 100,
      auraPenalty: 50,
      maxStrikes: 1,
      startsOn: DateTime.utc(2026, 11, 1),
      createdAt: DateTime.utc(2026, 11, 1),
      checkinPeriod: period,
      goalType: GoalType.progress,
      tracking: clock ? QuestTracking.clock : QuestTracking.manual,
      targetValue: target,
      unit: clock ? 'min' : 'Reps',
      progressInPeriod: progress,
    );

void main() {
  group('formatMinutes', () {
    test('reads as hours and minutes, never as a raw count', () {
      expect(formatMinutes(960), '16h 00m');
      expect(formatMinutes(970), '16h 10m');
      expect(formatMinutes(45), '45m');
      expect(formatMinutes(0), '0m');
    });

    test('hours keep counting past a day', () {
      // A 36-hour fast is spoken of as 36 hours, not "1d 12h".
      expect(formatMinutes(36 * 60), '36h 00m');
    });

    test('nothing and nonsense degrade to zero rather than throwing', () {
      expect(formatMinutes(-5), '0m');
      expect(formatMinutes(double.nan), '0m');
      expect(formatMinutes(double.infinity), '0m');
    });
  });

  group('formatStopwatch', () {
    test('pads to a stable width so the readout does not jump', () {
      expect(formatStopwatch(const Duration(seconds: 8)), '00:00:08');
      expect(
          formatStopwatch(const Duration(hours: 14, minutes: 22, seconds: 8)),
          '14:22:08');
    });

    test('a clock running past a day keeps growing, not wrapping', () {
      expect(formatStopwatch(const Duration(hours: 30)), '30:00:00');
    });

    test('a negative span (a skewed clock) shows zero, not a minus', () {
      expect(formatStopwatch(const Duration(seconds: -30)), '00:00:00');
    });
  });

  test('splitMinutes feeds the hours/minutes pickers', () {
    expect(splitMinutes(970), (hours: 16, minutes: 10));
    expect(splitMinutes(0), (hours: 0, minutes: 0));
    expect(splitMinutes(-9), (hours: 0, minutes: 0));
  });

  group('QuestTracking', () {
    test('rows written before clock quests existed stay manual', () {
      expect(QuestTracking.fromDb(null), QuestTracking.manual);
      expect(QuestTracking.fromDb('manual'), QuestTracking.manual);
      expect(QuestTracking.fromDb('clock'), QuestTracking.clock);
      // Anything unexpected must not become a clock by accident.
      expect(QuestTracking.fromDb('stopwatch'), QuestTracking.manual);
    });

    test('a clock quest is still a progress quest to the engine', () {
      final quest = _quest();
      expect(quest.isClock, isTrue);
      expect(quest.isProgress, isTrue,
          reason: 'the whole point is that add_progress still applies');
      expect(quest.goalType, GoalType.progress);
    });

    test('survives a JSON round trip from the database', () {
      final quest = Challenge.fromJson({
        'id': 'q',
        'creator_id': 'u',
        'title': 'Fasting',
        'description': '',
        'duration_days': 30,
        'aura_gain': 100,
        'aura_penalty': 50,
        'max_strikes': 1,
        'starts_on': '2026-11-01',
        'created_at': '2026-11-01T00:00:00Z',
        'goal_type': 'progress',
        'tracking': 'clock',
        'target_value': 960,
        'unit': 'min',
      });
      expect(quest.isClock, isTrue);
      expect(quest.copyWith(progressInPeriod: 10).isClock, isTrue,
          reason: 'copyWith must not quietly drop the input mode');
    });
  });

  group('amounts are written as time, not as minutes', () {
    test('a clock quest never prints its unit', () {
      final quest = _quest(progress: 750);
      expect(quest.amount(750), '12h 30m');
      expect(quest.amountWithUnit(750), '12h 30m');
      expect(quest.addedLabel(45), '+45m');
      expect(quest.progressLabel(750, 960), '12h 30m / 16h 00m');
      expect(quest.amountWithUnit(750), isNot(contains('min')));
    });

    test('a hand-typed progress quest is untouched', () {
      final quest = _quest(clock: false, target: 100, progress: 72);
      expect(quest.amount(72), '72');
      expect(quest.amountWithUnit(72), '72 Reps');
      expect(quest.addedLabel(20), '+20 Reps');
      expect(quest.progressLabel(72, 100), '72 / 100 Reps');
    });
  });

  group('ClockSession', () {
    final started = DateTime.utc(2026, 11, 2, 20);

    test('an open session is running and measures against now', () {
      final session = ClockSession(
          id: 's', challengeId: 'q', userId: 'u', startedAt: started);
      expect(session.isRunning, isTrue);
      expect(session.elapsed(DateTime.utc(2026, 11, 3, 14)),
          const Duration(hours: 18));
      expect(session.minutesAt(DateTime.utc(2026, 11, 3, 14)), 1080);
    });

    test('a closed session ignores the clock entirely', () {
      final session = ClockSession(
        id: 's',
        challengeId: 'q',
        userId: 'u',
        startedAt: started,
        endedAt: DateTime.utc(2026, 11, 3, 14),
      );
      expect(session.isRunning, isFalse);
      // Whatever "now" is, a finished session is as long as it was.
      expect(
          session.elapsed(DateTime.utc(2027, 1, 1)), const Duration(hours: 18));
    });
  });

  test('ProgressTotals answers "how long today" as well as week and month', () {
    final now = DateTime(2026, 11, 2, 12); // a Monday
    final periodStart = DateTime.utc(2026, 11, 2);
    ProgressEntry at(DateTime when, double amount) => ProgressEntry(
        id: '$when', amount: amount, periodStart: periodStart, createdAt: when);

    final totals = ProgressTotals.from([
      at(now, 960), // today
      // Yesterday was a Sunday: inside the month, outside the week,
      // which is exactly the boundary worth pinning down.
      at(now.subtract(const Duration(days: 1)), 900),
      at(now.subtract(const Duration(days: 40)), 800), // earlier month
    ], now);

    expect(totals.today, 960);
    expect(totals.thisWeek, 960, reason: 'the week starts on this Monday');
    expect(totals.thisMonth, 1860);
    expect(totals.lifetime, 2660);
  });

  group('the card offers a clock instead of a keypad', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    Future<void> pump(WidgetTester tester, List<Override> overrides) async {
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: Scaffold(body: QuickProgressActions(challenge: _quest())),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('with no clock running, the only action is to start one',
        (tester) async {
      await pump(tester, [
        openClockSessionProvider('q').overrideWith((ref) async => null),
      ]);

      expect(find.text('START THE CLOCK'), findsOneWidget);
      // The amount shortcuts belong to typed quests only.
      expect(find.textContaining('Finish ('), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a running clock shows the elapsed time and a way to stop',
        (tester) async {
      await pump(tester, [
        openClockSessionProvider('q').overrideWith((ref) async => ClockSession(
              id: 's',
              challengeId: 'q',
              userId: 'u',
              startedAt: DateTime.now()
                  .toUtc()
                  .subtract(const Duration(hours: 2, minutes: 5, seconds: 30)),
            )),
      ]);

      expect(find.text('CLOCK RUNNING'), findsOneWidget);
      expect(find.text('STOP'), findsOneWidget);
      expect(find.text('START THE CLOCK'), findsNothing);
      // Two hours in, the readout has to say so.
      expect(find.textContaining('02:05:'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'a clock left running for a day says so rather than counting on',
        (tester) async {
      await pump(tester, [
        openClockSessionProvider('q').overrideWith((ref) async => ClockSession(
              id: 's',
              challengeId: 'q',
              userId: 'u',
              startedAt:
                  DateTime.now().toUtc().subtract(const Duration(hours: 26)),
            )),
      ]);

      expect(find.textContaining('Running for over a day'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
