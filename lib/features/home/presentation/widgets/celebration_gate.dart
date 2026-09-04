import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/text/hype.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../challenges/application/challenge_providers.dart';
import '../../../challenges/domain/settlement.dart';

/// Invisible gate on Home, the winning counterpart to LossRoastGate:
/// when the engine records a fresh milestone (streak 7/30/100) or a
/// completed quest, it interrupts with a full celebration screen.
///
/// Acknowledged locally by timestamp. On first ever run it silently
/// adopts "now" so old completions don't retro-flood the player.
class CelebrationGate extends ConsumerStatefulWidget {
  const CelebrationGate({super.key});

  static const _prefsKey = 'celebration_acked_at';
  static const _kinds = {'milestone', 'completed'};

  @override
  ConsumerState<CelebrationGate> createState() => _CelebrationGateState();
}

class _CelebrationGateState extends ConsumerState<CelebrationGate> {
  bool _showing = false;

  Future<void> _maybeCelebrate(List<SettlementEvent> events) async {
    if (_showing || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final ackedRaw = prefs.getString(CelebrationGate._prefsKey);
    if (ackedRaw == null) {
      // First encounter: adopt now, celebrate only what comes next.
      await prefs.setString(
          CelebrationGate._prefsKey, DateTime.now().toUtc().toIso8601String());
      return;
    }
    final acked = DateTime.parse(ackedRaw);

    final fresh = events
        .where((e) =>
            CelebrationGate._kinds.contains(e.kind) &&
            e.createdAt.isAfter(acked))
        .toList()
      // Oldest first so we celebrate in the order they happened.
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (fresh.isEmpty || !mounted) return;

    _showing = true;
    final event = fresh.first;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => _CelebrationDialog(event: event),
    );

    await prefs.setString(
        CelebrationGate._prefsKey, event.createdAt.toIso8601String());
    _showing = false;

    // Chain to the next unseen celebration, if any.
    if (mounted && fresh.length > 1) _maybeCelebrate(events);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settlementEventsProvider, (_, next) {
      final events = next.valueOrNull;
      if (events != null) _maybeCelebrate(events);
    });

    final current = ref.watch(settlementEventsProvider).valueOrNull;
    if (current != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybeCelebrate(current));
    }

    return const SizedBox.shrink();
  }
}

/// The celebration itself: a confetti burst behind a big glyph, a
/// hype line, and one loud dismiss button.
class _CelebrationDialog extends StatefulWidget {
  const _CelebrationDialog({required this.event});

  final SettlementEvent event;

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  late final String _hype;

  bool get _isStreak => widget.event.kind == 'milestone';

  @override
  void initState() {
    super.initState();
    _hype = _isStreak ? Hype.forStreak() : Hype.forCompletion();

    final rand = Random();
    final palette = [
      AppColors.neonGreen,
      AppColors.neonYellow,
      AppColors.neonPink,
      AppColors.neonCyan,
      AppColors.neonPurple,
    ];
    _particles = List.generate(38, (i) {
      final angle = (i / 38) * 2 * pi + rand.nextDouble() * 0.4;
      return _Particle(
        angle: angle,
        distance: 90 + rand.nextDouble() * 150,
        size: 5 + rand.nextDouble() * 7,
        color: palette[rand.nextInt(palette.length)],
        spin: rand.nextDouble() * 6 - 3,
      );
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = _isStreak ? AppColors.neonYellow : AppColors.neonGreen;
    final glyph = _isStreak ? '🔥' : '🏆';
    final headline = _isStreak
        ? '${widget.event.amount}-DAY STREAK'
        : 'QUEST COMPLETE';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent, width: 2),
          boxShadow: AppColors.neonGlow(accent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Confetti burst behind the glyph.
            SizedBox(
              height: 180,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(double.infinity, 180),
                        painter: _ConfettiPainter(
                          particles: _particles,
                          progress: _controller.value,
                          accent: accent,
                        ),
                      ),
                      // Glyph pops in with an elastic bounce — starting
                      // from a visible size, never from nothing.
                      Transform.scale(
                        scale: 0.4 +
                            0.6 *
                                Curves.elasticOut.transform(
                                    (_controller.value * 1.4).clamp(0.0, 1.0)),
                        child: Text(glyph,
                            style: const TextStyle(fontSize: 76)),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                color: accent,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.event.questTitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            if (!_isStreak && widget.event.amount != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, color: accent, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.event.amount} aura banked',
                    style: textTheme.bodyLarge?.copyWith(
                        color: accent, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              '"$_hype"',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: AppColors.background,
                  minimumSize: const Size(0, 48),
                ),
                child: Text(_isStreak ? "LET'S GO" : 'HELL YEAH'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One confetti fleck: fixed heading, spun and flung outward over the
/// animation, fading as it flies.
class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.spin,
  });

  final double angle;
  final double distance;
  final double size;
  final Color color;
  final double spin;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.accent,
  });

  final List<_Particle> particles;
  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Two expanding shockwave rings.
    for (var r = 0; r < 2; r++) {
      final t = (progress - r * 0.12).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - t)
        ..color = accent.withValues(alpha: (1 - t) * 0.5);
      canvas.drawCircle(center, 20 + t * 130, ringPaint);
    }

    // Flung confetti flecks.
    final eased = Curves.easeOutCubic.transform(progress);
    for (final p in particles) {
      final d = p.distance * eased;
      final pos = center + Offset(cos(p.angle) * d, sin(p.angle) * d);
      final fade = (1 - progress).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: fade);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * progress * pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.progress != progress;
}
