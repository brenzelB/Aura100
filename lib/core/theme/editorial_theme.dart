import 'package:flutter/material.dart';
import 'app_colors.dart';

/// The magazine edition is opt-in. Other theme data never enters this path.
abstract class EditorialTheme {
  static ThemeData refine(ThemeData base) {
    TextStyle display(double size) => TextStyle(
          fontFamily: 'Editorial Display',
          fontSize: size,
          fontWeight: FontWeight.w400,
          height: 1.08,
          letterSpacing: -.7,
          color: AppColors.textPrimary,
        );
    final control =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final text = base.textTheme.copyWith(
      displayLarge: display(52),
      displayMedium: display(48),
      displaySmall: display(43),
      headlineLarge: display(38),
      headlineMedium: display(29),
      headlineSmall: display(22),
      titleLarge: display(24),
    );
    return base.copyWith(
      textTheme: text,
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle:
            base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        toolbarHeight: 56,
        shape: const Border(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: base.elevatedButtonTheme.style
              ?.copyWith(shape: WidgetStatePropertyAll(control))),
      filledButtonTheme: FilledButtonThemeData(
          style: base.filledButtonTheme.style
              ?.copyWith(shape: WidgetStatePropertyAll(control))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: base.outlinedButtonTheme.style
              ?.copyWith(shape: WidgetStatePropertyAll(control))),
      floatingActionButtonTheme:
          base.floatingActionButtonTheme.copyWith(shape: control, elevation: 0),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        indicatorShape: control,
        height: 72,
        indicatorColor: const Color(0xFFB7EBCC),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFF312149)
                  : AppColors.textSecondary,
            )),
      ),
      navigationRailTheme: base.navigationRailTheme.copyWith(
        indicatorShape: control,
        indicatorColor: const Color(0xFFB7EBCC),
        selectedIconTheme: const IconThemeData(color: Color(0xFF312149)),
      ),
      chipTheme: base.chipTheme.copyWith(shape: control),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accentText,
        selectionColor: AppColors.neonPink.withValues(alpha: .3),
        selectionHandleColor: AppColors.accentText,
      ),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
          borderRadius: BorderRadius.circular(12), linearMinHeight: 6),
      dialogTheme: base.dialogTheme.copyWith(titleTextStyle: display(28)),
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        ...base.pageTransitionsTheme.builders,
        TargetPlatform.android: const EditorialPageTransition(),
        TargetPlatform.macOS: const EditorialPageTransition(),
        TargetPlatform.windows: const EditorialPageTransition(),
        TargetPlatform.linux: const EditorialPageTransition(),
      }),
    );
  }
}

class EditorialPageTransition extends PageTransitionsBuilder {
  const EditorialPageTransition();
  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: curve
              .drive(Tween(begin: const Offset(0, .025), end: Offset.zero)),
          child: child,
        ));
  }
}
