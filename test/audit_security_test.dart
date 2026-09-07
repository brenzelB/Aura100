import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura_quest/core/data/read_all_pages.dart';
import 'package:aura_quest/core/text/dates.dart';
import 'package:aura_quest/core/offline/offline_check_in_queue.dart';
import 'package:aura_quest/core/offline/offline_sync_service.dart';
import 'package:aura_quest/core/offline/pending_check_in.dart';
import 'package:aura_quest/core/push/push_account_gate.dart';
import 'package:aura_quest/core/push/push_message.dart';
import 'offline/offline_sync_service_test.dart' show FakeChallengeRepository;

PendingCheckIn item(String id, {String owner = 'alice', DateTime? day}) =>
    PendingCheckIn(
        challengeId: id,
        questTitle: id,
        timestamp: day ?? DateTime.utc(2026, 9, 7, 12),
        date: day ?? DateTime.utc(2026, 9, 7),
        userId: owner);

class WaitingRepository extends FakeChallengeRepository {
  final entered = Completer<void>();
  final release = Completer<int>();
  @override
  Future<int> logCheckIn(String challengeId) {
    loggedCalls.add(challengeId);
    if (!entered.isCompleted) entered.complete();
    return release.future;
  }
}

void main() {
  test('calendar dates remain on their UTC quest day', () {
    expect(formatDate(DateTime.utc(2026, 9, 7)), 'Sep 7, 2026');
    expect(formatWeekdayDate(DateTime.utc(2026, 9, 7)), 'Monday, Sep 7, 2026');
  });
  test('malformed push fields do not crash a background handler', () {
    expect(PushMessage.tryParse({'category': 123}), isNull);
    expect(PushMessage.tryParse({'category': 'quest', 'title': {}, 'body': [],
      'refId': 123, 'id': '42'})?.outboxId, 42);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const queue = OfflineCheckInQueue(userId: 'alice');

  test('legacy unowned data is never assigned to the next login', () async {
    SharedPreferences.setMockInitialValues({
      OfflineCheckInQueue.defaultStorageKey: [
        jsonEncode(item('legacy', owner: '').toJson())
      ]
    });
    expect(await queue.getPending(), isEmpty);
    expect(
        await const OfflineCheckInQueue(userId: 'bob').getPending(), isEmpty);
  });
  test('same UUID on different backends has separate data', () async {
    await queue.enqueue(item('q'));
    expect(
        await const OfflineCheckInQueue(
                userId: 'alice', backendUrl: 'https://other.invalid')
            .getPending(),
        isEmpty);
  });
  test('queue rejects anonymous and foreign writes', () async {
    expect(await const OfflineCheckInQueue().enqueue(item('q')), isFalse);
    expect(await queue.enqueue(item('q', owner: 'bob')), isFalse);
    expect(await queue.getPending(), isEmpty);
  });
  test('concurrent writes from two queue instances retain every item',
      () async {
    const another = OfflineCheckInQueue(userId: 'alice');
    await Future.wait(List.generate(
        50, (n) => (n.isEven ? queue : another).enqueue(item('q$n'))));
    expect((await queue.getPending()).length, 50);
    await Future.wait([queue.remove('q0'), another.enqueue(item('q50'))]);
    final items = await queue.getPending();
    expect(items.length, 50);
    expect(items.any((p) => p.challengeId == 'q50'), isTrue);
  });
  test('account change during request halts sync and keeps original queue',
      () async {
    await queue.enqueue(item('q1'));
    await queue.enqueue(item('q2'));
    String? owner = 'alice';
    final repo = WaitingRepository();
    final service = OfflineSyncService(
        queue: queue,
        currentUserIdGetter: () => owner,
        now: () => DateTime.utc(2026, 9, 7, 12));
    final pending = service.syncPendingCheckIns(repo);
    await repo.entered.future;
    owner = 'bob';
    repo.release.complete(100);
    final result = await pending;
    expect(repo.loggedCalls, ['q1']);
    expect(result.syncedCount, 0);
    expect((await queue.getPending()).length, 2);
    service.dispose();
  });
  test('parallel sync calls cannot send the same item twice', () async {
    await queue.enqueue(item('q'));
    final repo = WaitingRepository();
    final service = OfflineSyncService(
        queue: queue,
        currentUserIdGetter: () => 'alice',
        now: () => DateTime.utc(2026, 9, 7));
    final first = service.syncPendingCheckIns(repo);
    final second = service.syncPendingCheckIns(repo);
    await repo.entered.future;
    repo.release.complete(100);
    await Future.wait([first, second]);
    expect(repo.loggedCalls, ['q']);
    service.dispose();
  });
  test('future and previous UTC days are discarded without a server call',
      () async {
    await queue.enqueue(item('yesterday', day: DateTime.utc(2026, 9, 6)));
    await queue.enqueue(item('tomorrow', day: DateTime.utc(2026, 9, 8)));
    final repo = FakeChallengeRepository();
    final service = OfflineSyncService(
        queue: queue,
        currentUserIdGetter: () => 'alice',
        now: () => DateTime.utc(2026, 9, 7));
    final result = await service.syncPendingCheckIns(repo);
    expect(result.discardedCount, 2);
    expect(repo.loggedCalls, isEmpty);
    service.dispose();
  });
  const message = PushMessage(
      category: 'quest',
      title: 'Private Alice text',
      body: 'secret',
      outboxId: 42);
  test('push with full text still needs server authorization', () async {
    expect(
        await authorizePushMessage(
            message: message,
            currentUserId: () => 'bob',
            fetch: (_) async => null),
        isNull);
  });
  test('push account switch during fetch suppresses the old message', () async {
    var owner = 'alice';
    final fetched = Completer<PushMessage?>();
    final request = authorizePushMessage(
        message: message,
        currentUserId: () => owner,
        fetch: (_) => fetched.future);
    owner = 'bob';
    fetched.complete(message);
    expect(await request, isNull);
  });
  test('verified push for current owner is returned', () async {
    expect(
        await authorizePushMessage(
            message: message,
            currentUserId: () => 'alice',
            fetch: (_) async => message),
        message);
  });
  test('pagination reads 1205 records despite a lower server cap', () async {
    final data = List.generate(1205, (n) => n);
    final rows = await readAllPages<int>(
        (from, to) async => data.skip(from).take(100).toList());
    expect(rows, data);
  });
}
