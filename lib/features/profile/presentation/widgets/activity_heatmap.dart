import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/text/dates.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../challenges/application/challenge_providers.dart';

/// A year of habit, one square per day.
///
/// Adds no rule and asks nothing of the player — it only draws what the
/// check-ins and progress entries already say. The point is the shape:
/// an unbroken block reads as a streak long before any number does, and
/// a gap is visible without being scolded for it.
class ActivityHeatmap extends ConsumerStatefulWidget {
  const ActivityHeatmap({super.key});

  @override
  ConsumerState<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends ConsumerState<ActivityHeatmap> {
  static const _weeks = 53;
  static const _cell = 11.0;
  static const _gap = 3.0;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Open on today, not on last January — the recent weeks are the
    // ones anyone actually wants to see.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final byDay = ref.watch(activityByDayProvider).valueOrNull ?? const {};

    // The grid ends on the Sunday of the current week, so the last
    // column is always a full one and today never sits mid-air.
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final lastSunday = today.add(Duration(days: 7 - today.weekday));
    final firstMonday =
        lastSunday.subtract(const Duration(days: _weeks * 7 - 1));

    final busiest =
        byDay.values.isEmpty ? 1 : byDay.values.reduce((a, b) => a > b ? a : b);
    final totalDays = byDay.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'THE YEAR',
              style: textTheme.headlineSmall
                  ?.copyWith(color: AppColors.accentText),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                totalDays == 0
                    ? 'nothing logged yet'
                    : '$totalDays active ${totalDays == 1 ? 'day' : 'days'}',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppColors.panelDecoration(accent: AppColors.neonGreen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var week = 0; week < _weeks; week++) ...[
                      Column(
                        children: [
                          for (var day = 0; day < 7; day++)
                            _cellFor(
                              firstMonday
                                  .add(Duration(days: week * 7 + day)),
                              today,
                              byDay,
                              busiest,
                            ),
                        ],
                      ),
                      if (week < _weeks - 1) const SizedBox(width: _gap),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Legend, in the same language the squares speak.
              Row(
                children: [
                  Text('less',
                      style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary, fontSize: 10)),
                  const SizedBox(width: 6),
                  for (final step in [0.0, 0.34, 0.67, 1.0]) ...[
                    Container(
                      width: _cell,
                      height: _cell,
                      decoration: BoxDecoration(
                        color: _shade(step),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: _gap),
                  ],
                  const SizedBox(width: 3),
                  Text('more',
                      style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cellFor(
    DateTime day,
    DateTime today,
    Map<DateTime, int> byDay,
    int busiest,
  ) {
    // Days after today would suggest the future is already empty —
    // leave them out entirely.
    final future = day.isAfter(today);
    final count = byDay[day] ?? 0;
    final intensity = count == 0 ? 0.0 : (count / busiest).clamp(0.25, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: _gap),
      child: Tooltip(
        message: future
            ? ''
            : '${formatDate(day)} — '
                '${count == 0 ? 'nothing' : '$count logged'}',
        child: Container(
          width: _cell,
          height: _cell,
          decoration: BoxDecoration(
            color: future ? Colors.transparent : _shade(intensity),
            borderRadius: BorderRadius.circular(2),
            border: day == today
                ? Border.all(color: AppColors.accentText, width: 1.2)
                : null,
          ),
        ),
      ),
    );
  }

  /// Empty days stay visible as a faint grid — a hole you can see is
  /// more honest than no square at all.
  Color _shade(double intensity) => intensity == 0
      ? AppColors.textSecondary.withValues(alpha: 0.12)
      : AppColors.neonGreen.withValues(alpha: 0.25 + 0.75 * intensity);
}
