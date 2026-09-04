import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/push/push_service.dart';

/// Thin wrapper around Supabase Auth.
///
/// Screens and controllers never talk to `Supabase.instance` directly —
/// everything goes through this repository. That keeps the Supabase SDK
/// out of the UI layer and makes auth trivially mockable in tests.
///
/// Every method logs failures in detail (code, status, message) to the
/// debug console BEFORE rethrowing, so the exact reason for an auth
/// failure is always visible in `flutter run` output / logcat. The
/// rethrow keeps the AsyncValue error flow (SnackBars) working.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// The active session, or null when logged out.
  Session? get currentSession => _client.auth.currentSession;

  /// The logged-in user, or null when logged out.
  User? get currentUser => _client.auth.currentUser;

  /// Fires on every auth event: signed in, signed out, token refreshed...
  /// The router listens to this to re-evaluate its redirect logic.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _guarded('signInWithEmail', () async {
        await _client.auth.signInWithPassword(email: email, password: password);
        debugPrint('✅ [AuthRepository.signInWithEmail] signed in as $email');
      });

  /// Creates a new account. With email confirmations disabled (local dev)
  /// this returns a live session immediately; with confirmations enabled
  /// the user first has to click the link in their inbox.
  ///
  /// [username] travels in the auth metadata; the `handle_new_user`
  /// database trigger reads it to create the player's profile row.
  ///
  /// `emailRedirectTo` decides where the confirmation link drops the user
  /// once the server has accepted the token — a WEB page, not the deep
  /// link. Pointing it at the app scheme looked elegant and failed badly:
  /// on a laptop nothing opens, so the click seems to do nothing, while
  /// it has in fact already consumed the token. The six-digit code then
  /// answers "token has expired" and the player concludes the sign-up
  /// broke, although the account is confirmed. See
  /// [SupabaseConfig.confirmRedirectUrl].
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) =>
      _guarded('signUpWithEmail', () async {
        final response = await _client.auth.signUp(
          email: email,
          password: password,
          data: {'username': username},
          emailRedirectTo:
              kIsWeb ? null : SupabaseConfig.confirmRedirectUrl,
        );
        debugPrint(
          '✅ [AuthRepository.signUpWithEmail] user created: '
          '${response.user?.email} — session: '
          '${response.session != null ? 'ACTIVE' : 'NONE (email confirmation pending)'}',
        );
      });

  /// Confirms a new account with the six-digit code from the mail.
  ///
  /// The mail carries both a link and a code — and they are the SAME
  /// token. Using one spends the other. That is why a failure here is
  /// usually not a failure at all: the player clicked the link first,
  /// the account is already confirmed, and all that is left to do is
  /// sign in. The caller has to say so rather than repeat the raw
  /// "token has expired".
  ///
  /// On success GoTrue returns a live session, so the player is signed
  /// in without typing their password again.
  Future<void> confirmSignupWithCode({
    required String email,
    required String code,
  }) =>
      _guarded('confirmSignupWithCode', () async {
        await _client.auth.verifyOTP(
          type: OtpType.signup,
          email: email,
          token: code,
        );
        debugPrint('✅ [AuthRepository.confirmSignupWithCode] confirmed $email');
      });

  /// Sends the confirmation mail again.
  ///
  /// Mail gets lost, lands in spam, or the link expires — without this the
  /// account is stranded, because signing up a second time with the same
  /// address is refused. GoTrue rate-limits this server-side, so the
  /// button cannot be used to hammer somebody's inbox.
  Future<void> resendConfirmation(String email) =>
      _guarded('resendConfirmation', () async {
        await _client.auth.resend(
          type: OtpType.signup,
          email: email,
          emailRedirectTo:
              kIsWeb ? null : SupabaseConfig.confirmRedirectUrl,
        );
        debugPrint('✅ [AuthRepository.resendConfirmation] sent to $email');
      });

  // ── Forgotten password ─────────────────────────────────────────────
  //
  // Three steps, because a password reset is one: ask for the mail, prove
  // you received it, then choose the new password. The proof is the code
  // from the mail rather than the link, for the same reason as sign-up —
  // a link only works on the device that has the app.

  /// Sends the recovery mail. Deliberately says nothing about whether the
  /// address exists: callers report success either way, so this cannot be
  /// used to find out who has an account here.
  Future<void> sendPasswordReset(String email) =>
      _guarded('sendPasswordReset', () async {
        await _client.auth.resetPasswordForEmail(
          email,
          redirectTo: kIsWeb ? null : SupabaseConfig.oauthRedirectUri,
        );
        debugPrint('✅ [AuthRepository.sendPasswordReset] mail sent to $email');
      });

  /// Redeems the recovery code. On success the user holds a session —
  /// which is exactly what [updatePassword] needs, and also why the caller
  /// must keep them on the reset screen until the new password is set.
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) =>
      _guarded('verifyRecoveryCode', () async {
        await _client.auth.verifyOTP(
          type: OtpType.recovery,
          email: email,
          token: code,
        );
        debugPrint('✅ [AuthRepository.verifyRecoveryCode] verified $email');
      });

  /// Sets a new password for the currently signed-in user.
  Future<void> updatePassword(String newPassword) =>
      _guarded('updatePassword', () async {
        await _client.auth.updateUser(UserAttributes(password: newPassword));
        debugPrint('✅ [AuthRepository.updatePassword] password changed');
      });

  /// Opens the Google OAuth flow in the browser.
  ///
  /// On mobile the browser hands control back to the app via the deep link
  /// in [SupabaseConfig.oauthRedirectUri] — see README for the required
  /// AndroidManifest / Info.plist setup. On web, Supabase redirects back
  /// to the site itself, so no redirectTo is needed.
  Future<void> signInWithGoogle() => _guarded('signInWithGoogle', () async {
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb ? null : SupabaseConfig.oauthRedirectUri,
        );
        debugPrint('✅ [AuthRepository.signInWithGoogle] browser flow launched');
      });

  Future<void> signOut() => _guarded('signOut', () async {
        try {
          await PushService.instance.unregisterAll();
        } catch (e) {
          debugPrint('⚠ [AuthRepository.signOut] push unregister failed: $e');
        }
        await _client.auth.signOut();
        debugPrint('✅ [AuthRepository.signOut] signed out');
      });

  // ── Deep error logging ─────────────────────────────────────────────

  /// Runs [action], logging any failure with full detail, then rethrows
  /// so callers (AuthController → AsyncValue → SnackBar) still see it.
  Future<void> _guarded(String method, Future<void> Function() action) async {
    try {
      await action();
    } on AuthApiException catch (e) {
      // Server rejected the request (wrong password, provider disabled,
      // signups disabled, rate limit, ...). `code` is the machine-readable
      // reason — the fastest way to diagnose what went wrong.
      debugPrint(
        '⛔ [AuthRepository.$method] AuthApiException\n'
        '   code:       ${e.code}\n'
        '   statusCode: ${e.statusCode}\n'
        '   message:    ${e.message}',
      );
      rethrow;
    } on AuthException catch (e) {
      // Other auth-layer failures. AuthRetryableFetchException here means
      // the server was UNREACHABLE (wrong URL, emulator networking, stack
      // not running) rather than the request being rejected.
      debugPrint(
        '⛔ [AuthRepository.$method] ${e.runtimeType}\n'
        '   message: ${e.message}\n'
        '   hint:    ${e is AuthRetryableFetchException ? 'Server unreachable — is the Supabase URL correct for this platform (Android emulator → http://10.0.2.2:54321) and the local stack running?' : 'Auth request rejected by server.'}',
      );
      rethrow;
    } on Exception catch (e, stackTrace) {
      // Anything else (SocketException, FormatException, ...) — log with
      // stack trace, since these are the truly unexpected ones.
      debugPrint('⛔ [AuthRepository.$method] Unexpected ${e.runtimeType}: $e');
      debugPrintStack(stackTrace: stackTrace, maxFrames: 8);
      rethrow;
    }
  }
}
