import 'package:aura_quest/core/theme/app_colors.dart';
import 'package:aura_quest/core/theme/app_theme.dart';
import 'package:aura_quest/features/auth/application/auth_providers.dart';
import 'package:aura_quest/features/challenges/data/quest_draft_store.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/create_challenge_sheet.dart';
import 'package:aura_quest/features/friends/application/friends_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// A device clock on a different calendar day, independent of the test host's
// timezone. This reproduces Berlin's midnight bug on Windows and Linux alike.
class _DeviceClock extends Fake implements DateTime {
  _DeviceClock(this.deviceDay, this.utc);
  final DateTime deviceDay;
  final DateTime utc;

  @override
  int get year => deviceDay.year;
  @override
  int get month => deviceDay.month;
  @override
  int get day => deviceDay.day;
  @override
  DateTime toUtc() => utc;
}

final _owner = User(
  id: 'schedule-owner',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-24T00:00:00Z',
);

Future<void> _openSchedule(WidgetTester tester, DateTime now) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(_owner),
      myFriendsProvider.overrideWith((ref) => []),
    ],
    child: MaterialApp(
      theme: AppTheme.build(AppThemeType.neoBrutalist, AppThemeMode.light),
      home: Scaffold(body: CreateChallengeSheet(now: () => now)),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Quest name'), 'Start today');
  await tester.tap(find.text('NEXT'));
  await tester.pumpAndSettle();
}

void _expectDate(DateTime actual, DateTime expected) {
  expect((actual.year, actual.month, actual.day),
      (expected.year, expected.month, expected.day));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    AppColors.apply(AppThemeType.neoBrutalist, AppThemeMode.light);
  });

  for (final deviceAhead in [true, false]) {
    testWidgets(
        'Today starts in the current server day when device is '
        '${deviceAhead ? 'ahead of' : 'behind'} UTC', (tester) async {
      final utc = DateTime.utc(2026, 10, deviceAhead ? 24 : 25, 22, 10);
      final deviceDay = DateTime.utc(2026, 10, deviceAhead ? 25 : 24);
      await _openSchedule(tester, _DeviceClock(deviceDay, utc));
      expect(find.text('Today'), findsOneWidget);
      expect(find.textContaining('your time (00:00 UTC)'), findsOneWidget);
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      final picker =
          tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      _expectDate(picker.initialDate!, utc);
      _expectDate(picker.firstDate, utc);
      _expectDate(picker.currentDate, utc);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final draft = (await QuestDraftStore().load(_owner.id))!;
      final start = DateTime.parse(draft['starts'] as String);
      final end = DateTime.parse(draft['ends'] as String);
      _expectDate(start, utc);
      expect(end.difference(start).inDays, 6);
      expect(draft['schedule_utc'], isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  for (final legacy in [true, false]) {
    testWidgets(
        legacy
            ? 'legacy midnight draft starts now and keeps its seven-day duration'
            : 'an explicitly scheduled UTC draft keeps its future start',
        (tester) async {
      final utc = DateTime.utc(2026, 10, 24, 22, 10);
      await QuestDraftStore().save(_owner.id, {
        'title': 'Start today',
        'starts': '2026-10-25T00:00:00.000Z',
        'ends': '2026-10-31T00:00:00.000Z',
        if (!legacy) 'schedule_utc': true,
      });
      await _openSchedule(
          tester, _DeviceClock(DateTime.utc(2026, 10, 25), utc));
      expect(find.text(legacy ? 'Today' : 'Oct 25, 2026'), findsOneWidget);
      expect(
          find.text(legacy ? 'Oct 30, 2026' : 'Oct 31, 2026'), findsOneWidget);
      expect(find.text('7 days total'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
