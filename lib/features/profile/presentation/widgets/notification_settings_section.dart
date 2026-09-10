import 'package:aura_quest/core/widgets/app_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../challenges/application/challenge_providers.dart';
import '../../../challenges/domain/challenge.dart';

/// The four notification categories, as stored server-side.
class NotificationSettings {
  const NotificationSettings({
    this.attacks = true,
    this.duels = true,
    this.social = true,
    this.quests = true,
  });

  final bool attacks;
  final bool duels;
  final bool social;
  final bool quests;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        attacks: json['attacks'] as bool? ?? true,
        duels: json['duels'] as bool? ?? true,
        social: json['social'] as bool? ?? true,
        quests: json['quests'] as bool? ?? true,
      );

  NotificationSettings copyWith({
    bool? attacks,
    bool? duels,
    bool? social,
    bool? quests,
  }) =>
      NotificationSettings(
        attacks: attacks ?? this.attacks,
        duels: duels ?? this.duels,
        social: social ?? this.social,
        quests: quests ?? this.quests,
      );
}

final notificationSettingsProvider =
    FutureProvider.autoDispose<NotificationSettings>((ref) async {
  if (!SupabaseConfig.isConfigured) return const NotificationSettings();
  final user = ref.watch(currentUserProvider);
  if (user == null) return const NotificationSettings();
  final row = await Supabase.instance.client
      .rpc<Map<String, dynamic>>('get_notification_settings');
  return NotificationSettings.fromJson(row);
});

/// Three switches, plus the per-quest reminders under the last one.
///
/// Deliberately not one master switch: somebody who has had enough of
/// being ambushed still wants to hear about quest invites. The system
/// permission is the master switch, and it lives in Android's settings
/// where it belongs.
///
/// Attacks and duels share a switch — to the player both are the same
/// thing, something a quest mate does to them. The database keeps the
/// categories apart because they route to different screens when
/// tapped, but that is no reason to ask twice.
class NotificationSettingsSection extends ConsumerStatefulWidget {
  const NotificationSettingsSection({super.key});

  @override
  ConsumerState<NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends ConsumerState<NotificationSettingsSection> {
  /// Local echo of the server state, so a flipped switch moves at once
  /// instead of after a round trip.
  NotificationSettings? _local;
  bool _saving = false;

  Future<void> _save(NotificationSettings next) async {
    final previous = _local;
    setState(() {
      _local = next;
      _saving = true;
    });
    try {
      await Supabase.instance.client.rpc<void>(
        'set_notification_settings',
        params: {
          'p_attacks': next.attacks,
          'p_duels': next.duels,
          'p_social': next.social,
          'p_quests': next.quests,
        },
      );
    } catch (error) {
      // Put the switch back where it was — leaving it in a state the
      // server never accepted would quietly lie to the player.
      if (mounted) {
        setState(() => _local = previous);
        ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
          content: const Text('Could not save that. Try again.'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(notificationSettingsProvider);
    final settings = _local ?? async.valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTIFICATIONS',
          style: textTheme.headlineSmall?.copyWith(color: AppColors.accentText),
        ),
        const SizedBox(height: 6),
        Text(
          'What is worth interrupting you for. Turning everything off '
          'here does not stop the game — you just find out later.',
          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        if (settings == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          // Angriffe und Duelle teilen sich einen Schalter: Aus Sicht des
          // Spielers ist beides dasselbe - etwas, das ein Mitspieler
          // gegen ihn unternimmt. Beide Spalten werden mitgeschrieben,
          // damit die Daten in sich stimmig bleiben.
          _Toggle(
            icon: Icons.bolt,
            label: 'Player attacks',
            hint: 'Blackout, aura heist, roast, duels',
            value: settings.attacks,
            enabled: !_saving,
            onChanged: (v) => _save(settings.copyWith(attacks: v, duels: v)),
          ),
          _Toggle(
            icon: Icons.group_outlined,
            label: 'Social',
            hint: 'Invites, friend requests, pokes',
            value: settings.social,
            enabled: !_saving,
            onChanged: (v) => _save(settings.copyWith(social: v)),
          ),
          _Toggle(
            icon: Icons.flag_outlined,
            label: 'Quests',
            hint: 'Strikes, wins, losses',
            value: settings.quests,
            enabled: !_saving,
            onChanged: (v) => _save(settings.copyWith(quests: v)),
          ),

          // Die Erinnerungen haengen unter Quests, weil sie dieselbe
          // Sache betreffen - und weil man sie sonst nur findet, indem
          // man jede Quest einzeln oeffnet.
          const _ReminderList(),
        ],
      ],
    );
  }
}

/// The per-quest reminders, gathered in one place.
///
/// They are set inside each quest as well, but only somebody who
/// already knows the feature exists goes looking there. Listing them
/// here makes them findable and — more useful — comparable: you see at
/// a glance that three quests all nag at 19:00.
///
/// Indented under the Quests toggle rather than given a heading of its
/// own, because that is what it belongs to.
class _ReminderList extends ConsumerWidget {
  const _ReminderList();

  static String _label(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Challenge quest,
    ({int hour, int minute})? current,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 19, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'REMIND ME AT',
    );
    if (picked == null) return;
    await ref.read(challengeRepositoryProvider).setQuestReminder(
          challengeId: quest.id,
          hour: picked.hour,
          minute: picked.minute,
        );
    ref.invalidate(questRemindersProvider);
    ref.invalidate(questReminderProvider(quest.id));
  }

  Future<void> _clear(BuildContext context, WidgetRef ref, String id) async {
    await ref.read(challengeRepositoryProvider).clearQuestReminder(id);
    ref.invalidate(questRemindersProvider);
    ref.invalidate(questReminderProvider(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final quests = ref.watch(myChallengesProvider).valueOrNull ?? const [];
    final reminders = ref.watch(questRemindersProvider).valueOrNull ?? const {};

    // Nothing to remind about in a lobby, and nothing a spectator could
    // act on.
    final open = quests.where((q) => !q.isLobby && !q.amIOut).toList();
    if (open.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 30, top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REMINDERS',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'A daily nudge per quest. Silent on days you already logged.',
            style: textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          for (final quest in open)
            Builder(builder: (context) {
              final at = reminders[quest.id];
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      quest.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  if (at != null)
                    IconButton(
                      tooltip: 'Turn off',
                      onPressed: () => _clear(context, ref, quest.id),
                      visualDensity: VisualDensity.compact,
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                      icon: Icon(Icons.close,
                          size: 16, color: AppColors.textSecondary),
                    ),
                  TextButton(
                    onPressed: () => _edit(context, ref, quest, at),
                    child: Text(
                      at == null ? 'SET' : _label(at.hour, at.minute),
                      style: TextStyle(
                        color: at == null
                            ? AppColors.textSecondary
                            : AppColors.neonPink,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String hint;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.bodyLarge),
                Text(hint,
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
