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
    const pill = StadiumBorder();
    final text = base.textTheme.copyWith(
      displayLarge: display(64),
      displayMedium: display(48),
      displaySmall: display(38),
      headlineLarge: display(32),
      headlineMedium: display(27),
      headlineSmall: display(22),
      titleLarge: display(24),
    );
    return base.copyWith(
      textTheme: text,
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: display(25),
        toolbarHeight: 68,
        shape: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: base.elevatedButtonTheme.style
              ?.copyWith(shape: const WidgetStatePropertyAll(pill))),
      filledButtonTheme: FilledButtonThemeData(
          style: base.filledButtonTheme.style
              ?.copyWith(shape: const WidgetStatePropertyAll(pill))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: base.outlinedButtonTheme.style
              ?.copyWith(shape: const WidgetStatePropertyAll(pill))),
      floatingActionButtonTheme:
          base.floatingActionButtonTheme.copyWith(shape: pill, elevation: 0),
      navigationBarTheme:
          base.navigationBarTheme.copyWith(indicatorShape: pill, height: 78),
      chipTheme: base.chipTheme.copyWith(shape: pill),
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
