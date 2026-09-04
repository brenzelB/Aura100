import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/text/dates.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../challenges/application/challenge_providers.dart';
import '../../../challenges/domain/blackout.dart';

/// Home banner for lockouts the player never saw.
///
/// The quest screen already announces a Blackout while it runs — but
/// only to someone who happens to open the app during those two hours.
/// Sleep through it and the quest screen has nothing left to say: the
/// window is closed, the button works again, and all that remains is an
/// unexplained hole in the day.
///
/// This is the catch-all. It lists every lockout that has started and
/// not been acknowledged, whether it is still running or long over, and
/// clears itself once the player taps it.
class BlackoutAlertSection extends ConsumerWidget {
  const BlackoutAlertSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(unseenBlackoutsProvider).valueOrNull ?? const [];
    if (notices.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;

    Future<void> dismiss(Blackout notice) async {
      await ref
          .read(challengeRepositoryProvider)
          .ackBlackouts(notice.challengeId);
      ref.invalidate(unseenBlackoutsProvider);
      ref.invalidate(myBlackoutProvider);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final notice in notices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration:
                  AppColors.panelDecoration(accent: AppColors.neonPurple),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🌑', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notice.isRunning
                              ? "YOU'RE BLACKED OUT"
                              : 'YOU WERE BLACKED OUT',
                          style: textTheme.headlineSmall?.copyWith(
                            color: AppColors.neonPurple,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _sentence(notice),
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Dismiss',
                    onPressed: () => dismiss(notice),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: Icon(Icons.close,
                        size: 18, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// One sentence that answers the only two questions the player has:
  /// who did it, and when was I locked out.
  static String _sentence(Blackout notice) {
    final who = notice.attackerName == null
        ? 'Someone'
        : '@${notice.attackerName}';
    final where = notice.challengeTitle == null
        ? 'one of your quests'
        : '"${notice.challengeTitle}"';
    final from = formatTime(notice.startsAt);
    final to = formatTime(notice.endsAt);

    if (notice.isRunning) {
      return '$who locked you out of $where until $to — '
          '${notice.remainingLabel} to go.';
    }
    return '$who locked you out of $where from $from to $to. '
        'Anything you tried to log in that window bounced.';
  }
}
