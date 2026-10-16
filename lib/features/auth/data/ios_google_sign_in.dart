import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

/// The OS owns this authentication sheet and dismisses it when its callback
/// arrives. A plain Safari controller cannot reliably provide that lifecycle.
class IosGoogleSignIn {
  IosGoogleSignIn(this._auth);

  static const _channel = MethodChannel('uk.brenzel.auraquest/google-auth');
  final GoTrueClient _auth;
  Object? _attempt;

  Future<void> signIn() async {
    if (_attempt != null) {
      throw const AuthException('Google sign-in is already in progress.');
    }
    final attempt = Object();
    _attempt = attempt;
    try {
      // Keep Supabase's existing PKCE verifier, provider and redirect. Only
      // replace the presentation; the SDK still validates/exchanges the code.
      final response = await _auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: SupabaseConfig.oauthRedirectUri,
      );
      if (_attempt != attempt) return;
      final callback = await _channel.invokeMethod<String>(
        'authenticate',
        {'url': response.url},
      );
      if (_attempt != attempt) return;
      final uri = callback == null ? null : Uri.tryParse(callback);
      final expected = Uri.parse(SupabaseConfig.oauthRedirectUri);
      if (uri == null ||
          uri.scheme != expected.scheme ||
          uri.host != expected.host ||
          uri.path != expected.path ||
          uri.hasPort ||
          uri.userInfo.isNotEmpty ||
          uri.fragment.isNotEmpty ||
          (!uri.queryParameters.containsKey('error') &&
              (uri.queryParametersAll['code']?.length != 1 ||
                  uri.queryParameters['code']!.isEmpty))) {
        throw const AuthException('Invalid Google sign-in callback.');
      }
      await _auth.getSessionFromUrl(uri);
    } on PlatformException catch (error) {
      if (_attempt != attempt || error.code == 'cancelled') return;
      throw const AuthException(
        'Could not complete Google sign-in. Please try again.',
      );
    } finally {
      if (_attempt == attempt) _attempt = null;
    }
  }

  /// Invalidate the callback before switching account/sign-in method. The
  /// pending native result must not sign in after a user chose another flow.
  void cancel() {
    if (_attempt == null) return;
    _attempt = null;
    unawaited(_cancelNative());
  }

  Future<void> _cancelNative() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (error) {
      debugPrint(
          'Could not cancel Google authentication: ${error.runtimeType}');
    }
  }
}
