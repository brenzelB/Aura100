import 'package:aura_quest/features/challenges/domain/challenge.dart';
import 'package:aura_quest/features/home/domain/home_agenda.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge _quest({
  QuestMode mode = QuestMode.solo,
  QuestLifecycle lifecycle = QuestLifecycle.active,
  bool isEndless = false,
  DateTime? startsOn,
  DateTime? startedAt,
}) =>
    Challenge(
      id: 'q',
      creatorId: 'u',
      title: 'Q',
      description: '',
      durationDays: 7,
      auraGain: 100,
      auraPenalty: 50,
      maxStrikes: 1,
      startsOn: startsOn ?? DateTime.utc(2026, 7, 20),
      createdAt: DateTime.utc(2026, 7, 20),
      mode: mode,
      lifecycle: lifecycle,
      isEndless: isEndless,
      startedAt: startedAt,
    );

void main() {
  group('QuestMode', () {
    test('last man standing maps to/from the snake_case db value', () {
      expect(QuestMode.lastManStanding.dbValue, 'last_man_standing');
      expect(QuestMode.fromDb('last_man_standing'), QuestMode.lastManStanding);
      expect(QuestMode.solo.dbValue, 'solo');
    });
  });

  group('QuestLifecycle', () {
    test('parses db values, defaults to active', () {
      expect(QuestLifecycle.fromDb('lobby'), QuestLifecycle.lobby);
      expect(QuestLifecycle.fromDb('finished'), QuestLifecycle.finished);
      expect(QuestLifecycle.fromDb(null), QuestLifecycle.active);
      expect(QuestLifecycle.fromDb('active'), QuestLifecycle.active);
    });
  });

  group('Challenge flags', () {
    test('lobby / lms / endless helpers', () {
      final lms = _quest(
          mode: QuestMode.lastManStanding,
          lifecycle: QuestLifecycle.lobby,
          isEndless: true);
      expect(lms.isLobby, isTrue);
      expect(lms.isLastManStanding, isTrue);
      expect(lms.isEndless, isTrue);
      expect(lms.isFinished, isFalse);
      expect(lms.timeLeftLabel, 'in lobby');
    });

    test('endless label counts up from the start', () {
      final endless = _quest(
        isEndless: true,
        startedAt: DateTime.now().toUtc().subtract(const Duration(days: 4)),
      );
      // Day 1 on the first day, so 4 days ago -> 5.
      expect(endless.runningDays, 5);
      expect(endless.timeLeftLabel, 'running 5d');
    });
  });

  group('HomeAgenda with lobby/endless', () {
    final today = DateTime.utc(2026, 7, 22);

    test('lobby quests are parked in upcoming, never actionable', () {
      final agenda = HomeAgenda.build(
        challenges: [
          _quest(
              mode: QuestMode.lastManStanding,
              lifecycle: QuestLifecycle.lobby,
              isEndless: true),
        ],
        checkInsByQuest: const {},
        today: today,
      );
      expect(agenda.open, isEmpty);
      expect(agenda.done, isEmpty);
      expect(agenda.upcoming, hasLength(1));
    });

    test('endless quests keep showing up long past a fixed duration', () {
      // Started 100 days ago with a nominal 7-day duration: a fixed
      // quest would be gone, an endless one is still open today.
      final start = today.subtract(const Duration(days: 100));
      final endless = _quest(isEndless: true, startsOn: start);
      final agenda = HomeAgenda.build(
        challenges: [endless],
        checkInsByQuest: const {},
        today: today,
      );
      expect(agenda.open.length + agenda.done.length, 1);
    });
  });
}
