import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/motion.dart';

/// A theme-aware icon widget.
/// Renders standard icons in Neo-Brutalist/Editorial/Auralis.
class ThemeIcon extends StatelessWidget {
  const ThemeIcon({
    super.key,
    required this.icon,
    required this.matrixChar, // Kept parameter for API compatibility but not used
    required this.color,
    this.size = 14.0,
  });

  final IconData icon;
  final String matrixChar;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color,
    );
  }
}

/// A theme-aware progress indicator.
/// Renders a circular ring in Neo-Brutalist/Auralis, but builds a thick-stroke
/// circular progress indicator in Editorial Growth.
class ThemeProgressRing extends StatelessWidget {
  const ThemeProgressRing({
    super.key,
    required this.completion,
    required this.doneCount,
    required this.totalCount,
    required this.accent,
  });

  final double? completion;
  final int doneCount;
  final int totalCount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (AppColors.activeType == AppThemeType.editorial) {
      // ── Thick Stroke Circular Progress Indicator for Editorial Growth ──
      final allDone = completion == 1.0;
      return SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: completion ?? 0),
              duration: AppDurations.slow,
              curve: AppCurves.emphasizedOut,
              builder: (context, value, _) => SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: completion == null ? 0 : value,
                  strokeWidth: 6, // Thick stroke
                  color: accent, // Terracotta
                  backgroundColor: AppColors.surfaceLight, // Very light neutral/cream
                ),
              ),
            ),
            if (allDone)
              Icon(Icons.check, color: AppColors.successText)
            else
              Text(
                '$doneCount/$totalCount',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
          ],
        ),
      );
    }

    if (AppColors.activeType == AppThemeType.auralis) {
      // ── High-Precision Circular Progress Indicator for Auralis ──
      final allDone = completion == 1.0;
      return SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: completion ?? 0),
              duration: AppDurations.slow,
              curve: AppCurves.emphasizedOut,
              builder: (context, value, _) => SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: completion == null ? 0 : value,
                  strokeWidth: 4, // Thinner, precise stroke
                  color: accent,
                  backgroundColor: AppColors.outline, // outline scaffolding color
                ),
              ),
            ),
            if (allDone)
              Icon(Icons.check, color: AppColors.successText)
            else
              Text(
                '$doneCount/$totalCount',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
          ],
        ),
      );
    }

    // ── Kinetic Neo-Brutalist Progress Indicator ──
    final allDone = completion == 1.0;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: completion ?? 0),
            duration: AppDurations.slow,
            curve: AppCurves.emphasizedOut,
            builder: (context, value, _) => SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: completion == null ? 0 : value,
                strokeWidth: 6,
                color: accent,
                backgroundColor: AppColors.surfaceLight,
              ),
            ),
          ),
          if (allDone)
            Icon(Icons.check, color: AppColors.successText)
          else
            Text(
              '$doneCount/$totalCount',
              style: textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}
