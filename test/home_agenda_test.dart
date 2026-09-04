import 'package:flutter_test/flutter_test.dart';

import 'package:aura_quest/features/challenges/domain/challenge.dart';
import 'package:aura_quest/features/home/domain/home_agenda.dart';

Challenge _challenge({
  String id = 'c1',
  String title = 'Test',
  DateTime? startsOn,
  int durationDays = 14,
  int maxStrikes = 1,
  int auraGain = 60,
  int strikesUsed = 0,
  CheckinPeriod checkinPeriod = CheckinPeriod.daily,
  int checkinsPerPeriod = 1,
}) {
  return Challenge(
    id: id,
    creatorId: 'u1',
    title: title,
    description: '',
    durationDays: durationDays,
    auraGain: auraGain,
    auraPenalty: 30,
    maxStrikes: maxStrikes,
    strikesUsed: strikesUsed,
    startsOn: startsOn ?? DateTime.utc(2026, 7, 10),
    createdAt: DateTime.utc(2026, 7, 10),
    checkinPeriod: checkinPeriod,
    checkinsPerPeriod: checkinsPerPeriod,
  );
}

DateTime _d(int day) => DateTime.utc(2026, 7, day);
Map<DateTime, DateTime> _checks(List<int> days) => {
      for (final day in days) _d(day): DateTime.utc(2026, 7, day, 8),
    };

void main() {
  group('HomeAgenda.build', () {
    test('splits running quests into open and done for today', () {
      final agenda = HomeAgenda.build(
        challenges: [
          _challenge(id: 'a', title: 'Done today'),
          _challenge(id: 'b', title: 'Still open'),
        ],
        checkInsByQuest: {'a': _checks([15])},
        today: _d(15),
      );

      expect(agenda.done.single.challenge.id, 'a');
      expect(agenda.open.single.challenge.id, 'b');
      expect(agenda.totalRunning, 2);
      expect(agenda.completion, 0.5);
      expect(agenda.open.single.demandLabel, 'due today');
    });

    test('not-yet-started quests are upcoming, ended ones are ignored', () {
      final agenda = HomeAgenda.build(
        challenges: [
          _challenge(id: 'future', startsOn: _d(20)),
          _challenge(id: 'over', startsOn: _d(1), durationDays: 5),
          _challenge(id: 'now'),
        ],
        checkInsByQuest: const {},
        today: _d(15),
      );

      expect(agenda.upcoming.single.id, 'future');
      expect(agenda.totalRunning, 1); // 'over' counts nowhere
      expect(agenda.open.single.challenge.id, 'now');
    });

    test('critical when the last strike is on the table', () {
      // The engine settled 1 of 1 strikes → today decides.
      final agenda = HomeAgenda.build(
        challenges: [
          _challenge(startsOn: _d(10), maxStrikes: 1, strikesUsed: 1)
        ],
        checkInsByQuest: {'c1': _checks([11, 12, 13, 14])},
        today: _d(15),
      );

      final item = agenda.open.single;
      expect(item.strikesUsed, 1);
      expect(item.isCritical, isTrue);
      expect(item.isDoomed, isFalse);
      expect(agenda.atRisk, hasLength(1));
      expect(agenda.doomed, isEmpty);
    });

    test('doomed (not critical) once the budget is overspent', () {
      // Settled strikes exceed the budget: the engine will fail this
      // participant on its next run — the UI must not promise rescue.
      // (Rare gap state: only visible between miss and the next
      // hourly settlement tick.)
      final agenda = HomeAgenda.build(
        challenges: [
          _challenge(startsOn: _d(14), maxStrikes: 0, strikesUsed: 1)
        ],
        checkInsByQuest: const {},
        today: _d(15),
      );

      final item = agenda.open.single;
      expect(item.strikesUsed, 1);
      expect(item.isDoomed, isTrue);
      expect(item.isCritical, isFalse); // no false hope
      expect(agenda.doomed, hasLength(1));
      expect(agenda.atRisk, isEmpty);
    });

    test('not critical while strikes are still in the budget', () {
      // Nothing settled against them yet → today may be skipped.
      final agenda = HomeAgenda.build(
        challenges: [
          _challenge(startsOn: _d(10), maxStrikes: 1, strikesUsed: 0)
        ],
        checkInsByQuest: {'c1': _checks([10, 11, 12, 13, 14])},
        today: _d(15),
      );

      expect(agenda.open.single.strikesUsed, 0);
      expect(agenda.open.single.isCritical, isFalse);
      expect(agenda.atRisk, isEmpty);
    });

    test('hardcore (0 strikes) is critical from the very first day', () {
      final agenda = HomeAgenda.build(
        challenges: [
          _challenge(startsOn: _d(15), maxStrikes: 0, strikesUsed: 0)
        ],
        checkInsByQuest: const {},
        today: _d(15),
      );

      expect(agenda.open.single.isCritical, isTrue);
    });

    test('weekly quest counts the period, not the day', () {
      // 3x/week from 07-13; checked in on 13th and 14th; today 15th.
      final agenda = HomeAgenda.build(
        challenges: [
          _challenge(
            startsOn: _d(13),
            durationDays: 28,
            checkinPeriod: CheckinPeriod.weekly,
            checkinsPerPeriod: 3,
          )
        ],
        checkInsByQuest: {'c1': _checks([13, 14])},
        today: _d(15),
      );

      final item = agenda.open.single;
      expect(item.doneInPeriod, 2);
      expect(item.remaining, 1);
      expect(item.daysLeftInPeriod, 4); // period 13..19, today 15
      expect(item.demandLabel, '1x to go · 4d left');
      expect(item.deadlineToday, isFalse);
    });

    test('weekly quest with its goal met is done, not open', () {
      final agenda = HomeAgenda.build(
        challenges: [
          _challenge(
            startsOn: _d(13),
            durationDays: 28,
            checkinPeriod: CheckinPeriod.weekly,
            checkinsPerPeriod: 2,
          )
        ],
        checkInsByQuest: {'c1': _checks([13, 14])},
        today: _d(15),
      );

      expect(agenda.open, isEmpty);
      expect(agenda.done.single.goalMet, isTrue);
      expect(agenda.completion, 1.0);
    });

    test('open list is sorted: critical first, then tightest deadline', () {
      final agenda = HomeAgenda.build(
        challenges: [
          // Relaxed: weekly, plenty of slack.
          _challenge(
            id: 'relaxed',
            startsOn: _d(13),
            durationDays: 28,
            maxStrikes: 3,
            checkinPeriod: CheckinPeriod.weekly,
            checkinsPerPeriod: 1,
          ),
          // Critical: 1 strike allowed and exactly 1 settled →
          // today decides.
          _challenge(
              id: 'critical',
              startsOn: _d(13),
              maxStrikes: 1,
              strikesUsed: 1),
        ],
        checkInsByQuest: {'critical': _checks([13])},
        today: _d(15),
      );

      expect(agenda.open.first.challenge.id, 'critical');
      expect(agenda.open.first.isCritical, isTrue);
      expect(agenda.open.last.challenge.id, 'relaxed');
    });

    test('doomed quests sink to the bottom of the open list', () {
      final agenda = HomeAgenda.build(
        challenges: [
          _challenge(
              id: 'dead', startsOn: _d(13), maxStrikes: 0, strikesUsed: 2),
          _challenge(id: 'alive', startsOn: _d(15), maxStrikes: 2),
        ],
        checkInsByQuest: const {},
        today: _d(15),
      );

      expect(agenda.open.first.challenge.id, 'alive');
      expect(agenda.open.last.challenge.id, 'dead');
      expect(agenda.open.last.isDoomed, isTrue);
    });

    test('empty input yields an empty agenda', () {
      final agenda = HomeAgenda.build(
        challenges: const [],
        checkInsByQuest: const {},
        today: _d(15),
      );

      expect(agenda.totalRunning, 0);
      expect(agenda.completion, isNull);
      expect(agenda.atRisk, isEmpty);
    });
  });
}
