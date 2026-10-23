import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppThemeBackground extends StatelessWidget {
  const AppThemeBackground({
    super.key,
    required this.themeType,
    required this.child,
  });

  final AppThemeType themeType;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    switch (themeType) {
      case AppThemeType.neoBrutalist:
        return Container(
          color: AppColors.background,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    // Ink gridlines in light, paper gridlines in dark.
                    painter: _GridPainter(
                      color: AppColors.textPrimary.withValues(alpha: 0.04),
                      spacing: 40,
                      strokeWidth: 1.0,
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        );
      case AppThemeType.editorial:
        return ColoredBox(
          color: AppColors.background,
          child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: child)),
        );
      case AppThemeType.auralis:
        return Container(
          color: AppColors.background,
          child: Stack(
            children: [
              // Subtle blueprint scaffolding grid overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GridPainter(
                      color: AppColors.isDark
                          ? AppColors.textSecondary.withValues(alpha: 0.10)
                          : const Color(0xFFC4C7C7).withValues(alpha: 0.15),
                      spacing: 48,
                      strokeWidth: 0.5,
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        );
    }
  }
}

/// Shared scaffolding grid — colour and density come from the active
/// theme, so it survives a light/dark switch.
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.color,
    required this.spacing,
    required this.strokeWidth,
  });

  final Color color;
  final double spacing;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.color != color ||
      old.spacing != spacing ||
      old.strokeWidth != strokeWidth;
}
