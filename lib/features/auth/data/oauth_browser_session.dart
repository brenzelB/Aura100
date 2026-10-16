import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SFSafariViewController stays open after a custom-scheme OAuth callback.
/// Close only the browser belonging to an active sign-in, after Supabase has
/// accepted the callback. Token refreshes must never dismiss another browser.
class OAuthBrowserSession {
  OAuthBrowserSession({
    required Stream<AuthState> authEvents,
    required Future<void> Function() closeBrowser,
    Duration expiry = const Duration(minutes: 10),
  })  : _authEvents = authEvents,
        _closeBrowser = closeBrowser,
        _expiry = expiry;

  final Stream<AuthState> _authEvents;
  final Future<void> Function() _closeBrowser;
  final Duration _expiry;
  StreamSubscription<AuthState>? _subscription;
  Timer? _timer;

  Future<bool> launch(Future<bool> Function() openBrowser) async {
    cancel();
    _subscription = _authEvents.listen((state) {
      if (state.event == AuthChangeEvent.signedIn && state.session != null) {
        cancel();
        unawaited(_dismiss());
      }
    }, onError: (Object _, StackTrace __) {
      // Supabase owns error reporting; a failed callback is not a successful
      // sign-in and must not cause an unrelated browser to be dismissed later.
      cancel();
    });
    _timer = Timer(_expiry, cancel);
    try {
      final opened = await openBrowser();
      if (!opened) cancel();
      return opened;
    } catch (_) {
      cancel();
      rethrow;
    }
  }

  Future<void> _dismiss() async {
    try {
      await _closeBrowser();
    } catch (error) {
      // The authenticated session remains valid if native dismissal fails.
      debugPrint('Could not dismiss OAuth browser: ${error.runtimeType}');
    }
  }

  void cancel() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _timer?.cancel();
    _timer = null;
  }
}
