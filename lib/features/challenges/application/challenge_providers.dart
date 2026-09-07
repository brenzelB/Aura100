import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/offline/offline_check_in_queue.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/pending_check_in.dart';
import '../../auth/application/auth_providers.dart';
import '../data/challenge_repository.dart';
import '../domain/benefit.dart';
import '../domain/blackout.dart';
import '../domain/challenge.dart';
import '../domain/duel.dart';
import '../domain/progress_entry.dart';
import '../domain/quest_activity.dart';
import '../domain/quest_member.dart';
import '../domain/aura_heist.dart';
import '../domain/settlement.dart';
import '../domain/slip_result.dart';
import '../domain/targeted_roast.dart';
import '../domain/weekly_recap.dart';
import '../../friends/domain/head_to_head.dart';

final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) {
  return ChallengeRepository(Supabase.instance.client);
});

class _ChallengeCache {
  List<Challenge> active = [];
  Map<String, Map<DateTime, DateTime>> checkIns = {};
  final details = <String, Map<DateTime, DateTime>>{};
}

// A request retains its original cache object across awaits. A login change
// creates a new object, so a late response can never repopulate another account.
final _challengeCacheProvider = Provider<_ChallengeCache>((ref) {
  ref.watch(currentUserProvider);
  return _ChallengeCache();
});

/// The logged-in user's ACTIVE challenges (incl. per-challenge aura),
/// newest first. Re-fetches on auth events; empty in skeleton mode.
final myChallengesProvider =
    FutureProvider.autoDispose<List<Challenge>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider); // rebuild on login/logout

  final currentUserId = ref.watch(currentUserProvider)?.id;
  final cache = ref.watch(_challengeCacheProvider);
  if (currentUserId == null) return const [];

  try {
    final list =
        await ref.watch(challengeRepositoryProvider).fetchMyActiveChallenges();
    cache.active = list;
    return list;
  } catch (e) {
    if (_isNetworkError(e) && cache.active.isNotEmpty) {
      debugPrint('🔌 [myChallengesProvider] Offline, using cached challenges');
      return cache.active;
    }
    rethrow;
  }
});

/// Unacknowledged targeted roasts sent to the user.
final targetedRoastsProvider =
    FutureProvider.autoDispose<List<TargetedRoast>>((ref) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  return ref
      .watch(challengeRepositoryProvider)
      .fetchUnacknowledgedTargetedRoasts();
});

/// Landed-but-unseen Aura Heists against the user — the "you got robbed"
/// notices.
final robbedNoticesProvider =
    FutureProvider.autoDispose<List<RobbedNotice>>((ref) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  return ref.watch(challengeRepositoryProvider).fetchUnseenRobbedNotices();
});

/// The duel history of ONE quest (family arg = challenge id) — feeds
/// the DUELS section on the detail screen.
final questDuelsProvider = FutureProvider.autoDispose
    .family<List<QuestDuel>, String>((ref, challengeId) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  return ref.watch(challengeRepositoryProvider).fetchQuestDuels(challengeId);
});

/// Dice duels waiting for the user's answer (Home inbox).
final incomingDuelsProvider =
    FutureProvider.autoDispose<List<IncomingDuel>>((ref) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  return ref.watch(challengeRepositoryProvider).fetchIncomingDuels();
});

/// Creating and answering dice duels. One controller: the flows are
/// modal, so a single busy state is enough.
final duelControllerProvider =
    AsyncNotifierProvider.autoDispose<DuelController, void>(
  DuelController.new,
);

class DuelController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Action-only notifier.
  }

  void _refresh() {
    // Aura balances moved (escrow/pot), the inbox changed, and every
    // quest's duel history is potentially stale (invalidating the
    // family clears all its instances).
    ref.invalidate(myChallengesProvider);
    ref.invalidate(incomingDuelsProvider);
    ref.invalidate(settlementEventsProvider);
    ref.invalidate(questDuelsProvider);
  }

  /// Returns true when the challenge went out (stake escrowed).
  Future<bool> create({
    required String challengeId,
    required String opponentId,
    required int stake,
  }) async {
    final repo = ref.read(challengeRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repo.createDuel(
        challengeId: challengeId, opponentId: opponentId, stake: stake));
    if (state.hasError) return false;
    _refresh();
    return true;
  }

  /// Accepts and rolls. Returns the result, or null on failure
  /// (error lands in `state`).
  Future<DuelResult?> acceptAndRoll(String duelId) async {
    final repo = ref.read(challengeRepositoryProvider);
    state = const AsyncLoading();
    DuelResult? result;
    state = await AsyncValue.guard(() async {
      result = await repo.respondToDuel(duelId: duelId, accept: true);
    });
    if (state.hasError) return null;
    _refresh();
    return result;
  }

  /// Declines (challenger gets refunded). Returns true on success.
  Future<bool> decline(String duelId) async {
    final repo = ref.read(challengeRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => repo.respondToDuel(duelId: duelId, accept: false));
    if (state.hasError) return false;
    _refresh();
    return true;
  }
}

/// What the settlement engine did recently (penalties, strikes,
/// shields, completions) — shown on Home, later also pushed via FCM.
final settlementEventsProvider =
    FutureProvider.autoDispose<List<SettlementEvent>>((ref) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  return ref.watch(challengeRepositoryProvider).fetchRecentEvents();
});

/// The trophy room: finished quests with their frozen aura.
final trophiesProvider = FutureProvider.autoDispose<List<Trophy>>((ref) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  return ref.watch(challengeRepositoryProvider).fetchTrophies();
});

/// Starts a lobby quest (family arg = challenge id).
final startQuestControllerProvider = AsyncNotifierProvider.autoDispose
    .family<StartQuestController, void, String>(StartQuestController.new);

class StartQuestController
    extends AutoDisposeFamilyAsyncNotifier<void, String> {
  @override
  FutureOr<void> build(String arg) {
    // Action-only notifier; `arg` is the challenge id.
  }

  Future<bool> start() async {
    final repo = ref.read(challengeRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repo.startQuest(arg));
    if (state.hasError) return false;
    ref.invalidate(myChallengesProvider);
    ref.invalidate(questMembersProvider(arg));
    return true;
  }
}

/// Removes single entries from the trophy room.
final trophyControllerProvider =
    AsyncNotifierProvider.autoDispose<TrophyController, void>(
  TrophyController.new,
);

class TrophyController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Action-only notifier.
  }

  /// Returns true when the entry left the room.
  Future<bool> hide(String challengeId) async {
    final repo = ref.read(challengeRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repo.hideTrophy(challengeId));
    if (state.hasError) return false;
    ref.invalidate(trophiesProvider);
    return true;
  }
}

/// The user's check-ins across ALL active quests, grouped by quest id.
/// One request that feeds the whole Home dashboard. Merges pending
/// offline check-ins so the UI optimistically flips to done immediately.
final myCheckInsProvider =
    FutureProvider.autoDispose<Map<String, Map<DateTime, DateTime>>>(
        (ref) async {
  if (!SupabaseConfig.isConfigured) return const {};
  final cache = ref.watch(_challengeCacheProvider);
  final challenges = await ref.watch(myChallengesProvider.future);
  if (challenges.isEmpty) return const {};

  Map<String, Map<DateTime, DateTime>> serverMap = const {};
  try {
    serverMap = await ref
        .watch(challengeRepositoryProvider)
        .fetchCheckInsForChallenges(challenges.map((c) => c.id).toList());
    cache.checkIns = serverMap;
  } catch (e) {
    if (_isNetworkError(e)) {
      debugPrint('🔌 [myCheckInsProvider] Offline, using cached check-ins');
      serverMap = cache.checkIns;
    } else {
      rethrow;
    }
  }

  // Merge pending offline check-ins
  final pending = ref.watch(pendingCheckInsProvider);
  if (pending.isEmpty) return serverMap;

  final merged = <String, Map<DateTime, DateTime>>{};
  for (final entry in serverMap.entries) {
    merged[entry.key] = Map<DateTime, DateTime>.from(entry.value);
  }
  for (final p in pending) {
    final questMap = merged.putIfAbsent(p.challengeId, () => {});
    final pDate = DateTime.utc(p.date.year, p.date.month, p.date.day);
    questMap[pDate] = p.timestamp;
  }
  return merged;
});

/// The user's check-in history for ONE challenge (family arg =
/// challenge id): UTC day → check-in timestamp. Fuels the timeline
/// on the detail screen. Merges pending offline check-ins.
final checkInsProvider = FutureProvider.autoDispose
    .family<Map<DateTime, DateTime>, String>((ref, challengeId) async {
  if (!SupabaseConfig.isConfigured) return const {};
  ref.watch(authStateChangesProvider);
  final cache = ref.watch(_challengeCacheProvider);

  Map<DateTime, DateTime> serverMap = const {};
  try {
    serverMap =
        await ref.watch(challengeRepositoryProvider).fetchCheckIns(challengeId);
    cache.details[challengeId] = serverMap;
  } catch (e) {
    if (_isNetworkError(e)) {
      debugPrint(
          '🔌 [checkInsProvider] Offline for $challengeId, using cached check-ins');
      serverMap = cache.details[challengeId] ?? const {};
    } else {
      rethrow;
    }
  }

  final pending = ref.watch(pendingCheckInsProvider);
  final thisPending = pending.where((p) => p.challengeId == challengeId);
  if (thisPending.isEmpty) return serverMap;

  final merged = Map<DateTime, DateTime>.from(serverMap);
  for (final p in thisPending) {
    final pDate = DateTime.utc(p.date.year, p.date.month, p.date.day);
    merged[pDate] = p.timestamp;
  }
  return merged;
});

/// The shared activity feed of ONE quest (family arg = challenge id):
/// every member's wins and losses inside that quest.
final questActivityProvider = FutureProvider.autoDispose
    .family<List<QuestActivity>, String>((ref, challengeId) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  // Re-runs whenever the quest list moves, so a check-in or a logged
  // amount shows up without a manual pull.
  ref.watch(myChallengesProvider);
  return ref.watch(challengeRepositoryProvider).fetchQuestActivity(challengeId);
});

/// Every progress entry of ONE quest (family arg = challenge id) —
/// the history shown on the detail screen.
final progressEntriesProvider = FutureProvider.autoDispose
    .family<List<ProgressEntry>, String>((ref, challengeId) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  return ref
      .watch(challengeRepositoryProvider)
      .fetchProgressEntries(challengeId);
});

/// Logs progress on ONE quest (family arg = challenge id) so each card
/// keeps its own busy state.
final progressControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ProgressController, void, String>(ProgressController.new);

class ProgressController extends AutoDisposeFamilyAsyncNotifier<void, String> {
  @override
  FutureOr<void> build(String arg) {
    // Action-only notifier; `arg` is the challenge id.
  }

  /// Returns the new running total, or null when the server refused.
  Future<ProgressResult?> add(double amount) async {
    final repo = ref.read(challengeRepositoryProvider);
    state = const AsyncLoading();
    ProgressResult? result;
    state = await AsyncValue.guard(() async {
      result = await repo.addProgress(challengeId: arg, amount: amount);
    });
    if (state.hasError) return null;

    // The bar, the history and — once the target is met — the aura,
    // timeline and event feed all move.
    _refreshAfterProgress();
    return result;
  }

  /// Corrects a mistyped entry to [amount]. Returns null on refusal.
  Future<ProgressResult?> edit(String entryId, double amount) async {
    final repo = ref.read(challengeRepositoryProvider);
    state = const AsyncLoading();
    ProgressResult? result;
    state = await AsyncValue.guard(() async {
      result = await repo.editProgressEntry(entryId: entryId, amount: amount);
    });
    if (state.hasError) return null;
    _refreshAfterProgress();
    return result;
  }

  /// Deletes an entry from the current period. Returns null on refusal.
  Future<ProgressResult?> remove(String entryId) async {
    final repo = ref.read(challengeRepositoryProvider);
    state = const AsyncLoading();
    ProgressResult? result;
    state = await AsyncValue.guard(() async {
      result = await repo.deleteProgressEntry(entryId: entryId);
    });
    if (state.hasError) return null;
    _refreshAfterProgress();
    return result;
  }

  /// The bar, the history and — when a goal crossing changes — the aura,
  /// timeline and event feed all move.
  void _refreshAfterProgress() {
    ref.invalidate(myChallengesProvider);
    ref.invalidate(progressEntriesProvider(arg));
    ref.invalidate(checkInsProvider(arg));
    ref.invalidate(myCheckInsProvider);
    ref.invalidate(settlementEventsProvider);
  }
}

/// Logs / undoes slips on ONE negative quest (family arg = challenge id).
final slipControllerProvider = AsyncNotifierProvider.autoDispose
    .family<SlipController, void, String>(SlipController.new);

class SlipController extends AutoDisposeFamilyAsyncNotifier<void, String> {
  @override
  FutureOr<void> build(String arg) {
    // Action-only notifier; `arg` is the challenge id.
  }

  /// Records a slip. Returns null when the server refused.
  Future<SlipResult?> log() => _run((repo) => repo.logSlip(arg));

  /// Takes the last slip back. Returns null when the server refused.
  Future<SlipResult?> undo() => _run((repo) => repo.undoLastSlip(arg));

  Future<SlipResult?> _run(
      Future<SlipResult> Function(ChallengeRepository repo) action) async {
    final repo = ref.read(challengeRepositoryProvider);
    state = const AsyncLoading();
    SlipResult? result;
    state = await AsyncValue.guard(() async {
      result = await action(repo);
    });
    if (state.hasError) return null;

    // The counter, the aura, the strike board and the feed can all move.
    ref.invalidate(myChallengesProvider);
    ref.invalidate(questMembersProvider(arg));
    ref.invalidate(questActivityProvider(arg));
    ref.invalidate(settlementEventsProvider);
    return result;
  }
}

/// ONE challenge's shop stock (family arg = challenge id).
final benefitsProvider = FutureProvider.autoDispose
    .family<List<Benefit>, String>((ref, challengeId) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  return ref.watch(challengeRepositoryProvider).fetchBenefits(challengeId);
});

bool _isNetworkError(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException) {
    return true;
  }
  final errStr = error.toString().toLowerCase();
  return errStr.contains('socket') ||
      errStr.contains('network') ||
      errStr.contains('connection') ||
      errStr.contains('clientexception') ||
      errStr.contains('failed host lookup') ||
      errStr.contains('handshake') ||
      errStr.contains('timeout') ||
      errStr.contains('unreachable') ||
      errStr.contains('os error');
}

class PendingCheckInsNotifier extends StateNotifier<List<PendingCheckIn>> {
  PendingCheckInsNotifier(this._queue) : super(const []) {
    load();
  }

  final OfflineCheckInQueue _queue;

  Future<void> load() async {
    final list = await _queue.getPending();
    if (mounted) state = list;
  }

  Future<bool> enqueue(PendingCheckIn checkIn) async {
    final success = await _queue.enqueue(checkIn);
    if (success) {
      await load();
    }
    return success;
  }

  Future<void> remove(String challengeId, {DateTime? date}) async {
    await _queue.remove(challengeId, date: date);
    await load();
  }

  Future<void> clear() async {
    await _queue.clear();
    state = const [];
  }
}

final offlineCheckInQueueProvider = Provider<OfflineCheckInQueue>((ref) {
  final user = ref.watch(currentUserProvider);
  return OfflineCheckInQueue(userId: user?.id);
});

final pendingCheckInsProvider =
    StateNotifierProvider<PendingCheckInsNotifier, List<PendingCheckIn>>((ref) {
  final queue = ref.watch(offlineCheckInQueueProvider);
  return PendingCheckInsNotifier(queue);
});

final offlineSyncNoticeProvider = StateProvider<String?>((ref) {
  ref.watch(currentUserProvider);
  return null;
});

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final service = OfflineSyncService(
    queue: ref.watch(offlineCheckInQueueProvider),
    currentUserIdGetter: () => Supabase.instance.client.auth.currentUser?.id,
  );

  service.initialize(
    () async {
      await ref.read(pendingCheckInsProvider.notifier).load();
      ref.invalidate(myChallengesProvider);
      ref.invalidate(myCheckInsProvider);
      ref.invalidate(settlementEventsProvider);
      ref.invalidate(robbedNoticesProvider);
    },
    () async {
      final result = await service
          .syncPendingCheckIns(ref.read(challengeRepositoryProvider));
      if (result.discardedCount > 0 && !service.isDisposed) {
        ref.read(offlineSyncNoticeProvider.notifier).state =
            '${result.discardedCount} offline check-in(s) could not be applied. '
            'Only the current UTC day and active quests can be synced.';
      }
      return result;
    },
  );

  ref.onDispose(service.dispose);
  return service;
});

enum CheckInStatus {
  success,
  queuedOffline,
  failed,
}

class CheckInResult {
  const CheckInResult({
    required this.status,
    this.auraGained,
    this.errorMessage,
  });

  final CheckInStatus status;
  final int? auraGained;
  final String? errorMessage;

  bool get isSuccess => status == CheckInStatus.success;
  bool get isQueuedOffline => status == CheckInStatus.queuedOffline;
}

/// Runs the daily check-in for ONE challenge (family arg = challenge id)
/// so each card has its own loading/error state.
final checkInControllerProvider = AsyncNotifierProvider.autoDispose
    .family<CheckInController, void, String>(CheckInController.new);

class CheckInController extends AutoDisposeFamilyAsyncNotifier<void, String> {
  @override
  FutureOr<void> build(String arg) {
    // Action-only notifier; `arg` is the challenge id.
  }

  /// Runs the daily check-in. If offline, stores the check-in locally and
  /// returns [CheckInResult.queuedOffline] with optimistic UI update.
  Future<CheckInResult> checkIn({String? questTitle}) async {
    final repo = ref.read(challengeRepositoryProvider);
    final owner = ref.read(currentUserProvider)?.id;
    final queue = ref.read(offlineCheckInQueueProvider);
    final tappedAt = DateTime.now().toUtc();
    state = const AsyncLoading();
    int? gained;
    Object? caughtError;

    try {
      gained = await repo.logCheckIn(arg);
      state = const AsyncData(null);
    } catch (e, st) {
      caughtError = e;
      state = AsyncError(e, st);
    }

    if (owner == null ||
        Supabase.instance.client.auth.currentUser?.id != owner) {
      return const CheckInResult(
          status: CheckInStatus.failed,
          errorMessage: 'Account changed. Please try again.');
    }
    if (caughtError == null && gained != null) {
      ref.invalidate(myChallengesProvider);
      ref.invalidate(checkInsProvider(arg));
      ref.invalidate(myCheckInsProvider);
      ref.invalidate(settlementEventsProvider);
      ref.invalidate(robbedNoticesProvider);
      return CheckInResult(status: CheckInStatus.success, auraGained: gained);
    }

    // Check if offline/connection error
    if (caughtError != null && _isNetworkError(caughtError)) {
      final nowUtc = tappedAt;
      final todayDate = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final currentUserId = owner;
      final pending = PendingCheckIn(
        challengeId: arg,
        questTitle: questTitle ?? 'Quest',
        timestamp: nowUtc,
        date: todayDate,
        userId: currentUserId,
      );

      final saved = await queue.enqueue(pending);
      if (!saved) {
        return const CheckInResult(
            status: CheckInStatus.failed,
            errorMessage: 'Could not save your check-in. Please try again.');
      }
      if (Supabase.instance.client.auth.currentUser?.id != owner) {
        return const CheckInResult(
            status: CheckInStatus.failed,
            errorMessage:
                'Account changed. Your check-in stays with the original account.');
      }
      await ref.read(pendingCheckInsProvider.notifier).load();
      state = const AsyncData(null);

      // Invalidate to update optimistic UI
      ref.invalidate(myCheckInsProvider);
      ref.invalidate(checkInsProvider(arg));

      return const CheckInResult(status: CheckInStatus.queuedOffline);
    }

    final message = caughtError is PostgrestException
        ? caughtError.message
        : 'Check-in failed - try again.';
    return CheckInResult(
      status: CheckInStatus.failed,
      errorMessage: message,
    );
  }
}

/// The quest's party (family arg = challenge id). Watches the quest
/// list, so it refreshes automatically whenever the list does — e.g.
/// right after a check-in.
final questMembersProvider = FutureProvider.autoDispose
    .family<List<QuestMember>, String>((ref, challengeId) async {
  if (!SupabaseConfig.isConfigured) return const [];
  final challenges = await ref.watch(myChallengesProvider.future);
  final challenge = challenges.where((c) => c.id == challengeId).firstOrNull;
  if (challenge == null) return const [];
  return ref.watch(challengeRepositoryProvider).fetchQuestMembers(challenge);
});

/// Tells the server which time zone this device sits in, once per login.
///
/// The Blackout item schedules its two hours in the TARGET's local time,
/// and the server has no other way of knowing what "morning" means for
/// them. Fires and forgets: a failed report costs a mis-timed lockout,
/// never a broken start-up.
final timezoneReporterProvider = Provider<void>((ref) {
  if (!SupabaseConfig.isConfigured) return;
  final user = ref.watch(currentUserProvider);
  if (user == null) return;
  ref.read(challengeRepositoryProvider).reportTimezone();
});

/// Every day the user logged something, for the contribution grid.
final activityByDayProvider =
    FutureProvider.autoDispose<Map<DateTime, int>>((ref) {
  if (!SupabaseConfig.isConfigured) return const {};
  ref.watch(authStateChangesProvider);
  return ref.watch(challengeRepositoryProvider).fetchActivityByDay();
});

/// The last completed week in numbers — feeds the Monday card.
final weeklyRecapProvider = FutureProvider.autoDispose<WeeklyRecap?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  ref.watch(authStateChangesProvider);
  return ref.watch(challengeRepositoryProvider).fetchWeeklyRecap();
});

/// The running score against ONE friend (family arg = their user id).
final headToHeadProvider = FutureProvider.autoDispose
    .family<HeadToHead, ({String id, String username, String? emoji})>(
        (ref, who) {
  return ref.watch(challengeRepositoryProvider).fetchHeadToHead(
        friendId: who.id,
        username: who.username,
        avatarEmoji: who.emoji,
      );
});

/// Lockouts that already hit me and that I have not acknowledged yet.
///
/// Feeds the home banner. A player who was offline for the whole window
/// would otherwise never find out why their day went missing.
final unseenBlackoutsProvider =
    FutureProvider.autoDispose<List<Blackout>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  return ref.watch(challengeRepositoryProvider).fetchUnseenBlackouts();
});

/// The lockout currently running on ME in this quest, or null.
///
/// Only ever returns the caller's own row — RLS keeps a pending Blackout
/// out of everybody else's reach, so nobody can scout one coming.
final myBlackoutProvider = FutureProvider.autoDispose
    .family<Blackout?, String>((ref, challengeId) async {
  if (!SupabaseConfig.isConfigured) return null;
  return ref.watch(challengeRepositoryProvider).fetchMyBlackout(challengeId);
});

/// All of this player's reminders, keyed by quest id.
final questRemindersProvider =
    FutureProvider.autoDispose<Map<String, ({int hour, int minute})>>(
        (ref) async {
  if (!SupabaseConfig.isConfigured) return const {};
  ref.watch(authStateChangesProvider);
  return ref.watch(challengeRepositoryProvider).fetchQuestReminders();
});

/// This player's reminder time for ONE quest (family arg = challenge
/// id), or null when none is set.
final questReminderProvider = FutureProvider.autoDispose
    .family<({int hour, int minute})?, String>((ref, challengeId) async {
  if (!SupabaseConfig.isConfigured) return null;
  return ref.watch(challengeRepositoryProvider).fetchQuestReminder(challengeId);
});

/// Invites a player by username into ONE quest (family arg =
/// challenge id).
final inviteControllerProvider = AsyncNotifierProvider.autoDispose
    .family<InviteController, void, String>(InviteController.new);

class InviteController extends AutoDisposeFamilyAsyncNotifier<void, String> {
  @override
  FutureOr<void> build(String arg) {
    // Action-only notifier; `arg` is the challenge id.
  }

  /// Returns true when the invite went out.
  Future<bool> invite(String username) async {
    final repo = ref.read(challengeRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => repo.inviteToChallenge(challengeId: arg, username: username),
    );
    return !state.hasError;
  }
}

/// Pokes a quest-mate (family arg = challenge id).
final nudgeControllerProvider = AsyncNotifierProvider.autoDispose
    .family<NudgeController, void, String>(NudgeController.new);

class NudgeController extends AutoDisposeFamilyAsyncNotifier<void, String> {
  @override
  FutureOr<void> build(String arg) {
    // Action-only notifier; `arg` is the challenge id.
  }

  /// Returns true when the poke landed.
  Future<bool> nudge(String userId) async {
    final repo = ref.read(challengeRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => repo.nudgeParticipant(challengeId: arg, userId: userId),
    );
    return !state.hasError;
  }
}

/// Abandons ONE quest (family arg = challenge id) with its own
/// loading/error state for the confirmation dialog.
///
/// NOTE: the detail screen must `ref.watch` this provider, not only
/// `read` it. Being autoDispose, an unwatched provider is destroyed
/// mid-`await`, and the `state =` assignment afterwards throws —
/// which silently swallowed the whole abandon flow before.
final abandonControllerProvider = AsyncNotifierProvider.autoDispose
    .family<AbandonController, void, String>(AbandonController.new);

class AbandonController extends AutoDisposeFamilyAsyncNotifier<void, String> {
  @override
  FutureOr<void> build(String arg) {
    // Action-only notifier; `arg` is the challenge id.
  }

  /// Leaves the quest. `ok` is false on failure; `newOwner` carries the
  /// username the ownership passed to (null when there was no handover).
  Future<({bool ok, String? newOwner})> abandon() async {
    final repo = ref.read(challengeRepositoryProvider);
    state = const AsyncLoading();
    String? newOwner;
    state = await AsyncValue.guard(() async {
      newOwner = await repo.leaveChallenge(arg);
    });
    if (state.hasError) return (ok: false, newOwner: null);

    // The quest disappears from the overview.
    ref.invalidate(myChallengesProvider);
    return (ok: true, newOwner: newOwner);
  }
}

/// Buys benefits inside ONE challenge's shop (family arg = challenge id).
final purchaseControllerProvider = AsyncNotifierProvider.autoDispose
    .family<PurchaseController, void, String>(PurchaseController.new);

class PurchaseController extends AutoDisposeFamilyAsyncNotifier<void, String> {
  @override
  FutureOr<void> build(String arg) {
    // Action-only notifier; `arg` is the challenge id.
  }

  /// Returns the new challenge balance, or null on failure.
  Future<int?> purchase(String benefitId) async {
    final repo = ref.read(challengeRepositoryProvider);
    state = const AsyncLoading();
    int? newBalance;
    state = await AsyncValue.guard(() async {
      newBalance = await repo.purchaseBenefit(benefitId);
    });
    if (state.hasError) return null;

    // Shop stock (owned flags) + challenge list (balance) are stale.
    ref.invalidate(benefitsProvider(arg));
    ref.invalidate(myChallengesProvider);
    return newBalance;
  }
}

/// Runs the "create challenge" action and exposes loading / error state
/// to the form (same pattern as AuthController).
final createChallengeControllerProvider =
    AsyncNotifierProvider.autoDispose<CreateChallengeController, void>(
  CreateChallengeController.new,
);

class CreateChallengeController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Action-only notifier.
  }

  /// Returns true on success; errors land in `state` for the UI.
  Future<bool> create({
    required String title,
    required String description,
    required int durationDays,
    required int auraGain,
    required int auraPenalty,
    required int maxStrikes,
    required DateTime startsOn,
    required CheckinPeriod checkinPeriod,
    required int checkinsPerPeriod,
    QuestMode mode = QuestMode.solo,
    GoalType goalType = GoalType.check,
    double? targetValue,
    String? unit,
    bool isEndless = false,
    int dailyAllowance = 0,
    List<int> activeWeekdays = const [1, 2, 3, 4, 5, 6, 7],
    List<String> invitees = const [],
  }) async {
    final repo = ref.read(challengeRepositoryProvider);
    state = const AsyncLoading();
    String? createdId;
    state = await AsyncValue.guard(() async {
      createdId = await repo.createChallenge(
        title: title,
        description: description,
        durationDays: durationDays,
        auraGain: auraGain,
        auraPenalty: auraPenalty,
        maxStrikes: maxStrikes,
        startsOn: startsOn,
        checkinPeriod: checkinPeriod,
        checkinsPerPeriod: checkinsPerPeriod,
        mode: mode,
        goalType: goalType,
        targetValue: targetValue,
        unit: unit,
        isEndless: isEndless,
        dailyAllowance: dailyAllowance,
        activeWeekdays: activeWeekdays,
      );
      // Fire the invitations right after the quest exists. Best-effort:
      // one bad username should not undo the whole creation.
      for (final username in invitees) {
        try {
          await repo.inviteToChallenge(
              challengeId: createdId!, username: username);
        } catch (_) {}
      }
    });
    if (!state.hasError) {
      // The freshly forged quest appears in the list immediately.
      ref.invalidate(myChallengesProvider);
    }
    return !state.hasError;
  }
}
