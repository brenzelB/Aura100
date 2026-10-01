import 'dart:async';

import 'package:aura_quest/core/realtime/realtime_sync.dart';
import 'package:aura_quest/features/auth/application/auth_providers.dart';
import 'package:aura_quest/features/auth/data/auth_repository.dart';
import 'package:aura_quest/features/challenges/application/challenge_providers.dart';
import 'package:aura_quest/features/challenges/data/challenge_repository.dart';
import 'package:aura_quest/features/challenges/domain/duel.dart';
import 'package:aura_quest/features/challenges/domain/settlement.dart';
import 'package:aura_quest/features/challenges/domain/weekly_recap.dart';
import 'package:aura_quest/features/friends/application/friends_providers.dart';
import 'package:aura_quest/features/friends/data/friends_repository.dart';
import 'package:aura_quest/features/friends/domain/social_models.dart';
import 'package:aura_quest/features/profile/application/profile_providers.dart';
import 'package:aura_quest/features/profile/data/profile_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Auth implements AuthRepository {
  @override
  User? currentUser = User(
      id: 'alice',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-09-30');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Quests implements ChallengeRepository {
  final reply = Completer<void>();
  int calls = 0;
  int activityReads = 0;
  int trophyReads = 0;
  int recapReads = 0;
  bool reset = false;
  bool hidden = false;
  final day = DateTime.utc(2026, 9, 29);
  static const verdict = DuelResult(
      challengerDice: [4, 5],
      opponentDice: [1, 2],
      winnerId: 'alice',
      pot: 200);

  @override
  Future<void> createDuel(
      {required String challengeId,
      required String opponentId,
      required int stake}) async {
    calls++;
    await reply.future;
  }

  @override
  Future<DuelResult?> respondToDuel(
      {required String duelId, required bool accept}) async {
    calls++;
    await reply.future;
    return accept ? verdict : null;
  }

  @override
  Future<void> hideTrophy(String challengeId) async {
    calls++;
    await reply.future;
    hidden = true;
  }

  @override
  Future<Map<DateTime, int>> fetchActivityByDay({int days = 365}) async {
    activityReads++;
    return reset ? {} : {day: 1};
  }

  @override
  Future<List<Trophy>> fetchTrophies() async {
    trophyReads++;
    return hidden
        ? []
        : [
            Trophy(
                challengeId: 'quest',
                questTitle: 'Quest',
                finalAura: reset ? 0 : 100,
                completed: true,
                perfect: true,
                finishedAt: day)
          ];
  }

  @override
  Future<WeeklyRecap?> fetchWeeklyRecap() async {
    recapReads++;
    return reset
        ? null
        : WeeklyRecap(
            weekStart: day,
            weekEnd: day,
            checkIns: 1,
            activeDays: 1,
            auraGained: 100,
            auraLost: 0,
            strikes: 0,
            questsFinished: 0,
            duelsWon: 0,
            duelsLost: 0,
            previousCheckIns: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profile implements ProfileRepository {
  _Profile(this.quests, {this.reject = false});
  final _Quests quests;
  final bool reject;
  @override
  Future<void> resetStats() async {
    if (reject) {
      throw const PostgrestException(message: 'Active quests remain.');
    }
    quests.reset = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Social implements FriendsRepository {
  bool arrived = false;
  int inviteReads = 0;
  int requestReads = 0;
  int friendReads = 0;
  @override
  Future<List<QuestInvite>> fetchMyInvites() async {
    inviteReads++;
    return arrived
        ? [
            QuestInvite(
                id: 'invite',
                questTitle: 'Walk',
                inviterName: 'Bob',
                createdAt: DateTime.utc(2026))
          ]
        : [];
  }

  @override
  Future<List<FriendRequest>> fetchFriendRequests() async {
    requestReads++;
    return arrived
        ? [
            FriendRequest(
                id: 'request',
                fromUserId: 'bob',
                fromName: 'Bob',
                createdAt: DateTime.utc(2026))
          ]
        : [];
  }

  @override
  Future<List<Friend>> fetchFriends() async {
    friendReads++;
    return arrived
        ? [
            Friend(
                userId: 'bob',
                username: 'Bob',
                friendsSince: DateTime.utc(2026))
          ]
        : [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Object?> _act(ProviderContainer container, String action) {
  if (action == 'hide') {
    return container.read(trophyControllerProvider.notifier).hide('quest');
  }
  final controller = container.read(duelControllerProvider.notifier);
  return switch (action) {
    'create' =>
      controller.create(challengeId: 'quest', opponentId: 'bob', stake: 100),
    'accept' => controller.acceptAndRoll('duel'),
    _ => controller.decline('duel'),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final action in ['create', 'accept', 'decline', 'hide']) {
    test('$action completes after its last widget listener disappears',
        () async {
      final repo = _Quests();
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(_Auth()),
        challengeRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      final provider =
          action == 'hide' ? trophyControllerProvider : duelControllerProvider;
      final listener = container.listen(provider, (_, __) {});
      final result = _act(container, action);
      listener.close();
      await container.pump();
      expect(container.exists(provider), isTrue);
      repo.reply.complete();
      expect(await result, action == 'accept' ? _Quests.verdict : true);
      await container.pump();
      expect(container.exists(provider), isFalse);
    });

    test('$action returns server errors without throwing a lifecycle exception',
        () async {
      final repo = _Quests();
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(_Auth()),
        challengeRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      final provider =
          action == 'hide' ? trophyControllerProvider : duelControllerProvider;
      final listener = container.listen(provider, (_, __) {});
      addTearDown(listener.close);
      final result = _act(container, action);
      await container.pump();
      const error = PostgrestException(message: 'Server rejected the action.');
      repo.reply.completeError(error);
      expect(await result, action == 'accept' ? null : false);
      expect(container.read(provider).error, error);
    });

    test(
        '$action drops an old-account response without refreshing the new account',
        () async {
      final repo = _Quests();
      final auth = _Auth();
      var reads = 0;
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        challengeRepositoryProvider.overrideWithValue(repo),
        incomingDuelsProvider.overrideWith((ref) async {
          reads++;
          return [];
        }),
        trophiesProvider.overrideWith((ref) async {
          reads++;
          return [];
        }),
      ]);
      addTearDown(container.dispose);
      final incoming = container.listen(incomingDuelsProvider, (_, __) {});
      final trophies = container.listen(trophiesProvider, (_, __) {});
      addTearDown(incoming.close);
      addTearDown(trophies.close);
      await container.read(incomingDuelsProvider.future);
      await container.read(trophiesProvider.future);
      final result = _act(container, action);
      await container.pump();
      auth.currentUser = null;
      repo.reply.complete();
      expect(await result, action == 'accept' ? null : false);
      await container.pump();
      expect(reads, 2);
    });
  }

  test('read-only duel creation survives a frame without any subscriber',
      () async {
    final repo = _Quests();
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_Auth()),
      challengeRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    final result = _act(container, 'create');
    await container.pump();
    repo.reply.complete();
    expect(await result, isTrue);
  });

  test('double tapping sends only one duel request', () async {
    final repo = _Quests();
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_Auth()),
      challengeRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    final first = _act(container, 'create');
    expect(await _act(container, 'create'), isFalse);
    expect(repo.calls, 1);
    repo.reply.complete();
    expect(await first, isTrue);
  });

  for (final reject in [false, true]) {
    test(
        'reset ${reject ? 'rejection retains' : 'success refreshes'} held profile history',
        () async {
      final repo = _Quests();
      final container = ProviderContainer(overrides: [
        authStateChangesProvider
            .overrideWith((ref) => const Stream<AuthState>.empty()),
        challengeRepositoryProvider.overrideWithValue(repo),
        profileRepositoryProvider
            .overrideWithValue(_Profile(repo, reject: reject)),
        currentProfileProvider.overrideWith((ref) async => null),
        myStatsProvider.overrideWith((ref) async => null),
        myChallengesProvider.overrideWith((ref) async => []),
      ]);
      addTearDown(container.dispose);
      final activity = container.listen(activityByDayProvider, (_, __) {});
      final trophies = container.listen(trophiesProvider, (_, __) {});
      final recap = container.listen(weeklyRecapProvider, (_, __) {});
      final controller =
          container.listen(profileControllerProvider, (_, __) {});
      addTearDown(activity.close);
      addTearDown(trophies.close);
      addTearDown(recap.close);
      addTearDown(controller.close);
      await container.read(activityByDayProvider.future);
      await container.read(trophiesProvider.future);
      await container.read(weeklyRecapProvider.future);
      expect(
          await container.read(profileControllerProvider.notifier).resetStats(),
          !reject);
      expect(await container.read(activityByDayProvider.future),
          reject ? {repo.day: 1} : isEmpty);
      expect((await container.read(trophiesProvider.future)).single.finalAura,
          reject ? 100 : 0);
      expect(await container.read(weeklyRecapProvider.future),
          reject ? isNotNull : isNull);
      expect(repo.activityReads, reject ? 1 : 2);
      expect(repo.trophyReads, reject ? 1 : 2);
      expect(repo.recapReads, reject ? 1 : 2);
    });
  }

  for (final resumed in [false, true]) {
    test('social notices catch up after ${resumed ? 'resume' : 'reconnect'}',
        () async {
      final repo = _Social();
      final syncProvider = Provider((ref) => RealtimeSync(ref, 'alice'));
      final container = ProviderContainer(overrides: [
        authStateChangesProvider
            .overrideWith((ref) => const Stream<AuthState>.empty()),
        friendsRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      final invites = container.listen(myInvitesProvider, (_, __) {});
      final requests = container.listen(friendRequestsProvider, (_, __) {});
      final friends = container.listen(myFriendsProvider, (_, __) {});
      addTearDown(invites.close);
      addTearDown(requests.close);
      addTearDown(friends.close);
      expect(await container.read(myInvitesProvider.future), isEmpty);
      expect(await container.read(friendRequestsProvider.future), isEmpty);
      expect(await container.read(myFriendsProvider.future), isEmpty);
      final sync = container.read(syncProvider);
      addTearDown(sync.dispose);
      repo.arrived = true;
      sync.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(repo.inviteReads, 1);
      if (resumed) {
        sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
      } else {
        sync.refresh();
      }
      expect((await container.read(myInvitesProvider.future)).single.questTitle,
          'Walk');
      expect(
          (await container.read(friendRequestsProvider.future)).single.fromName,
          'Bob');
      expect((await container.read(myFriendsProvider.future)).single.username,
          'Bob');
      expect(
          [repo.inviteReads, repo.requestReads, repo.friendReads], [2, 2, 2]);
      sync.dispose();
      sync.refresh();
      expect(repo.inviteReads, 2);
    });
  }
}
