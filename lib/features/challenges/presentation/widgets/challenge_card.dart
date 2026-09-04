import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../home/presentation/widgets/robbed_notice_gate.dart';
import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import 'benefit_chip.dart';
import 'challenge_shop_sheet.dart';
import 'progress_widgets.dart';
import 'slip_widgets.dart';

/// One quest in the Challenges list — Cyber-Pixel style:
/// dark surface, neon-yellow accent, stakes as glowing chips,
/// and the daily CHECK-IN button.
class ChallengeCard extends ConsumerWidget {
  const ChallengeCard({super.key, required this.challenge});

  final Challenge challenge;

  Future<void> _checkIn(BuildContext context, WidgetRef ref) async {
    // Capture the messenger BEFORE the await: the card may be rebuilt
    // (list invalidation) by the time the snackbar is shown.
    final messenger = ScaffoldMessenger.of(context);

    final gained = await ref
        .read(checkInControllerProvider(challenge.id).notifier)
        .checkIn();

    if (gained == null) {
      // Report the error HERE (not via ref.listen): the detail screen's
      // day sheet shares this controller, and two listeners would show
      // the same snackbar twice.
      final error = ref.read(checkInControllerProvider(challenge.id)).error;
      messenger.showSnackBar(SnackBar(
        content: Text(error is PostgrestException
            ? error.message
            : 'Check-in failed - try again.'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

    // A heist may have swiped this payout — reveal it and skip the
    // "+aura" toast (gained is 0 when robbed).
    if (context.mounted) {
      final robbed = await revealRobbedIfAny(context, ref, challenge.id);
      if (robbed != null) return;
    }

    messenger.showSnackBar(SnackBar(
      content: Text('⚡ +$gained Aura! Quest checked in.'),
      backgroundColor: AppColors.neonGreen,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final checkInState = ref.watch(checkInControllerProvider(challenge.id));
    // A running lockout has to reach this card too — otherwise the
    // button here still invites a tap the server will refuse.
    final runningBlackout =
        ref.watch(myBlackoutProvider(challenge.id)).valueOrNull;
    final blackout =
        (runningBlackout != null && runningBlackout.isRunning)
            ? runningBlackout
            : null;

    return Pressable(
      // Tapping the card (outside its buttons) opens the detail view.
      onTap: () => context.push('${AppRoutes.challenges}/${challenge.id}'),
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppColors.panelDecoration(accent: AppColors.neonYellow),
      child: Row(
        children: [
          // ── Trophy badge ─────────────────────────────────
          // Owning the "Title Badge" turns the quest icon golden —
          // that's literally what the shop item promises.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AppColors.panelDecoration(
              accent: AppColors.neonYellow,
              fill: AppColors.surfaceLight,
              radius: 8.0,
              glow: challenge.ownedBenefits.contains('Title Badge'),
            ),
            child: Icon(Icons.emoji_events,
                color: AppColors.warningText, size: 28),
          ),
          const SizedBox(width: 16),

          // ── Title + stakes ───────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    // Party size first — social quests should pop.
                    _StatChip(
                      icon: challenge.memberCount > 1
                          ? Icons.group
                          : Icons.person,
                      label: '${challenge.memberCount}',
                      color: challenge.memberCount > 1
                          ? AppColors.neonPink
                          : AppColors.textSecondary,
                    ),
                    // Team quests wear their mode on the sleeve.
                    if (challenge.mode == QuestMode.coop)
                      _StatChip(
                        icon: Icons.handshake,
                        label: 'CO-OP',
                        color: AppColors.neonPurple,
                      ),
                    if (challenge.mode == QuestMode.versus)
                      _StatChip(
                        icon: Icons.sports_kabaddi,
                        label: challenge.myTeam == 'blue'
                            ? 'TEAM BLUE'
                            : 'TEAM RED',
                        color: challenge.myTeam == 'blue'
                            ? AppColors.neonCyan
                            : AppColors.danger,
                      ),
                    _StatChip(
                      icon: Icons.hourglass_bottom,
                      label: challenge.timeLeftLabel,
                      color: AppColors.neonCyan,
                    ),
                    _StatChip(
                      icon: Icons.bolt,
                      label: '+${challenge.auraGain}',
                      color: AppColors.neonGreen,
                    ),
                    _StatChip(
                      icon: Icons.heart_broken,
                      label: '-${challenge.auraPenalty}',
                      color: AppColors.danger,
                    ),
                    _StatChip(
                      icon: Icons.shield_outlined,
                      label:
                          '${challenge.strikesUsed}/${challenge.maxStrikes} strikes',
                      // Turns red once the budget is fully burnt.
                      color: challenge.strikesUsed >= challenge.maxStrikes
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                    // Flexible schedules get their frequency shown;
                    // plain daily is the default and needs no chip.
                    if (challenge.checkinPeriod != CheckinPeriod.daily)
                      _StatChip(
                        icon: Icons.repeat,
                        label: '${challenge.checkinsPerPeriod}x/'
                            '${challenge.checkinPeriod == CheckinPeriod.weekly ? 'week' : 'month'}',
                        color: AppColors.neonPink,
                      ),
                    // Rest days change when the quest is due, so they
                    // belong on the card even for a daily quest.
                    if (challenge.hasRestDays)
                      _StatChip(
                        icon: Icons.event_repeat,
                        label: challenge.weekdayLabel,
                        color: AppColors.neonPink,
                      ),
                    // Owned shop gear, right in the overview.
                    for (final title in challenge.ownedBenefits)
                      BenefitChip(title: title),
                  ],
                ),
                // Live progress read-out for progress quests.
                if (challenge.isProgress) ...[
                  const SizedBox(height: 10),
                  QuestProgressBar(challenge: challenge, compact: true),
                ],
                // Slip budget for negative quests.
                if (challenge.isAvoid) ...[
                  const SizedBox(height: 10),
                  SlipMeter(challenge: challenge, compact: true),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Quest aura + actions ─────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // THIS challenge's aura balance — the shop currency.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(Icons.bolt,
                      size: 18, color: AppColors.neonPurple),
                  Text(
                    '${challenge.myAura}',
                    style: textTheme.titleLarge
                        ?.copyWith(color: AppColors.neonPurple),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Out of the running: the quest stays on the list so the
              // player can keep watching, but the action slot turns into
              // a plain marker. Tapping the card still opens everything.
              if (challenge.amIOut)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('☠️', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text('OUT',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          )),
                    ],
                  ),
                )
              // Locked out for the next couple of hours: the same pill
              // treatment, with the time left instead of a verb.
              else if (blackout != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.neonPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.neonPurple.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🌑', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text(blackout.remainingLabel,
                          style: TextStyle(
                            color: AppColors.neonPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          )),
                    ],
                  ),
                )
              // A lobby quest can't be checked into yet — it shows a
              // quiet "LOBBY" pill and is opened from the detail screen.
              else if (challenge.isLobby)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.neonYellow.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.neonYellow.withValues(alpha: 0.5)),
                  ),
                  child: Text('LOBBY',
                      style: TextStyle(
                        color: AppColors.warningText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                )
              // Progress quests collect towards a target instead of
              // being ticked off.
              else if (challenge.isProgress)
                _AddProgressButton(
                  done: challenge.checkedInToday,
                  onPressed: () =>
                      showAddProgressSheet(context, ref, challenge),
                )
              // Negative quests are won by inaction — there is nothing
              // to tick off, only a slip to own up to.
              else if (challenge.isAvoid)
                SlipButton(
                  challenge: challenge,
                  compact: true,
                  busy: ref
                      .watch(slipControllerProvider(challenge.id))
                      .isLoading,
                  onPressed: () => logSlipAndReveal(context, ref, challenge),
                )
              else
                _CheckInButton(
                  checkedInToday: challenge.checkedInToday,
                  isLoading: checkInState.isLoading,
                  onPressed: () => _checkIn(context, ref),
                ),
              // Opens the shop scoped to exactly this challenge.
              TextButton.icon(
                onPressed: challenge.amIOut
                    ? null
                    : () => ChallengeShopSheet.show(context, challenge),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.neonPurple,
                  disabledForegroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.storefront, size: 14),
                label: const Text('SHOP'),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

/// Progress counterpart to the check-in button: "+ ADD" until the
/// target is met, then a green "✓ MORE" — still tappable, because you
/// can always log bonus reps beyond the goal.
class _AddProgressButton extends StatelessWidget {
  const _AddProgressButton({required this.done, required this.onPressed});

  final bool done;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (done) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.successText,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: BorderSide(color: AppColors.neonGreen),
          textStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        icon: const Icon(Icons.check, size: 15),
        label: const Text('MORE'),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.neonPurple,
        foregroundColor: AppColors.background,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      icon: const Icon(Icons.add, size: 16),
      label: const Text('ADD'),
    );
  }
}

/// Compact action button: neon-green CHECK-IN → spinner → gray DONE.
class _CheckInButton extends StatelessWidget {
  const _CheckInButton({
    required this.checkedInToday,
    required this.isLoading,
    required this.onPressed,
  });

  final bool checkedInToday;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Already done today: disabled, quiet, unmistakable.
    if (checkedInToday) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          disabledForegroundColor: AppColors.textSecondary,
          side: BorderSide(
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        child: const Text('DONE ✓'),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.neonGreen,
        foregroundColor: AppColors.background,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      child: isLoading
          ?  SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.background,
              ),
            )
          : const Text('CHECK-IN'),
    );
  }
}

/// Tiny neon stat pill (time left / aura gain / penalty).
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
