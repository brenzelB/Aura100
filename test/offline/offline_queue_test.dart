import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura_quest/core/offline/pending_check_in.dart';
import 'package:aura_quest/core/offline/offline_check_in_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PendingCheckIn', () {
    test('toJson and fromJson preserves data', () {
      final now = DateTime.utc(2026, 9, 4, 15, 30, 0);
      final date = DateTime.utc(2026, 9, 4);
      final checkIn = PendingCheckIn(
        challengeId: 'c123',
        questTitle: 'Morning Workout',
        timestamp: now,
        date: date,
      );

      final json = checkIn.toJson();
      final recovered = PendingCheckIn.fromJson(json);

      expect(recovered.challengeId, 'c123');
      expect(recovered.questTitle, 'Morning Workout');
      expect(recovered.timestamp, now);
      expect(recovered.date, date);
      expect(recovered, checkIn);
    });
  });

  group('OfflineCheckInQueue', () {
    const queue = OfflineCheckInQueue();

    test('starts with empty queue', () async {
      final items = await queue.getPending();
      expect(items, isEmpty);
    });

    test('enqueues item and retrieves it', () async {
      final item = PendingCheckIn(
        challengeId: 'q1',
        questTitle: 'Cold Shower',
        timestamp: DateTime.utc(2026, 9, 4, 10, 0, 0),
        date: DateTime.utc(2026, 9, 4),
      );

      final added = await queue.enqueue(item);
      expect(added, isTrue);

      final items = await queue.getPending();
      expect(items.length, 1);
      expect(items.first.questTitle, 'Cold Shower');
    });

    test('prevents duplicate check-in for the same challenge on same day', () async {
      final item1 = PendingCheckIn(
        challengeId: 'q1',
        questTitle: 'Cold Shower',
        timestamp: DateTime.utc(2026, 9, 4, 10, 0, 0),
        date: DateTime.utc(2026, 9, 4),
      );
      final item2 = PendingCheckIn(
        challengeId: 'q1',
        questTitle: 'Cold Shower Duplicate',
        timestamp: DateTime.utc(2026, 9, 4, 11, 0, 0),
        date: DateTime.utc(2026, 9, 4),
      );

      final added1 = await queue.enqueue(item1);
      final added2 = await queue.enqueue(item2);

      expect(added1, isTrue);
      expect(added2, isFalse);

      final items = await queue.getPending();
      expect(items.length, 1);
    });

    test('removes specific item by challengeId and date', () async {
      final item1 = PendingCheckIn(
        challengeId: 'q1',
        questTitle: 'Quest 1',
        timestamp: DateTime.utc(2026, 9, 4, 10, 0, 0),
        date: DateTime.utc(2026, 9, 4),
      );
      final item2 = PendingCheckIn(
        challengeId: 'q2',
        questTitle: 'Quest 2',
        timestamp: DateTime.utc(2026, 9, 4, 10, 5, 0),
        date: DateTime.utc(2026, 9, 4),
      );

      await queue.enqueue(item1);
      await queue.enqueue(item2);

      await queue.remove('q1', date: item1.date);

      final items = await queue.getPending();
      expect(items.length, 1);
      expect(items.first.challengeId, 'q2');
    });

    test('clear wipes entire queue', () async {
      await queue.enqueue(PendingCheckIn(
        challengeId: 'q1',
        questTitle: 'Quest 1',
        timestamp: DateTime.utc(2026, 9, 4, 10, 0, 0),
        date: DateTime.utc(2026, 9, 4),
      ));

      await queue.clear();
      final items = await queue.getPending();
      expect(items, isEmpty);
    });
  });
}
