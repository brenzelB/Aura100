import 'dart:async';

import 'package:aura_quest/features/auth/data/oauth_browser_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final session = Session(
    accessToken: 'test-access-token',
    tokenType: 'bearer',
    user: User(
      id: 'test-user',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-16T08:33:00Z',
    ),
  );
  late StreamController<AuthState> events;
  late OAuthBrowserSession browser;
  late int dismissals;

  setUp(() {
    events = StreamController<AuthState>.broadcast(sync: true);
    dismissals = 0;
    browser = OAuthBrowserSession(
      authEvents: events.stream,
      closeBrowser: () async => dismissals++,
    );
  });

  tearDown(() async {
    browser.cancel();
    await events.close();
  });

  test('dismisses once only after the OAuth session is accepted', () async {
    await browser.launch(() async => true);
    events.add(AuthState(AuthChangeEvent.initialSession, session));
    events.add(AuthState(AuthChangeEvent.tokenRefreshed, session));
    events.add(const AuthState(AuthChangeEvent.signedIn, null));
    expect(dismissals, 0);
    events.add(AuthState(AuthChangeEvent.signedIn, session));
    events.add(AuthState(AuthChangeEvent.signedIn, session));
    expect(dismissals, 1);
  });

  test('observes callbacks that arrive before the browser launch resolves',
      () async {
    final opened = Completer<bool>();
    final launching = browser.launch(() => opened.future);
    events.add(AuthState(AuthChangeEvent.signedIn, session));
    expect(dismissals, 1);
    opened.complete(true);
    expect(await launching, isTrue);
  });

  test('does not retain listeners after failed or cancelled launches',
      () async {
    expect(await browser.launch(() async => false), isFalse);
    events.add(AuthState(AuthChangeEvent.signedIn, session));
    expect(dismissals, 0);
    await expectLater(
        browser.launch(() async => throw StateError('launch failed')),
        throwsStateError);
    events.add(AuthState(AuthChangeEvent.signedIn, session));
    expect(dismissals, 0);
  });

  test('a retry replaces the previous listener and cancellation is safe',
      () async {
    await browser.launch(() async => true);
    await browser.launch(() async => true);
    events.add(AuthState(AuthChangeEvent.signedIn, session));
    expect(dismissals, 1);
    await browser.launch(() async => true);
    browser.cancel();
    events.add(AuthState(AuthChangeEvent.signedIn, session));
    expect(dismissals, 1);
  });

  test('failed authentication cannot dismiss a later browser', () async {
    await browser.launch(() async => true);
    events.addError(const AuthException('callback rejected'), StackTrace.empty);
    events.add(AuthState(AuthChangeEvent.signedIn, session));
    expect(dismissals, 0);
  });

  testWidgets('an abandoned flow expires without closing another browser',
      (tester) async {
    await browser.launch(() async => true);
    await tester.pump(const Duration(minutes: 11));
    events.add(AuthState(AuthChangeEvent.signedIn, session));
    expect(dismissals, 0);
  });
}
