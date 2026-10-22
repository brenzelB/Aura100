import 'package:aura_quest/core/feedback/feedback_settings.dart';
import 'package:aura_quest/core/feedback/interaction_feedback.dart';
import 'package:aura_quest/core/theme/app_colors.dart';
import 'package:aura_quest/core/theme/app_theme.dart';
import 'package:aura_quest/features/profile/presentation/widgets/feedback_settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/recording_feedback.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  tearDown(
      () => AppColors.apply(AppThemeType.neoBrutalist, AppThemeMode.light));
  for (final theme in AppThemeType.values) {
    for (final mode in AppThemeMode.values) {
      for (final width in [320.0, 900.0]) {
        testWidgets(
            '${theme.name}/${mode.name} feedback controls at $width with large text',
            (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          AppColors.apply(theme, mode);
          final feedback = RecordingFeedback();
          final container = ProviderContainer(overrides: [
            interactionFeedbackProvider.overrideWithValue(feedback)
          ]);
          addTearDown(container.dispose);
          await container.read(feedbackSettingsProvider.future);
          await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.build(theme, mode),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.8)),
                child: child!,
              ),
              home: const Scaffold(
                  body: SingleChildScrollView(
                      padding: EdgeInsets.all(20),
                      child: FeedbackSettingsSection())),
            ),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('TRY FEEDBACK'));
          await tester.tap(find.text('TRY FEEDBACK'));
          expect(feedback.cues, [FeedbackCue.checkIn]);
          await tester.ensureVisible(find.text('Subtle sounds'));
          await tester.tap(find.text('Subtle sounds'));
          await tester.pumpAndSettle();
          expect(container.read(feedbackSettingsProvider).requireValue.sounds,
              isFalse);
          await tester.ensureVisible(find.text('Haptic feedback'));
          await tester.tap(find.text('Haptic feedback'));
          await tester.pumpAndSettle();
          expect(container.read(feedbackSettingsProvider).requireValue.haptics,
              isFalse);
          expect(
              tester
                  .widget<OutlinedButton>(find.byType(OutlinedButton))
                  .onPressed,
              isNull);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
