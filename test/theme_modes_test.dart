import 'package:aura_quest/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Perceived luminance — good enough to assert "this is a dark theme".
double _luminance(Color c) => c.computeLuminance();

void main() {
  group('Theme modes', () {
    test('every design system ships a light AND a dark palette', () {
      for (final type in AppThemeType.values) {
        final light = paletteFor(type, AppThemeMode.light);
        final dark = paletteFor(type, AppThemeMode.dark);

        expect(light.isDark, isFalse, reason: '${type.name} light');
        expect(dark.isDark, isTrue, reason: '${type.name} dark');
        expect(identical(light, dark), isFalse,
            reason: '${type.name} must have two distinct palettes');
      }
    });

    test('dark backgrounds are dark, light backgrounds are light', () {
      for (final type in AppThemeType.values) {
        expect(_luminance(paletteFor(type, AppThemeMode.dark).background),
            lessThan(0.15),
            reason: '${type.name} dark background should be dark');
        expect(_luminance(paletteFor(type, AppThemeMode.light).background),
            greaterThan(0.7),
            reason: '${type.name} light background should be light');
      }
    });

    test('text stays readable against its own background', () {
      for (final type in AppThemeType.values) {
        for (final mode in AppThemeMode.values) {
          final p = paletteFor(type, mode);
          final contrast =
              (_luminance(p.textPrimary) - _luminance(p.background)).abs();
          expect(contrast, greaterThan(0.4),
              reason: '${type.name}/${mode.name} primary text contrast');
          // Surfaces must not collide with the page behind them.
          expect(p.surface, isNot(equals(p.outline)),
              reason: '${type.name}/${mode.name} surface vs outline');
        }
      }
    });

    test('AppColors.apply switches the global palette and tracking', () {
      AppColors.apply(AppThemeType.auralis, AppThemeMode.dark);
      expect(AppColors.activeType, AppThemeType.auralis);
      expect(AppColors.currentMode, AppThemeMode.dark);
      expect(AppColors.isDark, isTrue);
      expect(AppColors.background, auralisDarkColors.background);

      AppColors.apply(AppThemeType.neoBrutalist, AppThemeMode.light);
      expect(AppColors.activeType, AppThemeType.neoBrutalist);
      expect(AppColors.isDark, isFalse);
      expect(AppColors.background, neoBrutalistColors.background);
    });

    test('light palettes keep their original hand-picked values', () {
      // Guards the user's design work against accidental drift.
      expect(neoBrutalistColors.background, const Color(0xFFF6F2DF));
      expect(neoBrutalistColors.outline, const Color(0xFF191919));
      expect(editorialColors.neonCyan, const Color(0xFFE65C4F));
      expect(editorialColors.inputOutline, const Color(0xFF8C716D));
      expect(auralisColors.neonPurple, const Color(0xFF5457E8));
      expect(auralisColors.outline, const Color(0xFFE3E5E9));
    });
  });
}
