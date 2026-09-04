import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Central ThemeData builder for Aura Quest.
///
/// Typography strategy:
///  - **Cyber-Pixel**: 'Press Start 2P' (headlines) + 'Space Grotesk' (body)
///  - **Editorial Growth**: 'Source Serif 4' (headlines) + 'Plus Jakarta Sans' (body/labels for editorial look)
///  - **Auralis**: 'Inter' (headlines & body for Visual Scaffolding minimalism)
abstract class AppTheme {
  /// Builds the ThemeData for one design system in one mode. The
  /// caller must have applied the matching palette to [AppColors]
  /// first (ThemeNotifier does this before every rebuild).
  static ThemeData build(AppThemeType themeType, AppThemeMode mode) {
    final isAuralis = themeType == AppThemeType.auralis;
    final isEditorial = themeType == AppThemeType.editorial;
    final isNeoBrutalist = themeType == AppThemeType.neoBrutalist;
    final isDark = mode == AppThemeMode.dark;

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: AppColors.neonCyan,
            onPrimary: AppColors.onAccent,
            secondary: AppColors.neonPink,
            onSecondary: AppColors.onAccent,
            tertiary: AppColors.neonPurple,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
            error: AppColors.danger,
          )
        : ColorScheme.light(
            primary: AppColors.neonCyan,
            onPrimary: AppColors.background,
            secondary: AppColors.neonPink,
            onSecondary: AppColors.background,
            tertiary: AppColors.neonPurple,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
            error: AppColors.danger,
          );

    final base = ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: isEditorial
          ? Colors.transparent // Let the custom editorial painter show through
          : AppColors.background,
      colorScheme: colorScheme,
    );

    // Dynamic typography depending on the design theme:
    final TextStyle displayStyle;
    final TextTheme textThemeBase;

    switch (themeType) {
      case AppThemeType.neoBrutalist:
        textThemeBase = GoogleFonts.hankenGroteskTextTheme(base.textTheme);
        displayStyle = GoogleFonts.hankenGrotesk(
          fontWeight: FontWeight.w900, // Black weight (900)
          height: 1.1, // Tight leading
          color: AppColors.textPrimary,
        );
        break;
      case AppThemeType.editorial:
        textThemeBase = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
        displayStyle = GoogleFonts.sourceSerif4(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        );
        break;
      case AppThemeType.auralis:
        textThemeBase = GoogleFonts.interTextTheme(base.textTheme);
        // Bolder minimalism: heavier, tighter display type. Confident
        // Inter at high weight is Auralis' strongest, most under-used move.
        displayStyle = GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.02,
          color: AppColors.textPrimary,
        );
        break;
    }

    final textTheme = textThemeBase.copyWith(
      displayLarge: isEditorial
          ? displayStyle.copyWith(fontSize: 48, letterSpacing: -0.02 * 48)
          : (isNeoBrutalist
              ? displayStyle.copyWith(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -0.02 * 48)
              : displayStyle.copyWith(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -0.03 * 40)),
      displayMedium: isEditorial
          ? displayStyle.copyWith(fontSize: 32)
          : (isNeoBrutalist
              ? displayStyle.copyWith(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.01 * 32)
              : displayStyle.copyWith(fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -0.025 * 29)),
      displaySmall: isEditorial
          ? displayStyle.copyWith(fontSize: 24, fontWeight: FontWeight.w500)
          : (isNeoBrutalist
              ? displayStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w700)
              : displayStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.02 * 22)),
      headlineMedium: isEditorial
          ? displayStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w500)
          : (isNeoBrutalist
              ? displayStyle.copyWith(fontSize: 16)
              : displayStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.01 * 18)),
      headlineSmall: isEditorial
          ? displayStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w500)
          : (isNeoBrutalist
              ? displayStyle.copyWith(fontSize: 13)
              // Auralis section labels: a crisp, tracked system element,
              // consistent everywhere instead of a faint whisper.
              : displayStyle.copyWith(
                  fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.06 * 13)),
      titleLarge: isEditorial
          ? displayStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600)
          : (isNeoBrutalist
              ? displayStyle.copyWith(fontSize: 12)
              : displayStyle.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
      bodyLarge: isEditorial
          ? GoogleFonts.plusJakartaSans(fontSize: 18, color: AppColors.textPrimary)
          : (isNeoBrutalist
              ? GoogleFonts.hankenGrotesk(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary)
              : null),
      bodyMedium: isEditorial
          ? GoogleFonts.plusJakartaSans(fontSize: 16, color: AppColors.textPrimary)
          : (isNeoBrutalist
              ? GoogleFonts.hankenGrotesk(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary)
              : null),
      bodySmall: isEditorial
          ? GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary)
          : (isNeoBrutalist
              ? GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)
              : null),
    );

    return base.copyWith(
      textTheme: textTheme,

      // ── App bar: flat, quiet ────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: displayStyle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      // ── Cards: Neo-Brutalist uses 8px radius with 2px stroke, Editorial uses 24px, Auralis uses 24px flat white
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            switch (themeType) {
              AppThemeType.neoBrutalist => 8,
              AppThemeType.editorial => 24,
              AppThemeType.auralis => 24,
            },
          ),
          side: BorderSide(
            color: AppColors.outline,
            width: isNeoBrutalist ? 2.0 : 1.0,
          ),
        ),
      ),

      // ── Primary buttons: rounded 8px corners and 2px border for Neo-Brutalist (Yellow background, ink text)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isEditorial ? AppColors.neonPink : AppColors.neonCyan,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size.fromHeight(52),
          shape: switch (themeType) {
            AppThemeType.neoBrutalist => RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8), // rounded-md
                side: BorderSide(color: AppColors.outline, width: 2.0),
              ),
            AppThemeType.editorial => RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // rounded-lg
              ),
            AppThemeType.auralis => RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
          },
          textStyle: isAuralis
              ? GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.01,
                )
              : (isEditorial
                  ? GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    )
                  : (isNeoBrutalist
                      ? GoogleFonts.hankenGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        )
                      : GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ))),
        ),
      ),

      // ── Secondary buttons: rounded 8px corners and 2px border for Neo-Brutalist (White background, ink text)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: isNeoBrutalist ? AppColors.surface : null,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(
            color: isEditorial ? AppColors.neonCyan : AppColors.outline,
            width: isNeoBrutalist ? 2.0 : 1.0,
          ),
          shape: switch (themeType) {
            AppThemeType.neoBrutalist => RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            AppThemeType.editorial => RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            AppThemeType.auralis => RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
          },
          textStyle: isAuralis
              ? GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.01,
                )
              : (isEditorial
                  ? GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    )
                  : (isNeoBrutalist
                      ? GoogleFonts.hankenGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        )
                      : GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ))),
        ),
      ),

      // ── Text fields: Roundness matches overall design system
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: isAuralis
            ? GoogleFonts.inter(color: AppColors.textSecondary)
            : (isEditorial
                ? GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 16)
                : (isNeoBrutalist
                    ? GoogleFonts.hankenGrotesk(color: AppColors.textSecondary, fontSize: 16)
                    : GoogleFonts.spaceGrotesk(color: AppColors.textSecondary))),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            switch (themeType) {
              AppThemeType.neoBrutalist => 8,
              AppThemeType.editorial => 12,
              AppThemeType.auralis => 8,
            },
          ),
          borderSide: BorderSide(
            color: AppColors.inputOutline,
            width: isNeoBrutalist ? 1.5 : 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            switch (themeType) {
              AppThemeType.neoBrutalist => 8,
              AppThemeType.editorial => 12,
              AppThemeType.auralis => 8,
            },
          ),
          borderSide: BorderSide(
            color: isAuralis
                ? AppColors.neonPurple
                : (isNeoBrutalist ? AppColors.outline : AppColors.neonCyan),
            width: isNeoBrutalist ? 2.5 : 2.0,
          ),
        ),
      ),

      // ── Bottom navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: isEditorial
            ? AppColors.neonCyan.withValues(alpha: 0.15)
            : (isNeoBrutalist
                ? AppColors.neonCyan.withValues(alpha: 0.25)
                : AppColors.neonPurple.withValues(alpha: 0.15)),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          final fontStyle = isAuralis
              ? GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)
              : (isEditorial
                  ? GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)
                  : (isNeoBrutalist
                      ? GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w700)
                      : GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600)));
          return fontStyle.copyWith(
            color: selected
                ? (isEditorial ? AppColors.accentText : (isNeoBrutalist ? AppColors.textPrimary : AppColors.neonPurple))
                : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? (isEditorial ? AppColors.neonCyan : (isNeoBrutalist ? AppColors.textPrimary : AppColors.neonPurple))
                : AppColors.textSecondary,
          );
        }),
      ),
    );
  }
}
