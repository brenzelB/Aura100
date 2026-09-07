import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aura_quest/core/offline/pending_check_in.dart';
import 'package:aura_quest/core/offline/offline_check_in_queue.dart';
import 'package:aura_quest/core/offline/offline_sync_service.dart';
import 'package:aura_quest/features/challenges/data/challenge_repository.dart';

class FakeChallengeRepository implements ChallengeRepository {
  final Map<String, int> checkInReturns = {};
  final Map<String, Exception> checkInErrors = {};
  final List<String> loggedCalls = [];

  @override
  Future<int> logCheckIn(String challengeId) async {
    loggedCalls.add(challengeId);
    if (checkInErrors.containsKey(challengeId)) {
      throw checkInErrors[challengeId]!;
    }
    return checkInReturns[challengeId] ?? 100;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OfflineSyncService', () {
    const queue = OfflineCheckInQueue();
    late OfflineSyncService service;
    late FakeChallengeRepository fakeRepo;

    setUp(() {
      service = OfflineSyncService(queue: queue);
      fakeRepo = FakeChallengeRepository();
    });

    test('syncs empty queue with 0 count', () async {
      final result = await service.syncPendingCheckIns(fakeRepo);
      expect(result.syncedCount, 0);
      expect(result.hasSynced, isFalse);
      expect(fakeRepo.loggedCalls, isEmpty);
    });

    test('successfully syncs pending check-ins and clears them from queue',
        () async {
      final nowUtc = DateTime.now().toUtc();
      final today = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);

      await queue.enqueue(PendingCheckIn(
        challengeId: 'c1',
        questTitle: 'Workout',
        timestamp: nowUtc,
        date: today,
      ));
      await queue.enqueue(PendingCheckIn(
        challengeId: 'c2',
        questTitle: 'Read Book',
        timestamp: nowUtc,
        date: today,
      ));

      fakeRepo.checkInReturns['c1'] = 100;
      fakeRepo.checkInReturns['c2'] = 50;

      final result = await service.syncPendingCheckIns(fakeRepo);

      expect(result.syncedCount, 2);
      expect(result.auraGained, 150);
      expect(result.syncedTitles, ['Workout', 'Read Book']);
      expect(fakeRepo.loggedCalls, ['c1', 'c2']);

      final remaining = await queue.getPending();
      expect(remaining, isEmpty);
    });

    test('handles already checked in message by clearing item', () async {
      final nowUtc = DateTime.now().toUtc();
      final today = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);

      await queue.enqueue(PendingCheckIn(
        challengeId: 'c1',
        questTitle: 'Workout',
        timestamp: nowUtc,
        date: today,
      ));

      fakeRepo.checkInErrors['c1'] = const PostgrestException(
        message: 'Already checked in today - come back tomorrow!',
      );

      final result = await service.syncPendingCheckIns(fakeRepo);

      expect(result.syncedCount, 1);
      expect(result.syncedTitles, ['Workout']);

      final remaining = await queue.getPending();
      expect(remaining, isEmpty);
    });
  });
}
