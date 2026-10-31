import 'package:aura_quest/features/challenges/application/challenge_providers.dart';
import 'package:aura_quest/features/profile/application/profile_providers.dart';
import 'package:aura_quest/features/profile/data/profile_repository.dart';
import 'package:aura_quest/features/profile/domain/profile.dart';
import 'package:aura_quest/features/profile/presentation/screens/profile_screen.dart';
import 'package:aura_quest/features/profile/presentation/widgets/notification_settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The profile must be able to ask for the system permission.
///
/// It could not. The only thing in the whole app that summoned the
/// system prompt was a card on the home screen, below the activity feed
/// and the weekly recap, which disappeared for good as soon as it was
/// answered or waved away. The profile offered category switches and a
/// snack bar saying "You can turn them on in Profile" — a promise it
/// had no means to keep.
///
/// On iOS that is a locked door rather than an inconvenience: an app
/// appears under Settings > Notifications only AFTER it has asked at
/// least once, so a player who never saw the card could not grant the
/// permission from the system settings either. Six iPhones were
/// registered for push and had notifications accepted by FCM; not one
/// could display them.
/// The screen only needs an address from it; nothing here is reset.
class _Repository implements ProfileRepository {
  @override
  String? get currentEmail => 'test@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('profile offers a way to grant the system permission',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      profileRepositoryProvider.overrideWithValue(_Repository()),
      currentProfileProvider.overrideWith((ref) async =>
          Profile(id: 'test', username: 'Tester', createdAt: DateTime(2026))),
      myStatsProvider.overrideWith((ref) async => null),
      trophiesProvider.overrideWith((ref) async => []),
      activityByDayProvider.overrideWith((ref) async => {}),
      myChallengesProvider.overrideWith((ref) async => []),
      questRemindersProvider.overrideWith((ref) async => {}),
      notificationSettingsProvider
          .overrideWith((ref) async => const NotificationSettings()),
    ], child: const MaterialApp(home: ProfileScreen())));
    await tester.pumpAndSettle();

    // No notification plugin is registered under test, so the service
    // reports "not determined" — the same state as a phone that has
    // never been asked, which is exactly the case under test.
    final allow = find.widgetWithText(ElevatedButton, 'ALLOW NOTIFICATIONS');
    await tester.scrollUntilVisible(allow, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    expect(allow, findsOneWidget);
    expect(find.text('NOTHING CAN REACH YOU'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
