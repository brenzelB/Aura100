import 'dart:async';
import 'dart:convert';

import 'package:aura_quest/core/config/supabase_config.dart';
import 'package:aura_quest/features/auth/data/ios_google_sign_in.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Storage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async => values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('uk.brenzel.auraquest/google-auth');
  const redirect = SupabaseConfig.oauthRedirectUri;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late GoTrueClient auth;
  late IosGoogleSignIn google;
  late List<http.Request> requests;
  late List<MethodCall> nativeCalls;
  late Future<String?> Function(MethodCall) native;
  late bool rejectExchange;

  setUp(() {
    requests = [];
    nativeCalls = [];
    rejectExchange = false;
    native = (_) async => '$redirect?code=accepted-code';
    auth = GoTrueClient(
      url: 'https://auth.example.test/auth/v1',
      autoRefreshToken: false,
      asyncStorage: _Storage(),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (rejectExchange) {
          return http.Response(
            jsonEncode({'msg': 'Invalid grant', 'error_code': 'invalid_grant'}),
            400,
          );
        }
        return http.Response(
          jsonEncode({
            'access_token': 'test-access-token',
            'refresh_token': 'test-refresh-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'test-user',
              'aud': 'authenticated',
              'created_at': '2026-10-16T08:33:00Z',
              'app_metadata': {'provider': 'google'},
              'user_metadata': {},
            },
          }),
          200,
        );
      }),
    );
    google = IosGoogleSignIn(auth);
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call);
      if (call.method == 'cancel') return null;
      return native(call);
    });
  });

  tearDown(() async {
    google.cancel();
    auth.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('uses native auth and the real SDK exchanges its PKCE callback once',
      () async {
    final signedIn = auth.onAuthStateChange.firstWhere(
      (state) => state.event == AuthChangeEvent.signedIn,
    );
    await google.signIn();
    expect((await signedIn).session?.user.id, 'test-user');
    expect(auth.currentSession?.user.id, 'test-user');
    expect(nativeCalls.single.method, 'authenticate');
    final url =
        Uri.parse((nativeCalls.single.arguments as Map)['url'] as String);
    expect(url.origin, 'https://auth.example.test');
    expect(url.path, '/auth/v1/authorize');
    expect(url.queryParameters['provider'], 'google');
    expect(url.queryParameters['redirect_to'], redirect);
    expect(url.queryParameters['code_challenge_method'], 's256');
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/auth/v1/token');
    expect(requests.single.url.queryParameters['grant_type'], 'pkce');
    final body = jsonDecode(requests.single.body) as Map;
    expect(body['auth_code'], 'accepted-code');
    expect(
      base64Url
          .encode(sha256
              .convert(utf8.encode(body['code_verifier'] as String))
              .bytes)
          .replaceAll('=', ''),
      url.queryParameters['code_challenge'],
    );
  });

  test(
      'user cancellation is quiet, creates no session and allows a fresh retry',
      () async {
    native = (_) async => throw PlatformException(code: 'cancelled');
    await google.signIn();
    expect(auth.currentSession, isNull);
    expect(requests, isEmpty);
    native = (_) async => '$redirect?code=retry-code';
    await google.signIn();
    expect(auth.currentSession, isNotNull);
    expect(requests, hasLength(1));
    expect(jsonDecode(requests.single.body)['auth_code'], 'retry-code');
    final urls = nativeCalls
        .map((c) => Uri.parse((c.arguments as Map)['url'] as String));
    expect(urls.first.queryParameters['code_challenge'],
        isNot(urls.last.queryParameters['code_challenge']));
  });

  for (final callback in [
    'other://login-callback/?code=untrusted',
    'io.supabase.auraquest://other/?code=untrusted',
    'io.supabase.auraquest://login-callback/other?code=untrusted',
    'io.supabase.auraquest://user@login-callback/?code=untrusted',
    'io.supabase.auraquest://login-callback:123/?code=untrusted',
    '$redirect?code=one&code=two',
    '$redirect?code=',
    '$redirect#access_token=injected&refresh_token=injected',
    '$redirect?access_token=injected&refresh_token=injected',
  ]) {
    test('rejects callback outside the expected PKCE redirect: $callback',
        () async {
      native = (_) async => callback;
      await expectLater(google.signIn(), throwsA(isA<AuthException>()));
      expect(auth.currentSession, isNull);
      expect(requests, isEmpty);
    });
  }

  test('provider rejection does not create a session or exchange a code',
      () async {
    native =
        (_) async => '$redirect?error=access_denied&error_description=Denied';
    await expectLater(google.signIn(), throwsA(isA<AuthException>()));
    expect(auth.currentSession, isNull);
    expect(requests, isEmpty);
  });

  test('failed PKCE validation is not reported as a successful login',
      () async {
    rejectExchange = true;
    await expectLater(google.signIn(), throwsA(isA<AuthException>()));
    expect(auth.currentSession, isNull);
    expect(requests, hasLength(1));
  });

  test(
      'a repeated tap cannot replace the pending PKCE verifier or native sheet',
      () async {
    final opened = Completer<void>();
    final callback = Completer<String>();
    native = (_) {
      opened.complete();
      return callback.future;
    };
    final signingIn = google.signIn();
    await opened.future;
    await expectLater(google.signIn(), throwsA(isA<AuthException>()));
    expect(nativeCalls, hasLength(1));
    callback.complete('$redirect?code=first-code');
    await signingIn;
    expect(auth.currentSession, isNotNull);
    expect(requests, hasLength(1));
  });

  test('switching sign-in methods invalidates a late native callback',
      () async {
    final opened = Completer<void>();
    final callback = Completer<String>();
    native = (_) {
      opened.complete();
      return callback.future;
    };
    final signingIn = google.signIn();
    await opened.future;
    google.cancel();
    callback.complete('$redirect?code=stale-code');
    await signingIn;
    expect(nativeCalls.map((c) => c.method), ['authenticate', 'cancel']);
    expect(auth.currentSession, isNull);
    expect(requests, isEmpty);
  });

  test(
      'native startup failure can be retried without leaving a pending attempt',
      () async {
    native = (_) async => throw PlatformException(code: 'unavailable');
    await expectLater(google.signIn(), throwsA(isA<AuthException>()));
    expect(auth.currentSession, isNull);
    native = (_) async => '$redirect?code=retry-code';
    await google.signIn();
    expect(auth.currentSession, isNotNull);
  });
}
