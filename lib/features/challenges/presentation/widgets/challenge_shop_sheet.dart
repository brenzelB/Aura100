import 'package:aura_quest/core/widgets/app_states.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/editorial_cover.dart';
import '../../../../core/theme/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/text/dates.dart';
import '../../../../core/text/roasts_300.dart';
import '../../domain/quest_balance.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/motion.dart';
import '../../application/challenge_providers.dart';
import '../../domain/benefit.dart';
import '../../domain/blackout.dart';
import '../../domain/challenge.dart';
import '../../domain/quest_member.dart';
import 'roast_duel.dart';

/// The QUEST SHOP — strictly scoped to ONE challenge: it lists only
/// this challenge's benefits and spends only this challenge's aura.
class ChallengeShopSheet extends ConsumerStatefulWidget {
  const ChallengeShopSheet({
    super.key,
    required this.challenge,
    this.scrollController,
  });

  final Challenge challenge;

  /// Supplied by the draggable sheet so the list and the sheet share
  /// one gesture: scroll while there is content, drag the sheet down
  /// once the list sits at the top.
  final ScrollController? scrollController;

  static Future<void> show(BuildContext context, Challenge challenge) {
    return showModalBottomSheet(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: AppShapes.sheet,
      // Swipe down to leave: DraggableScrollableSheet hands the drag
      // back to the sheet when the stock list is scrolled to the top.
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => ChallengeShopSheet(
          challenge: challenge,
          scrollController: controller,
        ),
      ),
    );
  }

  @override
  ConsumerState<ChallengeShopSheet> createState() => _ChallengeShopSheetState();
}

class _ChallengeShopSheetState extends ConsumerState<ChallengeShopSheet> {
  /// Which benefit is currently being purchased (its BUY shows the
  /// spinner; the others just disable).
  String? _pendingBenefitId;

  /// Live balance: prefer the freshly invalidated list, fall back to
  /// the value the card was opened with.
  int _currentBalance() {
    final challenges = ref.watch(myChallengesProvider).valueOrNull;
    final match =
        challenges?.where((c) => c.id == widget.challenge.id).firstOrNull;
    return match?.myAura ?? widget.challenge.myAura;
  }

  Future<void> _buy(Benefit benefit) async {
    final messenger = ScaffoldMessenger.of(context);

    if (benefit.title.startsWith('Targeted Roast')) {
      final newBalance = await showDialog<int?>(
        context: context,
        builder: (_) => _TargetedRoastFlowDialog(
          challenge: widget.challenge,
          benefit: benefit,
        ),
      );

      if (newBalance != null && mounted) {
        messenger.showSnackBar(AppSnackBar(
          content: Text('🔥 Targeted Roast sent! ⚡$newBalance left.'),
          backgroundColor: AppColors.neonPurple,
        ));
      }
      return;
    }

    if (benefit.title == 'Blackout') {
      final armed = await showDialog<Blackout?>(
        context: context,
        builder: (_) => _BlackoutFlowDialog(challenge: widget.challenge),
      );
      if (armed != null && mounted) {
        // Name the actual hours. "Armed for noon" once left a player
        // wondering why nothing happened — the window had already
        // started, so the lock had jumped to the next day.
        final from = formatTime(armed.startsAt);
        final to = formatTime(armed.endsAt);
        messenger.showSnackBar(AppSnackBar(
          content: Text(armed.isRunning
              ? '🌑 Blackout live — they are locked out until $to.'
              : '🌑 Blackout armed — $from to $to.'),
          backgroundColor: AppColors.neonPurple,
        ));
      }
      return;
    }

    setState(() => _pendingBenefitId = benefit.id);

    final newBalance = await ref
        .read(purchaseControllerProvider(widget.challenge.id).notifier)
        .purchase(benefit.id);

    if (mounted) setState(() => _pendingBenefitId = null);
    if (newBalance == null) return; // error → surfaced by ref.listen

    messenger.showSnackBar(AppSnackBar(
      content: Text('🛒 "${benefit.title}" unlocked! ⚡$newBalance left.'),
      backgroundColor: AppColors.neonPurple,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final benefitsAsync = ref.watch(benefitsProvider(widget.challenge.id));
    final purchaseState =
        ref.watch(purchaseControllerProvider(widget.challenge.id));
    final balance = _currentBalance();

    ref.listen(purchaseControllerProvider(widget.challenge.id), (_, next) {
      final error = next.error;
      if (error == null) return;
      final message = error is PostgrestException
          ? error.message
          : 'Purchase failed — try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(content: Text(message), backgroundColor: AppColors.danger),
      );
    });

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (AppColors.activeType == AppThemeType.editorial)
            const EditorialCover(
                title: 'A little extra.',
                compact: true,
                chapter: 'THE PERKS EDIT',
                subtitle: 'Give your next move a twist.'),
          Text(
            'QUEST PERKS',
            textAlign: TextAlign.center,
            style:
                textTheme.headlineMedium?.copyWith(color: AppColors.neonPurple),
          ),
          const SizedBox(height: 8),
          Text(
            widget.challenge.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // ── Balance of THIS quest ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: AppColors.panelDecoration(
              accent: AppColors.neonPurple,
              fill: AppColors.neonPurple.withValues(alpha: 0.12),
              radius: 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt, color: AppColors.neonPurple, size: 20),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(
                  '$balance quest aura',
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.neonPurple,
                    fontWeight: FontWeight.w700,
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Stock ─────────────────────────────────────────────
          if (widget.challenge.attacksEnabled && !widget.challenge.amIOut) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('EGO DUEL · FREE', style: textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('Rock, paper, scissors. The loser gets roasted. '
                        'No Aura stakes, transfers or XP rewards.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: ref.watch(duelControllerProvider).isLoading
                          ? null
                          : () async {
                              final opponent = await showDialog<QuestMember>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                        title: const Text('PICK YOUR RIVAL'),
                                        content: SizedBox(
                                            width: 400,
                                            child: Consumer(
                                              builder: (context, ref, _) => ref
                                                  .watch(questMembersProvider(
                                                      widget.challenge.id))
                                                  .when(
                                                    loading: () => const Center(
                                                        child:
                                                            CircularProgressIndicator()),
                                                    error: (_, __) => const Text(
                                                        'Could not load players. Try again.'),
                                                    data: (members) {
                                                      final rivals = members
                                                          .where((m) =>
                                                              !m.isMe &&
                                                              !m.isOut &&
                                                              !m.isWinner)
                                                          .toList();
                                                      if (rivals.isEmpty) {
                                                        return const Text(
                                                            'Invite a friend to this quest first.');
                                                      }
                                                      return SingleChildScrollView(
                                                          child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                            for (final rival
                                                                in rivals)
                                                              ListTile(
                                                                title: Text(
                                                                    '@${rival.username}'),
                                                                leading: const Icon(
                                                                    Icons
                                                                        .back_hand_outlined),
                                                                onTap: () =>
                                                                    Navigator.pop(
                                                                        dialogContext,
                                                                        rival),
                                                              )
                                                          ]));
                                                    },
                                                  ),
                                            )),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dialogContext),
                                              child: const Text('CLOSE'))
                                        ],
                                      ));
                              if (opponent == null || !context.mounted) return;
                              await startDuelFlow(context, ref,
                                  challenge: widget.challenge,
                                  opponent: opponent);
                            },
                      icon: const Icon(Icons.back_hand_outlined),
                      label: const Text('CHALLENGE A FRIEND'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(widget.challenge.auraGain > 0
              ? 'Prices follow this quest’s ${widget.challenge.auraGain} Aura base reward. Your XP and level stay when you spend Aura.'
              : 'Perks are unavailable for quests with a zero Aura reward.'),
          const SizedBox(height: 8),
          Text(widget.challenge.attacksEnabled
              ? '3 outgoing attacks per account / UTC day. Ego Duels are free: no Aura or XP changes.'
              : 'Attacks are disabled in this quest.'),
          const SizedBox(height: 12),
          benefitsAsync.when(
            data: (benefits) => Column(
              children: benefits
                  .where((b) =>
                      !const ['Aura Heist', 'Aura Ward'].contains(b.title) &&
                      widget.challenge.auraGain > 0 &&
                      (widget.challenge.attacksEnabled ||
                          !const [
                            'Aura Heist',
                            'Targeted Roast',
                            'Blackout',
                            'Aura Ward'
                          ].contains(b.title)) &&
                      (!widget.challenge.isAvoid ||
                          !const [
                            'Aura Heist',
                            'Blackout',
                            'Aura Ward',
                            'Double Down'
                          ].contains(b.title)))
                  .map((b) => _BenefitTile(
                        benefit: b,
                        baseReward: widget.challenge.auraGain,
                        balance: balance,
                        isPending: _pendingBenefitId == b.id,
                        anyPending: purchaseState.isLoading,
                        onBuy: () => _buy(b),
                      ))
                  .toList(),
            ),
            loading: () => Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.neonPurple),
              ),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Could not load perks. Please try again.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.benefit,
    required this.baseReward,
    required this.balance,
    required this.isPending,
    required this.anyPending,
    required this.onBuy,
  });

  final Benefit benefit;
  final int baseReward;
  final int balance;
  final bool isPending;
  final bool anyPending;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final affordable = balance >= benefit.cost;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: AppColors.panelDecoration(
        accent: benefit.owned ? AppColors.neonGreen : AppColors.neonPurple,
        fill: AppColors.surfaceLight,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit.title,
                  style: textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                    '${(benefit.cost / baseReward).toStringAsFixed(2)} base rewards',
                    style: textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  benefit.description,
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Consumables show their stock and stay buyable (stack up);
          // cosmetics (Title Badge) are own-once.
          if (benefit.isConsumable)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (benefit.readyCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${benefit.readyCount}x READY',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.successText,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (benefit.usedCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${benefit.usedCount}x used',
                      style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                _BuyButton(
                  cost: benefit.cost,
                  enabled: !anyPending && affordable,
                  isPending: isPending,
                  onBuy: onBuy,
                ),
              ],
            )
          else if (benefit.owned)
            Text(
              'OWNED ✓',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.successText,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            _BuyButton(
              cost: benefit.cost,
              enabled: !anyPending && affordable,
              isPending: isPending,
              onBuy: onBuy,
            ),
        ],
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({
    required this.cost,
    required this.enabled,
    required this.isPending,
    required this.onBuy,
  });

  final int cost;
  final bool enabled;
  final bool isPending;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled ? onBuy : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.neonPurple,
        foregroundColor: AppColors.isDark ? AppColors.background : Colors.white,
        disabledBackgroundColor:
            AppColors.textSecondary.withValues(alpha: 0.15),
        disabledForegroundColor: AppColors.textSecondary.withValues(alpha: 0.5),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      child: isPending
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.background),
            )
          : Text('⚡ $cost'),
    );
  }
}

class _TargetedRoastFlowDialog extends ConsumerStatefulWidget {
  const _TargetedRoastFlowDialog({
    required this.challenge,
    required this.benefit,
  });

  final Challenge challenge;
  final Benefit benefit;

  @override
  ConsumerState<_TargetedRoastFlowDialog> createState() =>
      __TargetedRoastFlowDialogState();
}

class __TargetedRoastFlowDialogState
    extends ConsumerState<_TargetedRoastFlowDialog> {
  late final List<String> _roastOptions;
  String? _selectedRoast;
  QuestMember? _selectedTarget;
  int _selectedDurationSeconds = 3; // 3 or 5
  bool _isSending = false;

  int _roastCost(int tier) =>
      QuestBalance.price(widget.challenge.auraGain, 'Targeted Roast',
          tier: tier);
  int get _calculatedCost => _roastCost(_selectedDurationSeconds == 5 ? 2 : 1);

  @override
  void initState() {
    super.initState();
    _roastOptions = Roasts300.drawThree();
    _selectedRoast = _roastOptions.first;
  }

  Future<void> _send() async {
    if (_selectedTarget == null || _selectedRoast == null) return;
    setState(() => _isSending = true);

    try {
      final newBalance =
          await ref.read(challengeRepositoryProvider).sendTargetedRoast(
                challengeId: widget.challenge.id,
                targetId: _selectedTarget!.userId,
                roastText: _selectedRoast!,
                durationSeconds: _selectedDurationSeconds,
              );

      ref.invalidate(myChallengesProvider);
      ref.invalidate(questMembersProvider(widget.challenge.id));

      if (mounted) {
        Navigator.of(context).pop(newBalance);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackBar(
              content: Text('Roast error: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final membersAsync = ref.watch(questMembersProvider(widget.challenge.id));

    return AppDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.neonPurple, width: 2),
      ),
      title: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 6),
              Text(
                'TARGETED ROAST',
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.neonPurple,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Roast a teammate & lock their screen',
            style:
                textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STEP 1: Select Duration
            Text(
              '1. Select Duration:',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.neonPurple,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDurationSeconds = 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedDurationSeconds == 3
                            ? AppColors.neonPurple.withValues(alpha: 0.15)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedDurationSeconds == 3
                              ? AppColors.neonPurple
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '3 Seconds',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '⚡ ${_roastCost(1)} Aura',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.neonPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDurationSeconds = 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedDurationSeconds == 5
                            ? AppColors.neonPurple.withValues(alpha: 0.15)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedDurationSeconds == 5
                              ? AppColors.neonPurple
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '5 Seconds',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '⚡ ${_roastCost(2)} Aura',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.neonPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // STEP 2: Select Target Teammate
            Text(
              '2. Select Teammate:',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.neonPurple,
              ),
            ),
            const SizedBox(height: 6),
            membersAsync.when(
              data: (members) {
                final targets = members.where((m) => !m.isMe).toList();
                if (targets.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No other players in this quest.',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  );
                }
                return Column(
                  children: targets.map((member) {
                    final selected = _selectedTarget?.userId == member.userId;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTarget = member),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.neonPurple.withValues(alpha: 0.15)
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? AppColors.neonPurple
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: selected
                                  ? AppColors.neonPurple
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '@${member.username}',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              )),
              error: (err, _) => Text('Error: $err'),
            ),
            const SizedBox(height: 16),

            // STEP 3: Select 1 of 3 Roasts
            Text(
              '3. Select 1 of 3 Random Roasts:',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.neonPurple,
              ),
            ),
            const SizedBox(height: 6),
            Column(
              children: _roastOptions.map((roast) {
                final selected = _selectedRoast == roast;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRoast = roast),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.neonPurple.withValues(alpha: 0.12)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.neonPurple
                            : AppColors.outline.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: selected
                              ? AppColors.neonPurple
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '"$roast"',
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed:
              (_selectedTarget != null && _selectedRoast != null && !_isSending)
                  ? _send
                  : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.neonPurple,
            foregroundColor:
                AppColors.isDark ? AppColors.background : Colors.white,
            disabledBackgroundColor:
                AppColors.textSecondary.withValues(alpha: 0.2),
          ),
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('🔥 SEND ROAST (⚡$_calculatedCost)'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
class _BlackoutFlowDialog extends ConsumerStatefulWidget {
  const _BlackoutFlowDialog({required this.challenge});

  final Challenge challenge;

  @override
  ConsumerState<_BlackoutFlowDialog> createState() =>
      _BlackoutFlowDialogState();
}

class _BlackoutFlowDialogState extends ConsumerState<_BlackoutFlowDialog> {
  String _daypart = Blackout.dayparts.first;
  QuestMember? _target;
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    if (_target == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final armed = await ref.read(challengeRepositoryProvider).castBlackout(
            challengeId: widget.challenge.id,
            targetId: _target!.userId,
            daypart: _daypart,
          );
      ref.invalidate(myChallengesProvider);
      ref.invalidate(questMembersProvider(widget.challenge.id));
      if (mounted) Navigator.of(context).pop(armed);
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not arm it - try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final membersAsync = ref.watch(questMembersProvider(widget.challenge.id));
    final blocks = widget.challenge.isProgress ? 'log any reps' : 'check in';

    return AppDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.neonPurple, width: 2),
      ),
      title: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🌑', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 6),
              Text('BLACKOUT',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.neonPurple,
                    fontWeight: FontWeight.w900,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Text('Two hours where they cannot $blocks',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
      content: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Pick their blind spot:',
                style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.neonPurple)),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final part in Blackout.dayparts) ...[
                  Expanded(
                    child: Pressable(
                      onTap: () => setState(() => _daypart = part),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _daypart == part
                              ? AppColors.neonPurple.withValues(alpha: 0.15)
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _daypart == part
                                ? AppColors.neonPurple
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(Blackout.emojiFor(part),
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 2),
                            Text(Blackout.labelFor(part),
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: _daypart == part
                                      ? AppColors.neonPurple
                                      : AppColors.textSecondary,
                                )),
                            Text(Blackout.hoursFor(part),
                                style: textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (part != Blackout.dayparts.last) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
                'Their local time. Pick one that is running right now and '
                'it bites immediately.',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            Text('2. Pick your mark:',
                style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.neonPurple)),
            const SizedBox(height: 6),
            membersAsync.when(
              data: (members) {
                final targets = members
                    .where((m) => !m.isMe && m.status == 'active')
                    .toList();
                if (targets.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No one else to lock out.',
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  );
                }
                return Column(
                  children: [
                    for (final member in targets)
                      Pressable(
                        onTap: () => setState(() => _target = member),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _target?.userId == member.userId
                                ? AppColors.neonPurple.withValues(alpha: 0.15)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _target?.userId == member.userId
                                  ? AppColors.neonPurple
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                  _target?.userId == member.userId
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: _target?.userId == member.userId
                                      ? AppColors.neonPurple
                                      : AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('@${member.username}',
                                        style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                    // The one number that turns picking a
                                    // slot into an informed choice.
                                    Text(
                                        'last: '
                                        '${formatLastActivity(member.lastActivityAt)}',
                                        style: textTheme.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator())),
              error: (err, _) => Text('Error: $err'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      textTheme.bodySmall?.copyWith(color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: (_target != null && !_sending) ? _send : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.neonPurple,
            foregroundColor:
                AppColors.isDark ? AppColors.background : Colors.white,
            disabledBackgroundColor:
                AppColors.textSecondary.withValues(alpha: 0.2),
          ),
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'BLACK THEM OUT · ${QuestBalance.price(widget.challenge.auraGain, 'Blackout')}'),
        ),
      ],
    );
  }
}
