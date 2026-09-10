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
import 'package:supabase_flutter/supabase_flutter.dart';

class _Repository implements ProfileRepository {
  _Repository(this.error);
  final Object error;
  int calls = 0;
  @override
  String? get currentEmail => 'test@example.com';
  @override
  Future<void> resetStats() async {
    calls++;
    throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const reason =
      'Finish or leave active quests and settle pending duels before resetting stats.';
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  for (final businessError in [true, false]) {
    testWidgets(
        'reset explains ${businessError ? 'eligibility' : 'unexpected failure'}',
        (tester) async {
      final repo = _Repository(businessError
          ? const PostgrestException(message: reason, code: 'P0001')
          : const PostgrestException(
              message: 'private internal database details', code: 'XX000'));
      await tester.pumpWidget(ProviderScope(overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
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
      await tester.scrollUntilVisible(
          find.widgetWithText(OutlinedButton, 'RESET LIFE STATS'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('RESET LIFE STATS'));
      await tester.pumpAndSettle();
      expect(find.textContaining('First finish or leave all active quests'),
          findsOneWidget);
      expect(repo.calls, 0);
      await tester.tap(find.text('RESET STATS'));
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      expect(
          find.text(businessError
              ? reason
              : 'Could not reset stats. Check your connection and try again.'),
          findsOneWidget);
      expect(find.text('private internal database details'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
