import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../auth/application/auth_providers.dart';
import '../../challenges/application/challenge_providers.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});

/// The logged-in user's profile (username, member since).
///
/// - Re-fetches automatically on every auth event (login, logout,
///   token refresh) because it watches [authStateChangesProvider].
/// - Returns null when logged out or in offline skeleton mode.
final currentProfileProvider = FutureProvider.autoDispose<Profile?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  ref.watch(authStateChangesProvider); // rebuild on auth events
  return ref.watch(profileRepositoryProvider).fetchCurrentProfile();
});

/// Lifetime player stats for the profile screen.
final myStatsProvider = FutureProvider.autoDispose<PlayerStats?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  ref.watch(authStateChangesProvider);
  ref.watch(myChallengesProvider);
  return ref.watch(profileRepositoryProvider).fetchStats();
});

/// Profile edits (rename) and account deletion.
///
/// Must be `ref.watch`ed by the screen: being autoDispose, an unwatched
/// provider is destroyed mid-`await` and the flow dies silently.
final profileControllerProvider =
    AsyncNotifierProvider.autoDispose<ProfileController, void>(
  ProfileController.new,
);

class ProfileController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Action-only notifier.
  }

  /// Returns true on success; errors land in `state` for the UI.
  Future<bool> rename(String username) async {
    final repo = ref.read(profileRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repo.updateUsername(username));
    if (state.hasError) return false;

    ref.invalidate(currentProfileProvider);
    return true;
  }

  /// Sets the avatar emoji (null clears it). Returns true on success.
  Future<bool> setAvatarEmoji(String? emoji) async {
    final repo = ref.read(profileRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repo.updateAvatarEmoji(emoji));
    if (state.hasError) return false;

    ref.invalidate(currentProfileProvider);
    return true;
  }

  /// Deletes the account. On success Supabase drops the session, so the
  /// router's auth guard sends the user back to /login by itself.
  Future<bool> deleteAccount() async {
    final repo = ref.read(profileRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repo.deleteAccount();
      // The user row is gone; end the local session too so the app
      // can't keep using a token for a deleted account.
      await ref.read(authRepositoryProvider).signOut();
    });
    return !state.hasError;
  }

  /// Resets player stats. Returns true on success.
  Future<bool> resetStats() async {
    final repo = ref.read(profileRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repo.resetStats());
    if (state.hasError) return false;

    ref.invalidate(myStatsProvider);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(myChallengesProvider);
    return true;
  }
}
