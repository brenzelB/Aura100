import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/text/quantity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../home/presentation/widgets/targeted_roast_gate.dart';
import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import '../../domain/progress_presets.dart';
import 'progress_feedback.dart';

/// Direct, server-confirmed writes; all shortcuts share the quest's controller.
class QuickProgressActions extends ConsumerStatefulWidget {
  const QuickProgressActions({super.key, required this.challenge});
  final Challenge challenge;

  @override
  ConsumerState<QuickProgressActions> createState() =>
      _QuickProgressActionsState();
}

class _QuickProgressActionsState extends ConsumerState<QuickProgressActions> {
  bool _submitting = false;

  Future<void> _add(double amount) async {
    final challenge = widget.challenge;
    if (_submitting ||
        ref.read(progressControllerProvider(challenge.id)).isLoading) {
      return;
    }
    final owner = ref.read(currentUserProvider)?.id;
    if (owner == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      final roast = (ref.read(targetedRoastsProvider).valueOrNull ?? [])
          .where((r) => r.challengeId == challenge.id)
          .firstOrNull;
      if (roast != null) await showTargetedRoastLockDialog(context, ref, roast);
      if (!mounted || ref.read(currentUserProvider)?.id != owner) return;
      final result = await ref
          .read(progressControllerProvider(challenge.id).notifier)
          .add(amount);
      if (!mounted || ref.read(currentUserProvider)?.id != owner) return;
      if (result == null) {
        final error = ref.read(progressControllerProvider(challenge.id)).error;
        showActionFeedback(messenger,
            error: true,
            message: error is PostgrestException
                ? error.message
                : 'Could not log progress. Check your connection and try again.');
      } else {
        showProgressFeedback(messenger,
            result: result, added: amount, unit: challenge.unit ?? '');
        // Keep shortcuts locked until the card has the new remainder.
        // A refresh failure must not turn a confirmed write into an error.
        try {
          await ref.read(myChallengesProvider.future);
        } catch (_) {
          // The quest provider retains its last usable data while offline.
        }
      }
    } catch (_) {
      if (mounted && ref.read(currentUserProvider)?.id == owner) {
        showActionFeedback(messenger,
            error: true,
            message: 'Could not complete this action. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final blackout = ref.watch(myBlackoutProvider(challenge.id)).valueOrNull;
    if (blackout != null && blackout.isRunning) return const SizedBox.shrink();
    final remaining = challenge.progressRemaining;
    if (remaining <= 0) return const SizedBox.shrink();
    final busy = _submitting ||
        ref.watch(progressControllerProvider(challenge.id)).isLoading;
    final presets = progressPresets(challenge.targetValue ?? 0);
    // Two shortcuts plus the exact remainder; don't duplicate the final amount.
    final amounts = [
      if (presets.isNotEmpty) presets.first,
      if (presets.length > 1) presets.last
    ].where((amount) => amount < remaining).toSet();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final amount in amounts)
            _button('+${formatQuantity(amount)}', amount, busy),
          _button('Finish (${formatQuantity(remaining)})', remaining, busy),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
    );
  }

  Widget _button(String label, double amount, bool busy) => Tooltip(
        message:
            'Log ${formatQuantity(amount)} ${widget.challenge.unit ?? ''} now',
        child: OutlinedButton(
          onPressed: busy ? null : () => _add(amount),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentText,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            visualDensity: VisualDensity.standard,
          ),
          child: Text(label),
        ),
      );
}
