import 'package:aura_quest/features/challenges/domain/challenge.dart';
import 'package:aura_quest/features/challenges/domain/quest_balance.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/create_challenge_sheet.dart';
import 'package:aura_quest/features/profile/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge quest(
        {bool avoid = false,
        int slips = 0,
        String status = 'active',
        List<int> days = const [1, 2, 3, 4, 5],
        int duration = 30}) =>
    Challenge(
      id: 'q',
      creatorId: 'u',
      title: 'Comeback',
      description: '',
      durationDays: duration,
      auraGain: 100,
      auraPenalty: 25,
      maxStrikes: 3,
      startsOn: DateTime.utc(2026, 9, 7),
      createdAt: DateTime.utc(2026, 9, 7),
      activeWeekdays: days,
      goalType: avoid ? GoalType.avoid : GoalType.check,
      slipsInPeriod: slips,
      myStatus: status,
      comebackNeeded: true,
    );

void main() {
  test('Comeback skips weekend rest days', () {
    expect(quest().nextComebackDate(DateTime.utc(2026, 9, 12)),
        DateTime.utc(2026, 9, 14));
  });
  test('Broken avoid period waits for the next planned day', () {
    expect(
        quest(avoid: true, slips: 1)
            .nextComebackDate(DateTime.utc(2026, 9, 11)),
        DateTime.utc(2026, 9, 14));
  });
  test('Failed or ended quests do not offer impossible comeback units', () {
    expect(quest(status: 'failed').nextComebackDate(DateTime.utc(2026, 9, 8)),
        isNull);
    expect(
        quest(duration: 5).nextComebackDate(DateTime.utc(2026, 9, 12)), isNull);
  });
  test('Quest refresh keeps balance and comeback state', () {
    final q = quest().copyWith(myAura: 5);
    expect(q.comebackNeeded, isTrue);
    expect(q.attacksEnabled, isTrue);
    expect(q.myAura, 5);
  });
  test('XP level depends only on permanent progression', () {
    PlayerStats stats(int aura, int xp) => PlayerStats(
        questsJoined: 1,
        activeQuests: 1,
        totalCheckins: 9,
        totalAura: aura,
        gearOwned: 2,
        friends: 0,
        lifetimeXp: xp);
    expect(stats(0, 0).level, 0);
    expect(stats(5000, 499).level, 1);
    expect(stats(0, 500).level, 2);
    expect(stats(0, 500).xpInLevel, 0);
    expect(stats(0, 1200).level, stats(9999, 1200).level);
  });
  test(
      'Relative prices stay comparable and low rewards never create free items',
      () {
    for (final reward in [1, 10, 100, 1000]) {
      expect(QuestBalance.price(reward, 'Streak Shield'), reward);
      expect(QuestBalance.price(reward, 'Aura Heist', tier: 1),
          greaterThanOrEqualTo(1));
    }
    expect(QuestBalance.price(100, 'Aura Heist', tier: 1), 20);
    expect(QuestBalance.price(100, 'Aura Heist', tier: 2), 40);
    expect(QuestBalance.price(100, 'Aura Heist', tier: 3), 60);
  });
  testWidgets(
      'Classic is default, Chill changes all values and custom controls are under Advanced',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: Scaffold(body: CreateChallengeSheet()))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('BALANCE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('+100 Aura per unit · −25'), findsOneWidget);
    expect(find.text('Aura penalty per missed period'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Chill'));
    await tester.pumpAndSettle();
    expect(find.textContaining('+100 Aura per unit · −10'), findsOneWidget);
    expect(find.textContaining('5 misses allowed.'), findsOneWidget);
    await tester.ensureVisible(find.text('Advanced'));
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use custom balance'));
    await tester.tap(find.text('Use custom balance'));
    await tester.pumpAndSettle();
    expect(find.text('Aura penalty per missed period'), findsOneWidget);
    expect(find.text('Allow attacks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
