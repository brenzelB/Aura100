import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../challenges/application/challenge_providers.dart';
import '../../../challenges/domain/aura_heist.dart';

/// Shows the "you got robbed" reveal for one landed heist, then marks it
/// seen so it won't return.
Future<void> showRobbedNoticeDialog(
    BuildContext context, WidgetRef ref, RobbedNotice notice) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RobbedNoticeDialog(notice: notice),
  );
  await ref
      .read(challengeRepositoryProvider)
      .acknowledgeRobbedNotice(notice.id);
  ref.invalidate(robbedNoticesProvider);
}

/// Called right after a check-in: if a heist just took this quest's
/// payout, reveal it and return the notice (so the caller skips its own
/// "+aura" toast). Returns null when nothing was stolen.
Future<RobbedNotice?> revealRobbedIfAny(
    BuildContext context, WidgetRef ref, String challengeId) async {
  List<RobbedNotice> notices;
  try {
    notices = await ref.refresh(robbedNoticesProvider.future);
  } catch (_) {
    return null;
  }
  final notice =
      notices.where((n) => n.challengeId == challengeId).firstOrNull;
  if (notice == null || !context.mounted) return null;
  await showRobbedNoticeDialog(context, ref, notice);
  return notice;
}

/// Home banner listing any landed heists the user hasn't seen yet — a
/// safety net for notices they missed at check-in time.
class RobbedAlertSection extends ConsumerWidget {
  const RobbedAlertSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(robbedNoticesProvider).valueOrNull ?? [];
    if (notices.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final notice in notices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => showRobbedNoticeDialog(context, ref, notice),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppColors.panelDecoration(
                    accent: AppColors.danger, glow: true),
                child: Row(
                  children: [
                    const Text('💸', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AURA ROBBED!',
                              style: textTheme.headlineSmall
                                  ?.copyWith(color: AppColors.danger)),
                          const SizedBox(height: 4),
                          Text(
                            '@${notice.attackerUsername} lifted '
                            '⚡${notice.stolenAmount} from your check-in — '
                            'tap for the bad news.',
                            style: textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 20, color: AppColors.danger),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _RobbedNoticeDialog extends StatefulWidget {
  const _RobbedNoticeDialog({required this.notice});

  final RobbedNotice notice;

  @override
  State<_RobbedNoticeDialog> createState() => _RobbedNoticeDialogState();
}

class _RobbedNoticeDialogState extends State<_RobbedNoticeDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppDurations.base,
  );
  bool _kicked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_kicked) return;
    _kicked = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final curved = CurvedAnimation(parent: _c, curve: AppCurves.emphasizedOut);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.danger, width: 2.5),
        ),
        content: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.0).animate(curved),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💸', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text('YOU GOT ROBBED!',
                    style: textTheme.headlineSmall?.copyWith(
                        color: AppColors.danger, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: Text('−⚡${widget.notice.stolenAmount}',
                      style: textTheme.displaySmall?.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 12),
                Text(
                  '@${widget.notice.attackerUsername} pulled an Aura Heist. '
                  'Your check-in still counts — but the aura went to them.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textPrimary, height: 1.3),
                ),
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: AppColors.background,
                minimumSize: const Size(0, 46),
              ),
              child: const Text('RATS.'),
            ),
          ),
        ],
      ),
    );
  }
}
