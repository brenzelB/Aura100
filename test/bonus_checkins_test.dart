import 'package:aura_quest/features/challenges/domain/challenge.dart';
import 'package:aura_quest/features/challenges/domain/challenge_timeline.dart';
import 'package:aura_quest/features/home/domain/home_agenda.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge quest(QuestMode mode,
        {CheckinPeriod period = CheckinPeriod.weekly,
        GoalType goal = GoalType.check,
        int days = 21}) =>
    Challenge(
        id: 'q',
        creatorId: 'u',
        title: 'Train',
        description: '',
        durationDays: days,
        auraGain: 100,
        auraPenalty: 25,
        maxStrikes: 3,
        startsOn: DateTime.utc(2026, 10, 1),
        createdAt: DateTime.utc(2026, 10, 1),
        mode: mode,
        checkinPeriod: period,
        checkinsPerPeriod: 3,
        goalType: goal,
        targetValue: goal == GoalType.progress ? 100 : null);
DateTime day(int d) => DateTime.utc(2026, 10, d);
Map<DateTime, DateTime> checks(List<int> days) =>
    {for (final d in days) day(d): day(d)};

void main() {
  for (final mode in QuestMode.values) {
    test('$mode: optional days leave required completion full', () {
      final q = quest(mode);
      final agenda = HomeAgenda.build(challenges: [
        q
      ], checkInsByQuest: {
        'q': checks([1, 2, 3])
      }, today: day(4));
      expect(agenda.open, isEmpty);
      expect(agenda.completion, 1);
      expect(agenda.done.single.canLogBonus, isTrue);
      expect(agenda.done.single.isCritical, isFalse);
      final logged = HomeAgenda.build(challenges: [
        q
      ], checkInsByQuest: {
        'q': checks([1, 2, 3, 4])
      }, today: day(4));
      expect(logged.done.single.bonusCount, 1);
      expect(logged.done.single.canLogBonus, isFalse);
      final timeline = ChallengeTimeline.build(
          challenge: q, checkIns: checks([1, 2, 3, 4]), today: day(4));
      expect(timeline.days.take(3).any((d) => d.isBonus), isFalse);
      expect(timeline.days[3].isBonus, isTrue);
      expect(timeline.stats.doneCount, 1);
      expect(timeline.stats.successRate, 1);
    });
  }
  test('weekly bonus resets at the anchored next period', () {
    final q = quest(QuestMode.solo);
    final timeline = ChallengeTimeline.build(
        challenge: q, checkIns: checks([1, 2, 3, 4, 8]), today: day(8));
    expect(timeline.days[3].isBonus, isTrue);
    expect(timeline.days[7].isBonus, isFalse);
    final agenda = HomeAgenda.build(challenges: [
      q
    ], checkInsByQuest: {
      'q': checks([1, 2, 3, 4])
    }, today: day(8));
    expect(agenda.open.single.doneInPeriod, 0);
    expect(agenda.open.single.canLogBonus, isFalse);
  });
  test('monthly extras are distinct without exceeding a fulfilled target', () {
    final q = quest(QuestMode.coop, period: CheckinPeriod.monthly, days: 60);
    final t = ChallengeTimeline.build(
        challenge: q, checkIns: checks([1, 2, 3, 7, 12]), today: day(12));
    expect(t.days.where((d) => d.checkedAt != null && d.isBonus).length, 2);
    expect(t.stats.doneCount, 1);
  });
  test(
      'progress uses its amount target once and labels later activity days Bonus',
      () {
    final q = quest(QuestMode.versus, goal: GoalType.progress);
    final t = ChallengeTimeline.build(
        challenge: q, checkIns: checks([1, 3]), today: day(3));
    expect(t.days[0].isBonus, isFalse);
    expect(t.days[2].isBonus, isTrue);
    expect(t.stats.doneCount, 1);
  });
  test('Avoid never offers a bonus tick', () {
    final q = quest(QuestMode.lastManStanding, goal: GoalType.avoid);
    final agenda = HomeAgenda.build(challenges: [
      q
    ], checkInsByQuest: {
      'q': checks([1])
    }, today: day(3));
    expect(agenda.done.single.canLogBonus, isFalse);
    final t = ChallengeTimeline.build(
        challenge: q, checkIns: checks([1, 2]), today: day(3));
    expect(t.days.any((d) => d.isBonus), isFalse);
  });
}
