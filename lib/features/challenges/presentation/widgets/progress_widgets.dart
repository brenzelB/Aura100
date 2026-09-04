import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/text/quantity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/motion.dart';
import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import '../../domain/progress_entry.dart';

/// The progress read-out: "72 / 100 Reps", a percentage and
/// an animated bar. Used on the card, on Home and in the detail view.
class QuestProgressBar extends StatelessWidget {
  const QuestProgressBar({
    super.key,
    required this.challenge,
    this.compact = false,
  });

  final Challenge challenge;

  /// Tighter type + thinner bar for list cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final target = challenge.targetValue ?? 0;
    final done = challenge.progressInPeriod >= target && target > 0;
    final accent = done ? AppColors.neonGreen : AppColors.neonPurple;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (done) ...[
              Icon(Icons.check_circle, size: compact ? 14 : 18, color: accent),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                formatProgress(
                  challenge.progressInPeriod,
                  target,
                  challenge.unit ?? '',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (compact ? textTheme.bodySmall : textTheme.bodyLarge)
                    ?.copyWith(
                  color: done ? accent : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Beyond the goal: show the bonus reps, not a stuck 100%.
            if (challenge.overshoot > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.neonGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+${formatQuantity(challenge.overshoot)} over',
                  style: (compact ? textTheme.bodySmall : textTheme.bodyMedium)
                      ?.copyWith(
                          color: AppColors.successText,
                          fontWeight: FontWeight.w700),
                ),
              )
            else
              Text(
                '${challenge.progressPercent} %',
                style: (compact ? textTheme.bodySmall : textTheme.bodyMedium)
                    ?.copyWith(color: accent, fontWeight: FontWeight.w700),
              ),
          ],
        ),
        SizedBox(height: compact ? 5 : 8),
        // Animates from wherever it was to the new value after a log.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: challenge.progressRatio),
          duration: AppDurations.slow,
          curve: AppCurves.emphasizedOut,
          builder: (context, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: compact ? 6 : 10,
              color: accent,
              backgroundColor: AppColors.surfaceLight,
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens the "add progress" sheet and reports the outcome via
/// SnackBar. Safe to call from any screen that has a Scaffold.
Future<void> showAddProgressSheet(
  BuildContext context,
  WidgetRef ref,
  Challenge challenge,
) async {
  final messenger = ScaffoldMessenger.of(context);

  final result = await showModalBottomSheet<_AddOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AddProgressSheet(challenge: challenge),
  );
  if (result == null) return;

  final unit = challenge.unit ?? '';
  if (result.overshoot) {
    // Bonus reps beyond an already-met goal.
    final beyond = result.total - result.target;
    messenger.showSnackBar(SnackBar(
      content: Text('💪 +${formatQuantity(result.added)} bonus — '
          '${formatQuantity(result.total)} $unit '
          '(+${formatQuantity(beyond)} past goal)'),
      backgroundColor: AppColors.neonGreen,
    ));
  } else if (result.completed) {
    messenger.showSnackBar(SnackBar(
      content: Text('🎯 Goal reached — '
          '${formatQuantity(result.total)} $unit'
          '${result.gained == null ? '' : '! ⚡ +${result.gained}'}'),
      backgroundColor: AppColors.neonGreen,
    ));
  } else {
    messenger.showSnackBar(SnackBar(
      content: Text('+${formatQuantity(result.added)} logged — '
          '${formatProgress(result.total, result.target, unit)}'),
      backgroundColor: AppColors.neonPurple,
    ));
  }
}

class _AddOutcome {
  const _AddOutcome({
    required this.added,
    required this.total,
    required this.target,
    required this.completed,
    required this.overshoot,
    required this.gained,
  });

  final double added;
  final double total;
  final double target;
  final bool completed;
  final bool overshoot;
  final int? gained;
}

class _AddProgressSheet extends ConsumerStatefulWidget {
  const _AddProgressSheet({required this.challenge});

  final Challenge challenge;

  @override
  ConsumerState<_AddProgressSheet> createState() => _AddProgressSheetState();
}

class _AddProgressSheetState extends ConsumerState<_AddProgressSheet> {
  final _controller = TextEditingController();
  String? _error;

  Challenge get challenge => widget.challenge;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Quick amounts scaled to the target, so they fit "100 push-ups"
  /// and "2.5 litres" alike. Plus whatever is still missing.
  List<double> get _presets {
    final target = challenge.targetValue ?? 0;
    if (target <= 0) return const [];
    final raw = <double>[target * 0.1, target * 0.25, target * 0.5];
    final seen = <String>{};
    final presets = <double>[];
    for (final value in raw) {
      final rounded = _tidy(value);
      if (rounded <= 0) continue;
      if (seen.add(formatQuantity(rounded))) presets.add(rounded);
    }
    return presets;
  }

  /// Rounds a suggestion to something a human would type.
  double _tidy(double value) {
    if (value >= 100) return (value / 10).round() * 10;
    if (value >= 10) return value.roundToDouble();
    if (value >= 1) return (value * 2).round() / 2;
    return (value * 100).round() / 100;
  }

  Future<void> _submit() async {
    final amount = parseQuantity(_controller.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0');
      return;
    }
    setState(() => _error = null);

    final result =
        await ref.read(progressControllerProvider(challenge.id).notifier)
            .add(amount);

    if (!mounted) return;
    if (result == null) {
      final error = ref.read(progressControllerProvider(challenge.id)).error;
      setState(() => _error = error is PostgrestException
          ? error.message
          : 'Could not log that — try again.');
      return;
    }

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(_AddOutcome(
      added: amount,
      total: result.total,
      target: result.target,
      completed: result.completed,
      overshoot: result.overshoot,
      gained: result.gained,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final busy = ref.watch(progressControllerProvider(challenge.id)).isLoading;
    final unit = challenge.unit ?? '';
    final remaining = challenge.progressRemaining;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ADD PROGRESS',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium
                  ?.copyWith(color: AppColors.neonPurple),
            ),
            const SizedBox(height: 6),
            Text(
              challenge.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            QuestProgressBar(challenge: challenge),
            // Once the goal's met, make it unmistakable these are bonus.
            if (challenge.goalReached) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.neonGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.neonGreen.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: AppColors.successText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Goal's done — extra reps are bonus. They're "
                        'logged towards your totals, not the goal.',
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.successText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ── The amount ──────────────────────────────────
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: textTheme.displaySmall
                  ?.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: unit,
                errorText: _error,
              ),
              onSubmitted: (_) => busy ? null : _submit(),
            ),
            const SizedBox(height: 14),

            // ── Quick amounts ───────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final preset in _presets)
                  _QuickChip(
                    label: '+${formatQuantity(preset)}',
                    onTap: busy
                        ? null
                        : () => setState(
                            () => _controller.text = formatQuantity(preset)),
                  ),
                if (remaining > 0)
                  _QuickChip(
                    label: 'Rest (${formatQuantity(remaining)})',
                    highlight: true,
                    onTap: busy
                        ? null
                        : () => setState(
                            () => _controller.text = formatQuantity(remaining)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: challenge.goalReached
                    ? AppColors.neonGreen
                    : AppColors.neonPurple,
                foregroundColor: AppColors.background,
              ),
              icon: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.background),
                    )
                  : const Icon(Icons.add),
              label: Text(challenge.goalReached ? 'LOG BONUS' : 'LOG IT'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Opens the "correct entry" sheet for one logged entry (edit the amount
/// or delete it) and reports the outcome via SnackBar. Only meaningful for
/// entries in the current period — the server locks the rest.
Future<void> showCorrectEntrySheet(
  BuildContext context,
  WidgetRef ref,
  Challenge challenge,
  ProgressEntry entry,
) async {
  final messenger = ScaffoldMessenger.of(context);

  final outcome = await showModalBottomSheet<_CorrectOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CorrectEntrySheet(challenge: challenge, entry: entry),
  );
  if (outcome == null) return;

  final unit = challenge.unit ?? '';
  messenger.showSnackBar(SnackBar(
    content: Text(outcome.deleted
        ? '🗑️ Entry removed'
        : '✏️ Updated to ${formatQuantity(outcome.amount)} $unit'),
    backgroundColor: AppColors.neonPurple,
  ));
}

class _CorrectOutcome {
  const _CorrectOutcome({required this.deleted, required this.amount});
  final bool deleted;
  final double amount;
}

class _CorrectEntrySheet extends ConsumerStatefulWidget {
  const _CorrectEntrySheet({required this.challenge, required this.entry});

  final Challenge challenge;
  final ProgressEntry entry;

  @override
  ConsumerState<_CorrectEntrySheet> createState() => _CorrectEntrySheetState();
}

class _CorrectEntrySheetState extends ConsumerState<_CorrectEntrySheet> {
  late final TextEditingController _controller =
      TextEditingController(text: formatQuantity(widget.entry.amount));
  String? _error;
  bool _confirmingDelete = false;

  Challenge get challenge => widget.challenge;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseQuantity(_controller.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than 0');
      return;
    }
    if (amount == widget.entry.amount) {
      Navigator.of(context).pop(); // nothing changed
      return;
    }
    setState(() => _error = null);

    final result = await ref
        .read(progressControllerProvider(challenge.id).notifier)
        .edit(widget.entry.id, amount);

    if (!mounted) return;
    if (result == null) {
      _showError();
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(_CorrectOutcome(deleted: false, amount: amount));
  }

  Future<void> _delete() async {
    if (!_confirmingDelete) {
      setState(() => _confirmingDelete = true);
      return;
    }
    final result = await ref
        .read(progressControllerProvider(challenge.id).notifier)
        .remove(widget.entry.id);

    if (!mounted) return;
    if (result == null) {
      setState(() => _confirmingDelete = false);
      _showError();
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context)
        .pop(_CorrectOutcome(deleted: true, amount: widget.entry.amount));
  }

  void _showError() {
    final error = ref.read(progressControllerProvider(challenge.id)).error;
    setState(() => _error = error is PostgrestException
        ? error.message
        : 'Could not save that — try again.');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final busy = ref.watch(progressControllerProvider(challenge.id)).isLoading;
    final unit = challenge.unit ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'CORRECT ENTRY',
              textAlign: TextAlign.center,
              style:
                  textTheme.headlineMedium?.copyWith(color: AppColors.neonPurple),
            ),
            const SizedBox(height: 6),
            Text(
              'Fix a value you typed by mistake',
              textAlign: TextAlign.center,
              style:
                  textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: textTheme.displaySmall
                  ?.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: unit,
                errorText: _error,
              ),
              onSubmitted: (_) => busy ? null : _save(),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: busy ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonPurple,
                foregroundColor: AppColors.background,
              ),
              icon: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.background),
                    )
                  : const Icon(Icons.check),
              label: const Text('SAVE'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : _delete,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger),
                minimumSize: const Size(0, 46),
              ),
              icon: Icon(
                  _confirmingDelete ? Icons.delete_forever : Icons.delete_outline,
                  size: 18),
              label: Text(
                  _confirmingDelete ? 'TAP AGAIN TO DELETE' : 'DELETE ENTRY'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.neonGreen : AppColors.neonPurple;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
