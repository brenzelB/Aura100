import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import '../../domain/duel.dart';
import 'dice_duel.dart';

/// The quest's duel ledger on the detail screen: how often was rolled
/// today, what is still pending, and every past result — resolved
/// ones replay their animation on tap.
class QuestDuelsSection extends ConsumerWidget {
  const QuestDuelsSection({super.key, required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duels =
        ref.watch(questDuelsProvider(challenge.id)).valueOrNull ?? const [];
    if (duels.isEmpty) return const SizedBox.shrink();

    final myId = ref.watch(currentUserProvider)?.id ?? '';
    final textTheme = Theme.of(context).textTheme;

    final now = DateTime.now().toUtc();
    final todayCount = duels
        .where((d) =>
            d.createdAt.toUtc().year == now.year &&
            d.createdAt.toUtc().month == now.month &&
            d.createdAt.toUtc().day == now.day)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'DUELS',
              style: textTheme.headlineSmall
                  ?.copyWith(color: AppColors.neonPurple),
            ),
            const SizedBox(width: 10),
            Text(
              todayCount == 0 ? 'none today' : '$todayCount played today',
              style:
                  textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final duel in duels.take(8))
          _DuelTile(duel: duel, myId: myId, challenge: challenge),
      ],
    );
  }
}

class _DuelTile extends ConsumerWidget {
  const _DuelTile({
    required this.duel,
    required this.myId,
    required this.challenge,
  });

  final QuestDuel duel;
  final String myId;
  final Challenge challenge;

  void _open(BuildContext context) {
    if (duel.status == 'resolved') {
      DuelReplaySheet.show(context, duel: duel, questTitle: challenge.title);
    } else if (duel.status == 'pending' && !duel.isChallenger(myId)) {
      // My move: the regular accept flow.
      DuelSheet.show(
        context,
        IncomingDuel(
          id: duel.id,
          questTitle: challenge.title,
          challengerName: duel.challengerName,
          challengerAvatar: duel.challengerAvatar,
          stake: duel.stake,
          createdAt: duel.createdAt,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final iAmChallenger = duel.isChallenger(myId);
    final resolved = duel.status == 'resolved';
    final iWon = resolved && duel.wonBy(myId);

    final (Color accent, Widget trailing) = switch (duel.status) {
      'resolved' => (
          iWon ? AppColors.neonGreen : AppColors.danger,
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              iWon ? 'WON +${duel.stake}' : 'LOST -${duel.stake}',
              style: textTheme.bodyMedium?.copyWith(
                color: iWon ? AppColors.successText : AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.play_circle_outline,
                size: 18, color: AppColors.textSecondary),
          ]),
        ),
      'pending' when iAmChallenger => (
          AppColors.neonYellow,
          _Badge(
            text: 'PENDING',
            icon: Icons.hourglass_top,
            color: AppColors.neonYellow,
          ),
        ),
      'pending' => (
          AppColors.neonPink,
          _Badge(
            text: 'YOUR MOVE',
            icon: Icons.casino,
            color: AppColors.neonPink,
          ),
        ),
      'declined' => (
          AppColors.textSecondary,
          Text('declined',
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
        ),
      _ => (
          AppColors.textSecondary,
          Text('expired',
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
        ),
    };

    // Resolved duels show the final score right in the subtitle.
    final String subtitle;
    if (resolved) {
      final my = duel.myDice(myId)!;
      final their = duel.theirDice(myId)!;
      subtitle = 'you ${my[0] + my[1]} : ${their[0] + their[1]} · '
          'stake ${duel.stake}';
    } else {
      subtitle = 'stake ${duel.stake} · pot ${duel.stake * 2}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () => _open(context),
        child: Row(
          children: [
            Icon(Icons.casino, size: 18, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vs @${duel.otherName(myId)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
