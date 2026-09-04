import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../auth/application/auth_providers.dart';
import '../../challenges/application/challenge_providers.dart';
import '../data/friends_repository.dart';
import '../domain/social_models.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(Supabase.instance.client);
});

/// The user's accepted friends (alphabetical).
final myFriendsProvider = FutureProvider.autoDispose<List<Friend>>((ref) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  return ref.watch(friendsRepositoryProvider).fetchFriends();
});

/// Incoming friend requests.
final friendRequestsProvider =
    FutureProvider.autoDispose<List<FriendRequest>>((ref) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  return ref.watch(friendsRepositoryProvider).fetchFriendRequests();
});

/// Sending requests, responding to them and unfriending — one
/// controller, since the Friends tab shows a single busy state.
final friendshipControllerProvider =
    AsyncNotifierProvider.autoDispose<FriendshipController, void>(
  FriendshipController.new,
);

class FriendshipController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Action-only notifier.
  }

  void _refresh() {
    ref.invalidate(myFriendsProvider);
    ref.invalidate(friendRequestsProvider);
  }

  /// Returns 'pending' / 'accepted' on success, null on failure.
  Future<String?> sendRequest(String username) async {
    final repo = ref.read(friendsRepositoryProvider);
    state = const AsyncLoading();
    String? status;
    state = await AsyncValue.guard(() async {
      status = await repo.sendFriendRequest(username);
    });
    if (state.hasError) return null;
    _refresh();
    return status;
  }

  Future<bool> respond({
    required String friendshipId,
    required bool accept,
  }) async {
    final repo = ref.read(friendsRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() =>
        repo.respondToFriendRequest(friendshipId: friendshipId, accept: accept));
    if (state.hasError) return false;
    _refresh();
    return true;
  }

  Future<bool> remove(String userId) async {
    final repo = ref.read(friendsRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repo.removeFriend(userId));
    if (state.hasError) return false;
    _refresh();
    return true;
  }
}

/// Pending quest invites for the logged-in user.
final myInvitesProvider =
    FutureProvider.autoDispose<List<QuestInvite>>((ref) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  return ref.watch(friendsRepositoryProvider).fetchMyInvites();
});

/// Recent pokes received by the logged-in user (history, seen or not).
final myNudgesProvider = FutureProvider.autoDispose<List<Nudge>>((ref) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  return ref.watch(friendsRepositoryProvider).fetchMyNudges();
});

/// UNSEEN pokes — the actionable Home inbox (auto-clears on dismiss,
/// react, or a check-in on that quest).
final unseenNudgesProvider = FutureProvider.autoDispose<List<Nudge>>((ref) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  return ref.watch(friendsRepositoryProvider).fetchUnseenNudges();
});

/// Ids the current user has blocked — drives the "Blocked" state in the
/// safety sheet and hides blocked players from action surfaces.
final blockedUsersProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  if (!SupabaseConfig.isConfigured) return <String>{};
  ref.watch(authStateChangesProvider);
  return ref.watch(friendsRepositoryProvider).fetchBlockedIds();
});

/// Reactions on pokes the user SENT — the passive poke-back feed.
final pokeBacksProvider = FutureProvider.autoDispose<List<PokeBack>>((ref) {
  if (!SupabaseConfig.isConfigured) return const [];
  ref.watch(authStateChangesProvider);
  return ref.watch(friendsRepositoryProvider).fetchPokeBacks();
});

/// Accept/decline actions with loading + error state.
final respondInviteControllerProvider =
    AsyncNotifierProvider.autoDispose<RespondInviteController, void>(
  RespondInviteController.new,
);

class RespondInviteController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Action-only notifier.
  }

  /// Returns true on success.
  Future<bool> respond({required String inviteId, required bool accept}) async {
    final repo = ref.read(friendsRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => repo.respondToInvite(inviteId: inviteId, accept: accept),
    );
    if (state.hasError) return false;

    ref.invalidate(myInvitesProvider);
    if (accept) {
      // The freshly joined quest appears in the overview.
      ref.invalidate(myChallengesProvider);
    }
    return true;
  }
}
