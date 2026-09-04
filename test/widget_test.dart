// Smoke test: the app boots and renders the splash screen.
//
// The auth providers are overridden so the test never touches a real
// Supabase client (main() — and thus Supabase.initialize — is not run in
// widget tests). We stay on the splash route and tear the tree down before
// its 2-second navigation timer fires.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura_quest/app.dart';
import 'package:aura_quest/features/auth/application/auth_providers.dart';

void main() {
  testWidgets('boots and shows the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // No live backend in tests: feed the router an empty auth stream
          // and a null user instead of hitting Supabase.instance.
          authStateChangesProvider.overrideWith((ref) => const Stream.empty()),
          currentUserProvider.overrideWithValue(null),
        ],
        child: const AuraQuestApp(),
      ),
    );

    // First frame: the splash screen's branding is on screen.
    expect(find.text('AURA QUEST'), findsOneWidget);

    // Dispose the tree so SplashScreen.dispose() cancels its pending timer,
    // avoiding a "Timer is still pending" failure.
    await tester.pumpWidget(const SizedBox());
  });
}
