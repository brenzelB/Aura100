import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'design_tokens.dart';

/// One component system, three optional palettes, two deliberate modes.
abstract class AppTheme {
  static ThemeData build(AppThemeType themeType, AppThemeMode mode) {
    final dark = mode == AppThemeMode.dark;
    final neo = themeType == AppThemeType.neoBrutalist;
    final primary = themeType == AppThemeType.editorial
        ? AppColors.neonPink
        : AppColors.neonCyan;
    final colors = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: primary,
      onPrimary: readableOn(primary),
      secondary: AppColors.neonPurple,
      onSecondary: readableOn(AppColors.neonPurple),
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      onError: readableOn(AppColors.danger),
      outline: AppColors.inputOutline,
    );
    final base = ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: AppColors.background,
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded);
    final family = switch (themeType) {
      AppThemeType.neoBrutalist => 'Hanken Grotesk',
      AppThemeType.editorial => 'Plus Jakarta Sans',
      AppThemeType.auralis => 'Inter',
    };
    TextStyle type(double size, FontWeight weight, {bool muted = false}) =>
        GoogleFonts.getFont(family,
            fontSize: size,
            fontWeight: weight,
            height: size >= 24 ? 1.12 : 1.4,
            letterSpacing: size >= 24 ? -.6 : 0,
            color: muted ? AppColors.textSecondary : AppColors.textPrimary);
    final text = base.textTheme.copyWith(
      displayLarge: type(44, FontWeight.w900),
      displayMedium: type(36, FontWeight.w900),
      displaySmall: type(30, FontWeight.w800),
      headlineLarge: type(28, FontWeight.w800),
      headlineMedium: type(24, FontWeight.w800),
      headlineSmall: type(18, FontWeight.w800),
      titleLarge: type(20, FontWeight.w800),
      titleMedium: type(16, FontWeight.w700),
      titleSmall: type(14, FontWeight.w700),
      bodyLarge: type(17, FontWeight.w500),
      bodyMedium: type(15, FontWeight.w500),
      bodySmall: type(13, FontWeight.w500, muted: true),
      labelLarge: type(14, FontWeight.w800),
      labelMedium: type(13, FontWeight.w700),
      labelSmall: type(12, FontWeight.w700),
    );
    final shape = AppShapes.panel;
    OutlineInputBorder input(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShapes.radius),
        borderSide: BorderSide(color: color, width: width));
    return base.copyWith(
      textTheme: text,
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
      focusColor: AppColors.neonPurple.withValues(alpha: .22),
      appBarTheme: AppBarTheme(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 20,
          actionsPadding: const EdgeInsets.only(right: 16),
          titleTextStyle: type(22, FontWeight.w900),
          toolbarHeight: 64,
          shape: Border(
              bottom: BorderSide(color: AppColors.outline, width: neo ? 2 : 1)),
          systemOverlayStyle:
              dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark),
      cardTheme: CardThemeData(
          color: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: shape,
          elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: readableOn(primary),
              disabledForegroundColor: AppColors.textSecondary,
              disabledBackgroundColor: AppColors.surfaceLight,
              minimumSize: const Size(48, 52),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              textStyle: text.labelLarge,
              shape: shape,
              elevation: neo ? 3 : 0,
              shadowColor: AppColors.shadow,
              animationDuration: const Duration(milliseconds: 120))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: readableOn(primary),
              minimumSize: const Size(48, 52),
              shape: shape)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              backgroundColor: AppColors.surface,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side:
                  BorderSide(color: AppColors.outline, width: AppShapes.stroke),
              shape: shape,
              textStyle: text.labelLarge)),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: AppColors.accentText,
              minimumSize: const Size(48, 48),
              textStyle: text.labelLarge)),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: AppColors.textPrimary,
              shape: shape)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: readableOn(primary),
          shape: shape,
          elevation: 3,
          extendedTextStyle: text.labelLarge),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintStyle: text.bodyMedium!.copyWith(color: AppColors.textSecondary),
          labelStyle: text.bodyMedium,
          errorMaxLines: 3,
          helperMaxLines: 3,
          border: input(AppColors.inputOutline, AppShapes.stroke),
          enabledBorder: input(AppColors.inputOutline, AppShapes.stroke),
          focusedBorder: input(AppColors.neonPurple, 3),
          errorBorder: input(AppColors.danger, 2),
          focusedErrorBorder: input(AppColors.danger, 3)),
      dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: AppShapes.dialog,
          elevation: 8,
          titleTextStyle: text.headlineMedium,
          contentTextStyle: text.bodyMedium,
          insetPadding: const EdgeInsets.all(20)),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          modalBackgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: AppShapes.sheet,
          showDragHandle: true,
          dragHandleColor: AppColors.textSecondary,
          clipBehavior: Clip.antiAlias),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          backgroundColor: AppColors.surface,
          contentTextStyle: text.bodyMedium,
          shape: shape,
          insetPadding: const EdgeInsets.all(12)),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 72,
          indicatorColor: primary,
          indicatorShape: shape,
          labelTextStyle: WidgetStateProperty.resolveWith((s) =>
              text.labelSmall!.copyWith(
                  color: s.contains(WidgetState.selected)
                      ? AppColors.textPrimary
                      : AppColors.textSecondary)),
          iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected)
                  ? readableOn(primary)
                  : AppColors.textSecondary))),
      chipTheme: ChipThemeData(
          backgroundColor: AppColors.surface,
          selectedColor: primary,
          labelStyle: text.labelMedium,
          secondaryLabelStyle:
              text.labelMedium!.copyWith(color: readableOn(primary)),
          side: BorderSide(color: AppColors.outline, width: AppShapes.stroke),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          showCheckmark: true),
      progressIndicatorTheme: ProgressIndicatorThemeData(
          color: AppColors.accentText,
          linearTrackColor: AppColors.surfaceLight,
          circularTrackColor: AppColors.surfaceLight,
          linearMinHeight: 10,
          borderRadius: BorderRadius.circular(3)),
      dividerTheme:
          DividerThemeData(color: AppColors.outline, thickness: 1, space: 24),
      listTileTheme: ListTileThemeData(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          titleTextStyle: text.titleMedium,
          subtitleTextStyle: text.bodySmall,
          iconColor: AppColors.textPrimary),
      expansionTileTheme: ExpansionTileThemeData(
          iconColor: AppColors.textPrimary,
          collapsedIconColor: AppColors.textSecondary,
          textColor: AppColors.textPrimary,
          collapsedTextColor: AppColors.textPrimary,
          childrenPadding: const EdgeInsets.all(16)),
      tabBarTheme: TabBarThemeData(
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: text.labelLarge,
          indicatorColor: AppColors.accentText,
          indicatorSize: TabBarIndicatorSize.tab),
      tooltipTheme: TooltipThemeData(
          textStyle: text.bodySmall!
              .copyWith(color: readableOn(AppColors.textPrimary)),
          decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(6))),
    );
  }
}
