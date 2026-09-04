import 'package:flutter_test/flutter_test.dart';

import 'package:aura_quest/features/challenges/domain/challenge.dart';
import 'package:aura_quest/features/challenges/domain/challenge_timeline.dart';

Challenge _challenge({
  DateTime? startsOn,
  int durationDays = 14,
  DateTime? joinedOn,
  CheckinPeriod checkinPeriod = CheckinPeriod.daily,
  int checkinsPerPeriod = 1,
}) {
  return Challenge(
    id: 'c1',
    creatorId: 'u1',
    title: 'Test',
    description: '',
    durationDays: durationDays,
    auraGain: 60,
    auraPenalty: 30,
    maxStrikes: 3,
    startsOn: startsOn ?? DateTime.utc(2026, 7, 7),
    createdAt: DateTime.utc(2026, 7, 7),
    joinedOn: joinedOn,
    checkinPeriod: checkinPeriod,
    checkinsPerPeriod: checkinsPerPeriod,
  );
}

DateTime _d(int day) => DateTime.utc(2026, 7, day);

void main() {
  group('ChallengeTimeline.build', () {
    test('mirrors the Morning Run demo data exactly', () {
      // Start 07-07, 14 days, check-ins on 7,8,9,11,12,13 — today is 07-14.
      final checkIns = {
        for (final day in [7, 8, 9, 11, 12, 13])
          _d(day): DateTime.utc(2026, 7, day, 7, 0),
      };

      final timeline = ChallengeTimeline.build(
        challenge: _challenge(),
        checkIns: checkIns,
        today: _d(14),
      );

      expect(timeline.days, hasLength(14));
      expect(timeline.days[0].status, DayStatus.done); // 07-07
      expect(timeline.days[3].status, DayStatus.missed); // 07-10
      expect(timeline.days[7].status, DayStatus.today); // 07-14
      expect(timeline.days[7].isToday, isTrue);
      expect(timeline.days[8].status, DayStatus.future); // 07-15
      expect(timeline.days.last.status, DayStatus.future); // 07-20

      expect(timeline.stats.doneCount, 6);
      expect(timeline.stats.missedCount, 1); // only 07-10
      expect(timeline.stats.accountableCount, 7); // 7 past days
      expect(timeline.stats.successRate, closeTo(6 / 7, 0.001));
      expect(timeline.stats.longestStreak, 3); // 07-11..13
      expect(timeline.stats.currentStreak, 3); // ends yesterday, today pending
    });

    test('checked-in today counts and extends the current streak', () {
      final checkIns = {
        _d(13): DateTime.utc(2026, 7, 13, 7),
        _d(14): DateTime.utc(2026, 7, 14, 7),
      };

      final timeline = ChallengeTimeline.build(
        challenge: _challenge(startsOn: _d(13), durationDays: 7),
        checkIns: checkIns,
        today: _d(14),
      );

      expect(timeline.days[1].status, DayStatus.done); // today, checked
      expect(timeline.days[1].isToday, isTrue);
      expect(timeline.stats.currentStreak, 2);
      expect(timeline.stats.successRate, 1.0);
    });

    test('a missed day resets the current streak to zero', () {
      final checkIns = {
        _d(7): DateTime.utc(2026, 7, 7, 7),
        _d(8): DateTime.utc(2026, 7, 8, 7),
        // 07-09..13 all missed
      };

      final timeline = ChallengeTimeline.build(
        challenge: _challenge(),
        checkIns: checkIns,
        today: _d(14),
      );

      expect(timeline.stats.currentStreak, 0);
      expect(timeline.stats.longestStreak, 2);
      expect(timeline.stats.missedCount, 5);
    });

    test('days before joining are notJoined and never count as missed', () {
      final timeline = ChallengeTimeline.build(
        challenge: _challenge(joinedOn: _d(10)),
        checkIns: {_d(10): DateTime.utc(2026, 7, 10, 9)},
        today: _d(12),
      );

      expect(timeline.days[0].status, DayStatus.notJoined); // 07-07
      expect(timeline.days[2].status, DayStatus.notJoined); // 07-09
      expect(timeline.days[3].status, DayStatus.done); // 07-10 (joined)
      expect(timeline.days[4].status, DayStatus.missed); // 07-11
      expect(timeline.stats.missedCount, 1);
    });

    test('challenge not started yet: all days future, no stats', () {
      final timeline = ChallengeTimeline.build(
        challenge: _challenge(startsOn: _d(20), durationDays: 5),
        checkIns: const {},
        today: _d(14),
      );

      expect(
        timeline.days.every((d) => d.status == DayStatus.future),
        isTrue,
      );
      expect(timeline.stats.successRate, isNull);
      expect(timeline.stats.accountableCount, 0);
    });

    test('ended challenge: no today marker, all days resolved', () {
      final timeline = ChallengeTimeline.build(
        challenge: _challenge(startsOn: _d(1), durationDays: 5),
        checkIns: {
          for (final day in [1, 2, 3])
            _d(day): DateTime.utc(2026, 7, day, 7),
        },
        today: _d(14),
      );

      expect(timeline.days.any((d) => d.isToday), isFalse);
      expect(timeline.stats.doneCount, 3);
      expect(timeline.stats.missedCount, 2);
      expect(timeline.stats.successRate, closeTo(0.6, 0.001));
    });

    test('weekly quest: stats count periods, free days are rest not missed',
        () {
      // Start 07-01, 2x/week, today 07-15.
      // Week 1 (07-01..07): check-ins on 1 + 3 → fulfilled.
      // Week 2 (07-08..14): check-in on 9 only → under target → missed.
      // Week 3 (07-15..): current, nothing yet → pending.
      final checkIns = {
        for (final day in [1, 3, 9]) _d(day): DateTime.utc(2026, 7, day, 7),
      };

      final timeline = ChallengeTimeline.build(
        challenge: _challenge(
          startsOn: _d(1),
          durationDays: 28,
          checkinPeriod: CheckinPeriod.weekly,
          checkinsPerPeriod: 2,
        ),
        checkIns: checkIns,
        today: _d(15),
      );

      // Past day without check-in is a REST day, not missed.
      expect(timeline.days[1].status, DayStatus.rest); // 07-02
      expect(timeline.days[0].status, DayStatus.done); // 07-01
      expect(timeline.days[14].status, DayStatus.today); // 07-15

      expect(timeline.stats.unit, 'weeks');
      expect(timeline.stats.accountableCount, 2); // two completed weeks
      expect(timeline.stats.doneCount, 1); // week 1 fulfilled
      expect(timeline.stats.missedCount, 1); // week 2 under target
      expect(timeline.stats.successRate, closeTo(0.5, 0.001));
      expect(timeline.stats.longestStreak, 1);
      expect(timeline.stats.currentStreak, 0); // week 2 broke it
    });

    test('weekly quest: current period counts once its target is reached',
        () {
      // Start 07-08 (2x/week), today 07-10, check-ins 07-08 + 07-09:
      // the running week is already fulfilled.
      final checkIns = {
        for (final day in [8, 9]) _d(day): DateTime.utc(2026, 7, day, 7),
      };

      final timeline = ChallengeTimeline.build(
        challenge: _challenge(
          startsOn: _d(8),
          durationDays: 21,
          checkinPeriod: CheckinPeriod.weekly,
          checkinsPerPeriod: 2,
        ),
        checkIns: checkIns,
        today: _d(10),
      );

      expect(timeline.stats.accountableCount, 1);
      expect(timeline.stats.doneCount, 1);
      expect(timeline.stats.successRate, 1.0);
      expect(timeline.stats.currentStreak, 1);
      expect(timeline.stats.missedCount, 0);
    });

    test('365-day challenge builds quickly and completely', () {
      final timeline = ChallengeTimeline.build(
        challenge: _challenge(startsOn: _d(1), durationDays: 365),
        checkIns: const {},
        today: _d(14),
      );

      expect(timeline.days, hasLength(365));
      expect(timeline.stats.missedCount, 13); // 07-01..13
    });
  });
}
