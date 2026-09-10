import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/text/dates.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../challenges/application/challenge_providers.dart';
import '../../../challenges/domain/weekly_recap.dart';

/// The Monday card: what last week actually looked like.
///
/// It introduces no mechanic and asks for no decision — it only reads
/// back what the player already did. Shown once per week and then
/// dismissed for good, so it stays an event rather than furniture.
///
/// The "seen" flag lives on the device, not in the database: which card
/// somebody already looked at is not worth a table, and getting it wrong
/// costs nothing worse than seeing the card twice.
class WeeklyRecapCard extends ConsumerStatefulWidget {
  const WeeklyRecapCard({super.key, this.compact = false});
  final bool compact;

  @override
  ConsumerState<WeeklyRecapCard> createState() => _WeeklyRecapCardState();
}

class _WeeklyRecapCardState extends ConsumerState<WeeklyRecapCard> {
  /// null = still loading the flag; true = already seen this week.
  bool? _seen;
  String? _checkedKey;

  Future<void> _loadSeen(WeeklyRecap recap) async {
    _checkedKey = recap.storageKey;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(recap.storageKey) ?? false;
    if (mounted) setState(() => _seen = seen);
  }

  Future<void> _dismiss(WeeklyRecap recap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(recap.storageKey, true);
    if (mounted) setState(() => _seen = true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final recap = ref.watch(weeklyRecapProvider).valueOrNull;

    if (recap == null || recap.isEmpty) return const SizedBox.shrink();

    // The recap arrives asynchronously, so the flag is read the first
    // time we actually know which week we are talking about.
    if (_checkedKey != recap.storageKey) {
      _loadSeen(recap);
      return const SizedBox.shrink();
    }
    if (_seen != false) return const SizedBox.shrink();

    final better = recap.checkInDelta > 0;
    final same = recap.checkInDelta == 0;

    final content = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration:
            AppColors.panelDecoration(accent: AppColors.neonPurple, glow: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'LAST WEEK',
                    style: textTheme.headlineSmall
                        ?.copyWith(color: AppColors.neonPurple, fontSize: 17),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  onPressed: () => _dismiss(recap),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: Icon(Icons.close,
                      size: 18, color: AppColors.textSecondary),
                ),
              ],
            ),
            Text(
              '${formatDate(recap.weekStart)} – ${formatDate(recap.weekEnd)}',
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),

            // The two numbers that carry the week.
            Row(
              children: [
                _Figure(
                  value: '${recap.checkIns}',
                  label: 'logged',
                  color: AppColors.neonPurple,
                ),
                _Figure(
                  value: '${recap.activeDays}/7',
                  label: 'days active',
                  color: AppColors.successText,
                ),
                _Figure(
                  value: recap.auraNet >= 0
                      ? '+${recap.auraNet}'
                      : '${recap.auraNet}',
                  label: 'aura',
                  color: recap.auraNet >= 0
                      ? AppColors.successText
                      : AppColors.danger,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Everything else only shows up when it actually happened —
            // a wall of zeroes would say nothing.
            _line(
              textTheme,
              same
                  ? 'Same as the week before.'
                  : better
                      ? '${recap.checkInDelta} more than the week before.'
                      : '${recap.checkInDelta.abs()} fewer than the week before.',
              same
                  ? AppColors.textSecondary
                  : (better ? AppColors.successText : AppColors.danger),
              same
                  ? Icons.remove
                  : (better ? Icons.trending_up : Icons.trending_down),
            ),
            if (recap.bestDay != null && recap.bestDayCount > 1)
              _line(
                textTheme,
                'Best day: ${formatLastActivity(recap.bestDay!).split(',').first} '
                'with ${recap.bestDayCount}.',
                AppColors.textSecondary,
                Icons.star_outline,
              ),
            if (recap.strikes > 0)
              _line(
                textTheme,
                '${recap.strikes} ${recap.strikes == 1 ? 'strike' : 'strikes'} taken.',
                AppColors.danger,
                Icons.close,
              ),
            if (recap.questsFinished > 0)
              _line(
                textTheme,
                '${recap.questsFinished} quest'
                '${recap.questsFinished == 1 ? '' : 's'} finished.',
                AppColors.successText,
                Icons.emoji_events,
              ),
            if (recap.duelsWon + recap.duelsLost > 0)
              _line(
                textTheme,
                'Duels ${recap.duelsWon}:${recap.duelsLost}.',
                recap.duelsWon >= recap.duelsLost
                    ? AppColors.successText
                    : AppColors.danger,
                Icons.casino_outlined,
              ),
          ],
        ),
      ),
    );
    if (!widget.compact) return content;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppColors.panelDecoration(accent: AppColors.neonPurple),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(Icons.date_range, color: AppColors.accentText),
        title: const Text('WEEKLY RECAP'),
        subtitle: Text(
            '${recap.checkIns} logged · ${recap.activeDays}/7 days active'),
        children: [content],
      ),
    );
  }

  Widget _line(TextTheme textTheme, String text, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodySmall?.copyWith(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// One big number with its caption.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
