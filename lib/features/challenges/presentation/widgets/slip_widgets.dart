import 'package:aura_quest/core/widgets/app_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/motion.dart';
import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import '../../domain/slip_result.dart';

/// Traffic light for a negative quest: green while safe, amber on the
/// last slip, red once the period is lost.
Color slipColor(Challenge challenge) {
  if (challenge.slipLimitBroken) return AppColors.danger;
  if (challenge.slipNearLimit) return AppColors.neonYellow;
  return AppColors.neonGreen;
}

/// "2 / 3 slips" read-out with the traffic-light colour. Cold-turkey
/// quests (allowance 0) read as a clean/blown state instead of a count.
class SlipMeter extends StatelessWidget {
  const SlipMeter({
    super.key,
    required this.challenge,
    this.compact = false,
  });

  final Challenge challenge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = slipColor(challenge);
    final used = challenge.slipsInPeriod;
    final allowance = challenge.dailyAllowance;
    final broken = challenge.slipLimitBroken;

    final label = broken
        ? (allowance == 0
            ? 'Slipped — period lost'
            : '$used / $allowance — over')
        : (allowance == 0
            ? (used == 0 ? 'Clean so far' : '$used logged')
            : '$used / $allowance slips');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          broken
              ? Icons.cancel
              : (used == 0 ? Icons.shield_outlined : Icons.warning_amber),
          size: compact ? 14 : 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: (compact ? textTheme.bodySmall : textTheme.bodyMedium)
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
        if (allowance > 0 && !broken) ...[
          const SizedBox(width: 8),
          // Budget pips — a glanceable "how much rope is left".
          for (var i = 0; i < allowance.clamp(0, 8); i++) ...[
            Container(
              width: compact ? 6 : 8,
              height: compact ? 6 : 8,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < used ? color : color.withValues(alpha: 0.22),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// The "I slipped" button. Deliberately understated — pressing it is an
/// admission, not an achievement, so it never looks like a call to action.
class SlipButton extends StatelessWidget {
  const SlipButton({
    super.key,
    required this.challenge,
    required this.onPressed,
    this.busy = false,
    this.compact = false,
  });

  final Challenge challenge;
  final VoidCallback? onPressed;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final broken = challenge.slipLimitBroken;
    final color = broken ? AppColors.danger : slipColor(challenge);

    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        minimumSize: Size(0, compact ? 40 : 46),
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
        textStyle: TextStyle(
          fontSize: compact ? 12 : 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      icon: busy
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(broken ? Icons.add : Icons.remove_circle_outline,
              size: compact ? 15 : 18),
      label: Text(broken ? 'LOG ANYWAY' : 'I SLIPPED'),
    );
  }
}

/// Logs a slip and reports what it cost. A slip that stays inside the
/// budget gets a quiet snackbar; the one that breaks the limit gets an
/// unmissable reveal, because that is the moment the period is lost.
Future<void> logSlipAndReveal(
  BuildContext context,
  WidgetRef ref,
  Challenge challenge,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final result =
      await ref.read(slipControllerProvider(challenge.id).notifier).log();

  if (result == null) {
    final error = ref.read(slipControllerProvider(challenge.id)).error;
    messenger.showSnackBar(AppSnackBar(
      content: Text(error is PostgrestException
          ? error.message
          : 'Could not log that — try again.'),
      backgroundColor: AppColors.danger,
    ));
    return;
  }

  if (!context.mounted) return;

  if (result.justFailed) {
    HapticFeedback.heavyImpact();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SlipFailedDialog(result: result, challenge: challenge),
    );
    return;
  }

  HapticFeedback.selectionClick();
  if (result.over) {
    messenger.showSnackBar(AppSnackBar(
      content: Text('Logged — ${result.count} today. '
          'This period is already lost; tomorrow is a fresh start.'),
      backgroundColor: AppColors.textSecondary,
    ));
    return;
  }

  final left = result.left;
  messenger.showSnackBar(AppSnackBar(
    content: Text(result.allowance == 0
        ? 'Logged. That is one slip on the board.'
        : left == 0
            ? '${result.count}/${result.allowance} — that was your last one. '
                'One more loses the period.'
            : '${result.count}/${result.allowance} logged — '
                '$left left in the budget.'),
    backgroundColor: left == 0 ? AppColors.neonYellow : AppColors.textSecondary,
    action: SnackBarAction(
      label: 'UNDO',
      textColor: AppColors.background,
      onPressed: () async {
        final undone = await ref
            .read(slipControllerProvider(challenge.id).notifier)
            .undo();
        if (undone == null || !context.mounted) return;
        messenger.showSnackBar(AppSnackBar(
          content: Text('Taken back — ${undone.count} on the board.'),
          backgroundColor: AppColors.neonGreen,
        ));
      },
    ),
  ));
}

/// The moment the budget breaks: what it cost, and what still holds.
class _SlipFailedDialog extends StatefulWidget {
  const _SlipFailedDialog({required this.result, required this.challenge});

  final SlipResult result;
  final Challenge challenge;

  @override
  State<_SlipFailedDialog> createState() => _SlipFailedDialogState();
}

class _SlipFailedDialogState extends State<_SlipFailedDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppDurations.base,
  );
  bool _kicked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_kicked) return;
    _kicked = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final result = widget.result;
    final curved = CurvedAnimation(parent: _c, curve: AppCurves.emphasizedOut);

    return PopScope(
      canPop: false,
      child: AppDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.danger, width: 2.5),
        ),
        content: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.0).animate(curved),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 44, color: AppColors.danger),
                const SizedBox(height: 10),
                Text(
                  'LIMIT BROKEN',
                  style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.danger, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  result.allowance == 0
                      ? 'That was the one you were avoiding.'
                      : '${result.count} of ${result.allowance} allowed — '
                          'this period is lost.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textPrimary, height: 1.35),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: (result.shielded
                            ? AppColors.neonGreen
                            : AppColors.danger)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (result.shielded
                              ? AppColors.neonGreen
                              : AppColors.danger)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    result.shielded
                        ? '🛡 Streak Shield absorbed the strike'
                        : '−1 strike · ⚡${result.aura} left',
                    style: textTheme.bodyMedium?.copyWith(
                      color: result.shielded
                          ? AppColors.successText
                          : AppColors.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The streak you built still stands. Next period starts clean.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: AppColors.background,
                minimumSize: const Size(0, 48),
              ),
              child: const Text('OWN IT'),
            ),
          ),
        ],
      ),
    );
  }
}
