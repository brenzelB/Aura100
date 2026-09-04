import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/text/quantity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/aura_avatar.dart';
import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import '../../domain/quest_activity.dart';

/// ACTIVITY — the party's shared record for this quest: who hit their
/// target, who took a strike, who blew it, who won a duel, who went
/// shopping, who roasted whom.
///
/// Collapsed to [_collapsedCount] rows on open. The full record can run
/// to dozens of entries and would otherwise push the rest of the screen
/// out of sight; the button below unrolls it.
class QuestActivitySection extends ConsumerStatefulWidget {
  const QuestActivitySection({super.key, required this.challenge});

  final Challenge challenge;

  @override
  ConsumerState<QuestActivitySection> createState() =>
      _QuestActivitySectionState();
}

class _QuestActivitySectionState extends ConsumerState<QuestActivitySection> {
  /// Enough to see what just happened without burying the screen.
  static const _collapsedCount = 5;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final textTheme = Theme.of(context).textTheme;
    final activityAsync = ref.watch(questActivityProvider(challenge.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ACTIVITY',
              style: textTheme.headlineSmall
                  ?.copyWith(color: AppColors.accentText),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'everyone in this quest',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        activityAsync.when(
          // Auto-refresh reloads this; don't flash a spinner over the
          // feed that's already on screen.
          skipLoadingOnReload: true,
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accentText),
            ),
          ),
          error: (error, _) => Text(
            'Could not load the activity.\n$error',
            style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Text(
                'Nothing has happened yet. Be the first.',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              );
            }
            final hidden = items.length - _collapsedCount;
            final shown =
                _expanded ? items : items.take(_collapsedCount).toList();

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration:
                  AppColors.panelDecoration(accent: AppColors.neonCyan),
              child: Column(
                children: [
                  for (final item in shown)
                    _ActivityRow(item: item, challenge: challenge),
                  if (hidden > 0) ...[
                    Divider(
                        height: 14,
                        color: AppColors.textSecondary.withValues(alpha: 0.2)),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _expanded = !_expanded),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accentText,
                          minimumSize: const Size(0, 44),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        icon: Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 18),
                        label: Text(_expanded
                            ? 'SHOW LESS'
                            : 'SHOW ALL ($hidden more)'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.challenge});

  final QuestActivity item;
  final Challenge challenge;

  /// Icon, colour and the sentence itself, per kind.
  (IconData, Color, String) _describe() {
    final unit = challenge.unit ?? '';
    final amount = item.amount;

    return switch (item.kind) {
      'progress' => (
          Icons.add_circle_outline,
          AppColors.neonPurple,
          'logged +${formatQuantity(amount ?? 0)} $unit',
        ),
      'check_in' => (
          Icons.check_circle,
          AppColors.neonGreen,
          challenge.isProgress ? 'reached the target' : 'checked in',
        ),
      'milestone' => (
          Icons.local_fire_department,
          AppColors.neonYellow,
          'hit a ${amount ?? 0}-day streak',
        ),
      'completed' => (
          Icons.emoji_events,
          AppColors.neonGreen,
          'completed the quest (${amount ?? 0} aura)',
        ),
      'bonus' => (
          Icons.stars,
          AppColors.neonYellow,
          'earned a +${amount ?? 0} bonus',
        ),
      'penalty' => (
          Icons.heart_broken,
          AppColors.danger,
          'lost ${(amount ?? 0).abs()} aura',
        ),
      'strike' => (
          Icons.close,
          AppColors.danger,
          'took strike ${amount ?? 0}',
        ),
      'shield_saved' => (
          Icons.security,
          AppColors.neonGreen,
          'was saved by a Streak Shield',
        ),
      'strike_repaired' => (
          Icons.build,
          AppColors.neonGreen,
          'repaired a strike',
        ),
      'failed' => (
          Icons.flag,
          AppColors.danger,
          'failed the quest (${amount ?? 0} salvaged)',
        ),
      'duel_won' => (
          Icons.casino,
          AppColors.neonGreen,
          'won a duel (+${amount ?? 0})',
        ),
      'duel_lost' => (
          Icons.casino,
          AppColors.danger,
          'lost a duel (${amount ?? 0})',
        ),
      'versus_won' => (
          Icons.sports_kabaddi,
          AppColors.neonGreen,
          'took +${amount ?? 0} tribute',
        ),
      'versus_lost' => (
          Icons.sports_kabaddi,
          AppColors.danger,
          'paid ${(amount ?? 0).abs()} tribute',
        ),
      'eliminated' => (
          Icons.dangerous,
          AppColors.danger,
          'was eliminated',
        ),
      'lms_finished' => (
          Icons.flag,
          AppColors.textSecondary,
          'the quest ended',
        ),
      'heist_robbed' => (
          Icons.money_off,
          AppColors.danger,
          'got robbed of ${(amount ?? 0).abs()} aura',
        ),
      'heist_hit' => (
          Icons.savings,
          AppColors.neonGreen,
          'pulled off a +${amount ?? 0} heist',
        ),
      'avoided' => (
          Icons.shield_moon,
          AppColors.neonGreen,
          'stayed clean (+${amount ?? 0})',
        ),
      'slip_over' => (
          Icons.block,
          AppColors.danger,
          'slipped past the limit',
        ),
      'purchase' => (
          Icons.storefront,
          AppColors.neonPurple,
          item.detail == null
              ? 'bought something in the shop'
              : 'bought ${item.detail}',
        ),
      'roast' => (
          Icons.local_fire_department,
          AppColors.neonPink,
          item.detail == null ? 'sent a roast' : 'roasted @${item.detail}',
        ),
      // Only the two sides of a lockout ever get this row — the rest of
      // the party is not supposed to see one coming.
      'blackout' => (
          Icons.dark_mode,
          AppColors.neonPurple,
          item.detail == null
              ? 'set a blackout'
              : 'blacked out @${item.detail}',
        ),
      _ => (Icons.info_outline, AppColors.textSecondary, item.kind),
    };
  }

  String get _timeAgo {
    final diff = DateTime.now().toUtc().difference(item.createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (icon, color, text) = _describe();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          AuraAvatar(
            emoji: item.avatarEmoji,
            username: item.username,
            size: 26,
            color: color,
            borderWidth: 1,
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
                children: [
                  TextSpan(
                    text: item.isMe ? 'You ' : '@${item.username} ',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: text, style: TextStyle(color: color)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _timeAgo,
            style: textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
