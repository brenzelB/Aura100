import 'package:aura_quest/core/widgets/app_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';

/// A daily nudge for THIS quest, at a time this player picks.
///
/// Per player and per quest: two people in the same quest can be
/// reminded at completely different times, and the same person can want
/// 07:00 for the gym and 22:00 for journalling.
///
/// The time is the player's own local time — the server knows the
/// device's UTC offset already, from the Blackout feature.
///
/// Nothing arrives on a day the quest is already done, on a rest day, or
/// once the player is out. That restraint is the whole point: a reminder
/// for something already ticked off is the fastest way to get every
/// notification muted, attacks included.
class QuestReminderRow extends ConsumerWidget {
  const QuestReminderRow({super.key, required this.challenge});

  final Challenge challenge;

  Future<void> _pick(BuildContext context, WidgetRef ref,
      ({int hour, int minute})? current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 19, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'REMIND ME AT',
    );
    if (picked == null || !context.mounted) return;

    try {
      await ref.read(challengeRepositoryProvider).setQuestReminder(
            challengeId: challenge.id,
            hour: picked.hour,
            minute: picked.minute,
          );
      ref.invalidate(questReminderProvider(challenge.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
        content: Text('Reminder set for ${_label(picked.hour, picked.minute)}. '
            'Skipped on days you already logged.'),
        backgroundColor: AppColors.surfaceLight,
      ));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
        content: const Text('Could not save the reminder.'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(challengeRepositoryProvider)
          .clearQuestReminder(challenge.id);
      ref.invalidate(questReminderProvider(challenge.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
        content: const Text('Reminder off.'),
        backgroundColor: AppColors.surfaceLight,
      ));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
        content: const Text('Could not turn it off.'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  static String _label(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing to remind a spectator about, and a lobby has not started.
    if (challenge.amIOut || challenge.isLobby) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(questReminderProvider(challenge.id));
    final at = async.valueOrNull;
    final on = at != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: AppColors.panelDecoration(
        accent: on ? AppColors.accentText : AppColors.outline,
      ),
      child: Row(
        children: [
          Icon(
            on ? Icons.alarm_on : Icons.alarm_add_outlined,
            size: 20,
            color: on ? AppColors.accentText : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  on ? 'DAILY REMINDER' : 'REMIND ME',
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: on ? AppColors.accentText : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  on
                      // Says what it will NOT do, because that is the part
                      // people worry about before switching it on.
                      ? 'Every day at ${_label(at.hour, at.minute)}'
                          '${challenge.hasRestDays ? ' · ${challenge.weekdayLabel}' : ''}'
                          ' — silent once you have logged.'
                      : 'One nudge a day, at a time you pick. Nothing on '
                          'days you already logged.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (on)
            IconButton(
              tooltip: 'Turn off',
              onPressed: () => _clear(context, ref),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
            ),
          TextButton(
            onPressed: () => _pick(context, ref, at),
            child: Text(
              on ? _label(at.hour, at.minute) : 'SET',
              style: TextStyle(
                color: AppColors.neonPink,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
