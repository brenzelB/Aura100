import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../data/auth_repository.dart';

/// Single source of truth for the [AuthRepository].
///
/// IMPORTANT: only read this provider when [SupabaseConfig.isConfigured]
/// is true — `Supabase.instance` throws if `Supabase.initialize` was
/// skipped (offline skeleton mode).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

/// Stream of auth events (sign-in, sign-out, token refresh).
/// Emits nothing in offline skeleton mode.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  if (!SupabaseConfig.isConfigured) return const Stream.empty();
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// The currently logged-in user, or null. Rebuilds on every auth event.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateChangesProvider); // re-evaluate when auth changes
  if (!SupabaseConfig.isConfigured) return null;
  return ref.watch(authRepositoryProvider).currentUser;
});

/// True while a password reset is between "code accepted" and "new
/// password saved".
///
/// Redeeming a recovery code signs the user in, which would normally send
/// the router straight to the dashboard — past the screen that asks for
/// the new password. The router checks this flag and lets the login route
/// stand until the reset is finished.
final passwordRecoveryInProgressProvider = StateProvider<bool>((ref) => false);

/// Runs auth actions and exposes their loading / error state to the UI.
///
/// `state` is AsyncLoading while an action runs (used to disable buttons
/// and show spinners) and AsyncError when Supabase rejects the request
/// (used to show a SnackBar).
final authControllerProvider =
    AsyncNotifierProvider.autoDispose<AuthController, void>(
  AuthController.new,
);

class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // No initial work — this notifier only exists to run actions.
  }

  /// Shared plumbing: run [action], capture errors, report success.
  Future<bool> _run(Future<void> Function(AuthRepository repo) action) async {
    final repo = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => action(repo));
    return !state.hasError;
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _run((repo) => repo.signInWithEmail(email: email, password: password));

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) =>
      _run((repo) => repo.signUpWithEmail(
            email: email,
            password: password,
            username: username,
          ));

  Future<bool> sendPasswordReset(String email) =>
      _run((repo) => repo.sendPasswordReset(email));

  Future<bool> verifyRecoveryCode({
    required String email,
    required String code,
  }) =>
      _run((repo) => repo.verifyRecoveryCode(email: email, code: code));

  Future<bool> updatePassword(String newPassword) =>
      _run((repo) => repo.updatePassword(newPassword));

  Future<bool> confirmSignupWithCode({
    required String email,
    required String code,
  }) =>
      _run((repo) => repo.confirmSignupWithCode(email: email, code: code));

  Future<bool> resendConfirmation(String email) =>
      _run((repo) => repo.resendConfirmation(email));

  Future<bool> signInWithGoogle() => _run((repo) => repo.signInWithGoogle());

  Future<bool> signOut() => _run((repo) => repo.signOut());
}
