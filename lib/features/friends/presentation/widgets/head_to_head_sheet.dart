import 'package:aura_quest/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/aura_avatar.dart';
import '../../../challenges/application/challenge_providers.dart';
import '../../domain/head_to_head.dart';

/// The running score against one friend.
///
/// Counted only over quests both are actually in — a comparison across
/// quests the other never joined would flatter whoever simply signed up
/// for more. No new rule, no new data: check-ins and duels that were
/// already on the board, finally added up.
Future<void> showHeadToHeadSheet(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String username,
  String? avatarEmoji,
}) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: AppShapes.sheet,
    builder: (_) => _HeadToHeadSheet(
      userId: userId,
      username: username,
      avatarEmoji: avatarEmoji,
    ),
  );
}

class _HeadToHeadSheet extends ConsumerWidget {
  const _HeadToHeadSheet({
    required this.userId,
    required this.username,
    this.avatarEmoji,
  });

  final String userId;
  final String username;
  final String? avatarEmoji;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(headToHeadProvider(
        (id: userId, username: username, emoji: avatarEmoji)));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuraAvatar(
                emoji: avatarEmoji,
                username: username,
                size: 40,
                color: AppColors.neonCyan,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOU vs @$username',
                        style: textTheme.headlineSmall
                            ?.copyWith(color: AppColors.accentText)),
                    Text('across the quests you share',
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(
              'Could not load the record. Please try again.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
            data: (record) => _body(context, textTheme, record),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, TextTheme textTheme, HeadToHead r) {
    if (!r.hasHistory) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No shared quests yet. Invite @${r.username} to one and the '
          'score starts counting itself.',
          style: textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary, height: 1.4),
        ),
      );
    }

    final headline = r.isTied
        ? 'Dead even.'
        : r.amIAhead
            ? "You're ahead."
            : '@${r.username} is ahead.';
    final headlineColor = r.isTied
        ? AppColors.textSecondary
        : (r.amIAhead ? AppColors.successText : AppColors.danger);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The score, big, because it is the whole point of the sheet.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: AppColors.panelDecoration(accent: headlineColor),
          child: Column(
            children: [
              Text(
                r.scoreLine,
                style: textTheme.displaySmall?.copyWith(
                  color: headlineColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text('check-ins · you : them',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Text(headline,
                  style: textTheme.bodyMedium?.copyWith(
                      color: headlineColor, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Row(
          icon: Icons.flag_outlined,
          label: 'Shared quests',
          value: '${r.sharedQuests}',
          color: AppColors.accentText,
        ),
        _Row(
          icon: Icons.bolt,
          label: 'Aura in those quests',
          value: '${r.myAura} : ${r.theirAura}',
          color: AppColors.neonPurple,
        ),
        // Duels only earn a line once one has actually been fought.
        if (r.duelsWon + r.duelsLost > 0)
          _Row(
            icon: Icons.casino_outlined,
            label: 'Dice duels',
            value: r.duelLine,
            color: r.duelsWon >= r.duelsLost
                ? AppColors.successText
                : AppColors.danger,
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary)),
          ),
          Text(
            value,
            style: textTheme.bodyLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
