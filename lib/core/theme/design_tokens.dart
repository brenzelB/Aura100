import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract class AppSpace {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
  static const double touch = 48;
  static const page = EdgeInsets.fromLTRB(20, 24, 20, 32);
}

abstract class AppShapes {
  static double get radius =>
      AppColors.activeType == AppThemeType.neoBrutalist ? 6 : 16;
  static double get stroke =>
      AppColors.activeType == AppThemeType.neoBrutalist ? 2 : 1;
  static RoundedRectangleBorder get panel => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: AppColors.outline, width: stroke),
      );
  static RoundedRectangleBorder get dialog => panel;
  static RoundedRectangleBorder get sheet => RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius + 6)),
        side: BorderSide(color: AppColors.outline, width: stroke),
      );
}

/// Select foreground from the actual fill, including status colours.
Color readableOn(Color background) {
  final l = background.computeLuminance();
  return (l + .05) / .05 >= 1.05 / (l + .05) ? Colors.black : Colors.white;
}
