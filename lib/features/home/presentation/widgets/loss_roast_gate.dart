import 'package:aura_quest/core/widgets/app_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/text/roasts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../challenges/application/challenge_providers.dart';
import '../../../challenges/domain/settlement.dart';

/// Invisible gate on Home: when the settlement engine has FAILED a
/// quest the player hasn't been confronted with yet, it blocks the
/// screen with a roast that can only be dismissed by admitting defeat.
///
/// "Confronted" is tracked locally (shared_preferences timestamp), so
/// every device roasts its owner exactly once per lost quest.
class LossRoastGate extends ConsumerStatefulWidget {
  const LossRoastGate({super.key});

  static const _prefsKey = 'loss_roast_acked_at';

  @override
  ConsumerState<LossRoastGate> createState() => _LossRoastGateState();
}

class _LossRoastGateState extends ConsumerState<LossRoastGate> {
  bool _showing = false;

  Future<void> _maybeRoast(List<SettlementEvent> events) async {
    if (_showing || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final ackedAtRaw = prefs.getString(LossRoastGate._prefsKey);
    final ackedAt = ackedAtRaw == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.parse(ackedAtRaw);

    final freshLosses = events
        .where((e) => e.kind == 'failed' && e.createdAt.isAfter(ackedAt))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (freshLosses.isEmpty || !mounted) return;

    _showing = true;
    final loss = freshLosses.first;

    if (!mounted) {
      _showing = false;
      return;
    }

    final roast = Roasts.random();

    await showDialog<void>(
      context: context,
      // No slipping away: defeat must be acknowledged.
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AppDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.danger),
          ),
          title: Text(
            'QUEST FAILED',
            textAlign: TextAlign.center,
            style: Theme.of(dialogContext)
                .textTheme
                .headlineSmall
                ?.copyWith(color: AppColors.danger),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💀', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 14),
              Text(
                '"$roast"',
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                '${loss.questTitle} is over. '
                '${loss.amount ?? 0} aura salvaged'
                '${freshLosses.length > 1 ? ' — and ${freshLosses.length - 1} more defeat${freshLosses.length > 2 ? 's' : ''} waiting' : ''}.',
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('YES, I AM A LOSER'),
              ),
            ),
          ],
        ),
      ),
    );

    // Confession accepted for this loss — the next fresh one (if any)
    // gets its own dialog on the following pass.
    await prefs.setString(
        LossRoastGate._prefsKey, loss.createdAt.toIso8601String());
    _showing = false;

    if (mounted && freshLosses.length > 1) {
      _maybeRoast(events);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settlementEventsProvider, (_, next) {
      final events = next.valueOrNull;
      if (events != null) _maybeRoast(events);
    });

    // Also cover the case where events were already loaded before this
    // widget appeared.
    final current = ref.watch(settlementEventsProvider).valueOrNull;
    if (current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRoast(current));
    }

    return const SizedBox.shrink();
  }
}
