import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/feedback/feedback_settings.dart';
import '../../../../core/feedback/interaction_feedback.dart';
import '../../../../core/theme/app_colors.dart';

class FeedbackSettingsSection extends ConsumerStatefulWidget {
  const FeedbackSettingsSection({super.key});

  @override
  ConsumerState<FeedbackSettingsSection> createState() =>
      _FeedbackSettingsSectionState();
}

class _FeedbackSettingsSectionState
    extends ConsumerState<FeedbackSettingsSection> {
  bool _saving = false;

  Future<void> _save(Future<void> Function() save) async {
    setState(() => _saving = true);
    try {
      await save();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save feedback settings. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(feedbackSettingsProvider);
    final settings = preferences.valueOrNull;
    final controller = ref.read(feedbackSettingsProvider.notifier);
    final enabled = settings != null && !_saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SOUND & FEEL',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: AppColors.accentText)),
        const SizedBox(height: 6),
        Text('Checked off. Well earned. Saved on this device.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.volume_down_outlined),
          title: const Text('Subtle sounds'),
          subtitle: const Text(
              'Check-ins, progress and milestones. Respects silent mode.'),
          value: settings?.sounds ?? false,
          onChanged: enabled
              ? (value) => _save(() => controller.setSounds(value))
              : null,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.vibration_outlined),
          title: const Text('Haptic feedback'),
          subtitle:
              const Text('A firm, short tap when an action is confirmed.'),
          value: settings?.haptics ?? false,
          onChanged: enabled
              ? (value) => _save(() => controller.setHaptics(value))
              : null,
        ),
        if (preferences.hasError)
          TextButton(
            onPressed: () => ref.invalidate(feedbackSettingsProvider),
            child: const Text('Retry loading settings'),
          )
        else
          OutlinedButton.icon(
            onPressed: enabled && (settings.sounds || settings.haptics)
                ? () => ref
                    .read(interactionFeedbackProvider)
                    .play(FeedbackCue.checkIn)
                : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('TRY FEEDBACK'),
          ),
      ],
    );
  }
}
