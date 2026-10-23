import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import '../../domain/duel.dart';
import 'roast_duel.dart';

/// The free-game ledger. Results are separate from quest Aura and XP.
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
    } else if (duel.status == 'active' || duel.status == 'pending') {
      DuelSheet.show(
        context,
        IncomingDuel(
          id: duel.id,
          questTitle: challenge.title,
          challengerName: duel.otherName(myId),
          challengerAvatar: duel.otherAvatar(myId),
          createdAt: duel.createdAt,
          status: duel.status,
          isChallenger: duel.isChallenger(myId),
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
              iWon ? 'WON' : 'ROASTED',
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
      'active' || 'pending' => (
          AppColors.neonPink,
          _Badge(
            text: duel.status == 'active' ? 'PLAYING' : 'YOUR MOVE',
            icon: Icons.back_hand_outlined,
            color: AppColors.socialText,
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

    final subtitle = resolved || duel.status == 'active'
        ? '${duel.scoreFor(myId)} · first to 3'
        : 'Free to play · Aura and XP unchanged';

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
            Icon(Icons.back_hand_outlined, size: 18, color: accent),
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
