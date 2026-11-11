import 'package:aura_quest/core/text/dates.dart';
import 'package:aura_quest/core/text/server_message.dart';
import 'package:aura_quest/features/challenges/application/challenge_providers.dart';
import 'package:aura_quest/features/challenges/domain/challenge.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/clock_controls.dart';
import 'package:aura_quest/features/friends/domain/social_models.dart';
import 'package:aura_quest/features/home/domain/home_agenda.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// Regressions for the fixes from the 2026-11-09 app review.

const _everyDay = [1, 2, 3, 4, 5, 6, 7];

Challenge _quest({
  String id = 'q',
  List<int> weekdays = _everyDay,
  DateTime? startsOn,
  bool clock = false,
}) =>
    Challenge(
      id: id,
      creatorId: 'u',
      title: 'Quest $id',
      description: '',
      durationDays: 30,
      auraGain: 100,
      auraPenalty: 25,
      maxStrikes: 3,
      startsOn: startsOn ?? DateTime.utc(2026, 7, 1),
      createdAt: DateTime.utc(2026, 7, 1),
      activeWeekdays: weekdays,
      goalType: clock ? GoalType.progress : GoalType.check,
      tracking: clock ? QuestTracking.clock : QuestTracking.manual,
      targetValue: clock ? 60 : null,
      unit: clock ? 'min' : null,
    );

void main() {
  group('serverMessage', () {
    test('passes a game-rule message from the server through', () {
      const error = PostgrestException(
          message: 'This quest is paused today.', code: 'P0001');
      expect(serverMessage(error, 'fallback'), 'This quest is paused today.');
    });

    test('hides technical database errors behind the fallback', () {
      const error = PostgrestException(
          message: 'duplicate key value violates unique constraint',
          code: '23505');
      expect(serverMessage(error, 'Could not save.'), 'Could not save.');
    });

    test('anything that is not a server error uses the fallback', () {
      expect(serverMessage(StateError('boom'), 'Try again.'), 'Try again.');
      expect(serverMessage(null, 'Try again.'), 'Try again.');
    });
  });

  group('home agenda on a rest day', () {
    // 2026-07-15 is a Wednesday (ISO 3).
    final wednesday = DateTime.utc(2026, 7, 15);

    test('a quest resting today is counted, not dropped', () {
      final agenda = HomeAgenda.build(
        challenges: [
          _quest(id: 'rest', weekdays: const [1, 2, 4, 5]),
        ],
        checkInsByQuest: const {},
        today: wednesday,
      );

      expect(agenda.open, isEmpty);
      expect(agenda.resting.single.id, 'rest');
      expect(agenda.hasAnyQuest, isTrue);
    });

    test('an upcoming quest still shows on a rest day', () {
      final agenda = HomeAgenda.build(
        challenges: [
          _quest(
              id: 'soon',
              weekdays: const [1],
              startsOn: DateTime.utc(2026, 7, 20)),
        ],
        checkInsByQuest: const {},
        today: wednesday,
      );

      expect(agenda.upcoming.single.id, 'soon');
      expect(agenda.hasAnyQuest, isTrue);
    });

    test('no quests at all is the only case that says so', () {
      final agenda = HomeAgenda.build(
        challenges: const [],
        checkInsByQuest: const {},
        today: wednesday,
      );
      expect(agenda.hasAnyQuest, isFalse);
    });
  });

  group('QuestInvite.describe', () {
    test('names what joining commits to', () {
      final rules = QuestInvite.describe({
        'mode': 'coop',
        'duration_days': 30,
        'is_endless': false,
        'checkin_period': 'weekly',
        'checkins_per_period': 3,
        'goal_type': 'check',
        'aura_penalty': 50,
        'max_strikes': 1,
      });
      expect(
          rules,
          'CO-OP · everyone pays for a miss · 30 days · 3x a week · '
          '-50 Aura per miss · 1 strike allowed');
    });

    test('a stopwatch quest without an end says so', () {
      final rules = QuestInvite.describe({
        'mode': 'solo',
        'is_endless': true,
        'checkin_period': 'daily',
        'goal_type': 'progress',
        'tracking': 'clock',
        'max_strikes': 3,
      })!;
      expect(rules, contains('endless'));
      expect(rules, contains('stopwatch'));
      expect(rules, contains('3 strikes allowed'));
    });

    test('a missing quest row gives no rules instead of failing', () {
      expect(QuestInvite.describe(null), isNull);
    });
  });

  test('the daily reset is the local time of UTC midnight', () {
    final now = DateTime.utc(2026, 7, 15, 13);
    expect(formatDailyReset(now: now),
        formatTime(DateTime.utc(2026, 7, 15)));
  });

  test('CheckinPeriod.currentLabel speaks of the current period', () {
    expect(CheckinPeriod.daily.currentLabel, 'TODAY');
    expect(CheckinPeriod.weekly.currentLabel, 'THIS WEEK');
    expect(CheckinPeriod.monthly.currentLabel, 'THIS MONTH');
  });

  group('ClockQuickButton', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    Future<void> pump(WidgetTester tester, Challenge quest) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          openClockSessionProvider(quest.id).overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          home: Scaffold(body: Center(child: ClockQuickButton(challenge: quest))),
        ),
      ));
      await tester.pumpAndSettle();
    }

    ElevatedButton button(WidgetTester tester) => tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('clock-quick-start')));

    testWidgets('offers START on a quest day', (tester) async {
      await pump(tester, _quest(clock: true));
      expect(find.text('START'), findsOneWidget);
      expect(button(tester).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cannot start a clock on a rest day', (tester) async {
      final today = DateTime.now().toUtc().weekday;
      final otherDays = [
        for (var d = 1; d <= 7; d++)
          if (d != today) d
      ];
      await pump(tester, _quest(clock: true, weekdays: otherDays));
      expect(find.text('RESTS TODAY'), findsOneWidget);
      expect(button(tester).onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
