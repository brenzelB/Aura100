import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Which empty-state motif to draw. Each pairs the shared "aura" rings
/// with one simple line glyph.
enum SpotMotif { quests, friends, inbox, trophies, robbed }

/// A theme-tinted vector spot illustration for empty states — concentric
/// "aura" rings (the app's core motif) behind a minimal line glyph.
/// Auto-adapts to every theme + light/dark via [AppColors]; no raster
/// assets, crisp at any size.
class SpotIllustration extends StatelessWidget {
  const SpotIllustration({
    super.key,
    required this.motif,
    this.size = 108,
    this.accent,
  });

  final SpotMotif motif;
  final double size;

  /// Overrides the ring/glyph accent (defaults to the Aura indigo).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SpotPainter(
          motif: motif,
          accent: accent ?? AppColors.neonPurple,
          ink: AppColors.textPrimary,
          faint: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SpotPainter extends CustomPainter {
  _SpotPainter({
    required this.motif,
    required this.accent,
    required this.ink,
    required this.faint,
  });

  final SpotMotif motif;
  final Color accent;
  final Color ink;
  final Color faint;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // ── Aura rings: three concentric rings, fading outward. ──
    for (var i = 0; i < 3; i++) {
      final t = i / 2; // 0, .5, 1
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = accent.withValues(alpha: 0.28 * (1 - t) + 0.06);
      canvas.drawCircle(c, r * (0.52 + 0.24 * i), ringPaint);
    }
    // A soft accent disc behind the glyph.
    canvas.drawCircle(
      c,
      r * 0.52,
      Paint()..color = accent.withValues(alpha: 0.10),
    );

    final glyph = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    final glyphFill = Paint()..color = accent;

    final g = size.shortestSide * 0.20; // glyph half-extent
    switch (motif) {
      case SpotMotif.quests:
        _flag(canvas, c, g, glyph, glyphFill);
        break;
      case SpotMotif.friends:
        _friends(canvas, c, g, glyph, glyphFill);
        break;
      case SpotMotif.inbox:
        _bell(canvas, c, g, glyph, glyphFill);
        break;
      case SpotMotif.trophies:
        _trophy(canvas, c, g, glyph, glyphFill);
        break;
      case SpotMotif.robbed:
        _spark(canvas, c, g, glyph, glyphFill);
        break;
    }
  }

  void _flag(Canvas canvas, Offset c, double g, Paint stroke, Paint fill) {
    final pole = Offset(c.dx - g * 0.7, c.dy - g);
    canvas.drawLine(pole, Offset(pole.dx, c.dy + g), stroke);
    final path = Path()
      ..moveTo(pole.dx, pole.dy)
      ..lineTo(pole.dx + g * 1.6, pole.dy + g * 0.35)
      ..lineTo(pole.dx, pole.dy + g * 0.7)
      ..close();
    canvas.drawPath(path, fill);
  }

  void _friends(Canvas canvas, Offset c, double g, Paint stroke, Paint fill) {
    // Two overlapping heads + shoulders.
    for (final dx in [-g * 0.55, g * 0.55]) {
      final head = Offset(c.dx + dx, c.dy - g * 0.45);
      canvas.drawCircle(head, g * 0.42, dx < 0 ? fill : stroke);
      final body = Rect.fromLTWH(
          head.dx - g * 0.7, c.dy + g * 0.15, g * 1.4, g * 0.9);
      canvas.drawArc(body, math.pi, math.pi, false, stroke);
    }
  }

  void _bell(Canvas canvas, Offset c, double g, Paint stroke, Paint fill) {
    final path = Path()
      ..moveTo(c.dx - g, c.dy + g * 0.5)
      ..quadraticBezierTo(c.dx - g, c.dy - g, c.dx, c.dy - g)
      ..quadraticBezierTo(c.dx + g, c.dy - g, c.dx + g, c.dy + g * 0.5)
      ..close();
    canvas.drawPath(path, stroke);
    canvas.drawCircle(Offset(c.dx, c.dy + g * 0.85), g * 0.22, fill);
  }

  void _trophy(Canvas canvas, Offset c, double g, Paint stroke, Paint fill) {
    final cup = Path()
      ..moveTo(c.dx - g * 0.8, c.dy - g)
      ..lineTo(c.dx + g * 0.8, c.dy - g)
      ..lineTo(c.dx + g * 0.55, c.dy + g * 0.1)
      ..lineTo(c.dx - g * 0.55, c.dy + g * 0.1)
      ..close();
    canvas.drawPath(cup, fill);
    canvas.drawLine(Offset(c.dx, c.dy + g * 0.1),
        Offset(c.dx, c.dy + g * 0.7), stroke);
    canvas.drawLine(Offset(c.dx - g * 0.5, c.dy + g),
        Offset(c.dx + g * 0.5, c.dy + g), stroke);
  }

  void _spark(Canvas canvas, Offset c, double g, Paint stroke, Paint fill) {
    // A four-point spark / aura burst.
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final tip = Offset(c.dx + math.cos(a) * g, c.dy + math.sin(a) * g);
      final mid = Offset(c.dx + math.cos(a + math.pi / 4) * g * 0.32,
          c.dy + math.sin(a + math.pi / 4) * g * 0.32);
      if (i == 0) {
        path.moveTo(tip.dx, tip.dy);
      } else {
        path.lineTo(tip.dx, tip.dy);
      }
      path.lineTo(mid.dx, mid.dy);
    }
    path.close();
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(_SpotPainter old) =>
      old.motif != motif ||
      old.accent != accent ||
      old.ink != ink ||
      old.faint != faint;
}
