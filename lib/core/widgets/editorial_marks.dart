import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Bounded geometric marks; accessibility reports the actual quest count.
class EditorialMarks extends StatelessWidget {
  const EditorialMarks(
      {super.key,
      required this.completed,
      required this.total,
      this.width = 138,
      this.height = 62});
  final int completed, total;
  final double width, height;
  @override
  Widget build(BuildContext context) => Semantics(
        label: '$completed of $total quests confirmed today',
        image: true,
        child: RepaintBoundary(
            child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
              painter: _MarksPainter(
            ratio: total <= 0 ? 0 : (completed / total).clamp(0, 1),
            count: total.clamp(1, 3),
            fill: AppColors.neonPink,
            ink: AppColors.onAccent,
            line: AppColors.isDark
                ? const Color(0xFF9A7FA0)
                : const Color(0xFF9C7B97),
          )),
        )),
      );
}

class _MarksPainter extends CustomPainter {
  const _MarksPainter(
      {required this.ratio,
      required this.count,
      required this.fill,
      required this.ink,
      required this.line});
  final double ratio;
  final int count;
  final Color fill, ink, line;
  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.height * .72, size.width / (count + .2));
    final gap = side * .12;
    final left = (size.width - count * side - (count - 1) * gap) / 2;
    final path = Path()
      ..moveTo(0, side)
      ..lineTo(0, side / 2)
      ..quadraticBezierTo(0, 0, side / 2, 0)
      ..lineTo(side, 0)
      ..lineTo(side, side / 2)
      ..quadraticBezierTo(side, side, side / 2, side)
      ..close();
    for (var i = 0; i < count; i++) {
      final fraction = (ratio * count - i).clamp(0.0, 1.0);
      final filled = fraction >= 1;
      canvas.save();
      canvas.translate(
          left + i * (side + gap) + side / 2, size.height / 2 + (1 - i) * 2);
      canvas.rotate((i - (count - 1) / 2) * .17);
      canvas.translate(-side / 2, -side / 2);
      if (fraction > 0 && !filled) {
        canvas.save();
        canvas.clipPath(path);
        canvas.clipRect(Rect.fromLTWH(0, 0, side * fraction, side));
        canvas.drawPath(path, Paint()..color = fill);
        canvas.restore();
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = filled ? fill : line
            ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 1.5);
      if (filled) {
        canvas.drawPath(
            Path()
              ..moveTo(side * .28, side * .52)
              ..lineTo(side * .44, side * .68)
              ..lineTo(side * .74, side * .3),
            Paint()
              ..color = ink
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..strokeWidth = 2.2);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_MarksPainter old) =>
      old.ratio != ratio ||
      old.count != count ||
      old.fill != fill ||
      old.ink != ink ||
      old.line != line;
}

/// A compact signature driven by the quest's actual proportional progress.
/// The neighboring numeric readout supplies the accessible value.
class EditorialGoalMarks extends StatelessWidget {
  const EditorialGoalMarks({super.key, required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(
            child: SizedBox(
          width: 88,
          height: 46,
          child: CustomPaint(
              painter: _MarksPainter(
            ratio: progress.clamp(0.0, 1.0),
            count: 3,
            fill: AppColors.neonPink,
            ink: AppColors.onAccent,
            line: AppColors.isDark
                ? const Color(0xFF9A7FA0)
                : const Color(0xFF9C7B97),
          )),
        )),
      );
}

/// Proportional cuts, initially visible; only subsequent data changes animate.
class EditorialProgressTrack extends StatelessWidget {
  const EditorialProgressTrack(
      {super.key, required this.value, this.compact = false});
  final double value;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0.0, 1.0);
    return Semantics(
      value: '${(progress * 100).round()} percent',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: progress, end: progress),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        curve: Curves.easeOutExpo,
        builder: (context, current, _) => RepaintBoundary(
            child: SizedBox(
          width: double.infinity,
          height: compact ? 6 : 8,
          child: CustomPaint(
              painter: _TrackPainter(
                  current,
                  compact ? AppColors.textPrimary : AppColors.neonPink,
                  AppColors.surfaceLight)),
        )),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  const _TrackPainter(this.value, this.fill, this.track);
  final double value;
  final Color fill, track;
  @override
  void paint(Canvas canvas, Size size) {
    final gap = math.min(4.0, size.width / 40);
    final width = (size.width - 9 * gap) / 10;
    for (var i = 0; i < 10; i++) {
      final rect = Rect.fromLTWH(i * (width + gap), 0, width, size.height);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(1)),
          Paint()..color = track);
      final fraction = (value * 10 - i).clamp(0.0, 1.0);
      if (fraction > 0) {
        canvas.drawRect(
            Rect.fromLTWH(rect.left, 0, width * fraction, size.height),
            Paint()..color = fill);
      }
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.value != value || old.fill != fill || old.track != track;
}
