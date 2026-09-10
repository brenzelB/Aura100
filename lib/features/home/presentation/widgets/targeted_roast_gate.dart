import 'package:aura_quest/core/widgets/app_states.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/realtime/realtime_sync.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../challenges/application/challenge_providers.dart';
import '../../../challenges/domain/targeted_roast.dart';
import '../../../friends/application/friends_providers.dart';

/// Shows the countdown lock for one roast, then acknowledges it on the
/// server so it never comes back. The lock is deliberately NOT global:
/// it fires when the victim touches the roasted quest (check-in or
/// detail page), not the moment the roast lands.
Future<void> showTargetedRoastLockDialog(
    BuildContext context, WidgetRef ref, TargetedRoast roast) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => TargetedRoastLockDialog(roast: roast),
  );

  await ref
      .read(challengeRepositoryProvider)
      .acknowledgeTargetedRoast(roast.id);

  ref.invalidate(targetedRoastsProvider);
}

/// Invisible poller that keeps [targetedRoastsProvider] fresh while Home
/// is on screen, so the "you got roasted" banner appears without a
/// manual refresh. Renders nothing.
class TargetedRoastRefresher extends ConsumerStatefulWidget {
  const TargetedRoastRefresher({super.key});

  @override
  ConsumerState<TargetedRoastRefresher> createState() =>
      _TargetedRoastRefresherState();
}

class _TargetedRoastRefresherState extends ConsumerState<TargetedRoastRefresher>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  /// Safety net only — RealtimeSync pushes these the moment they happen.
  /// A timer this slow costs almost nothing but still recovers if the
  /// socket is down or the app missed events while asleep.
  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(RealtimeSync.fallbackInterval, (_) {
      if (!mounted) return;
      // Hidden tab (the shell is an IndexedStack): stay quiet.
      if (!TickerMode.valuesOf(context).enabled) return;
      ref.invalidate(targetedRoastsProvider);
      ref.invalidate(unseenNudgesProvider);
      ref.invalidate(pokeBacksProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A backgrounded app used to keep polling all day. Now it goes quiet
    // and catches up once on the way back.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(targetedRoastsProvider);
      ref.invalidate(unseenNudgesProvider);
      ref.invalidate(pokeBacksProvider);
      _start();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class TargetedRoastLockDialog extends StatefulWidget {
  const TargetedRoastLockDialog({super.key, required this.roast});

  final TargetedRoast roast;

  @override
  State<TargetedRoastLockDialog> createState() =>
      _TargetedRoastLockDialogState();
}

class _TargetedRoastLockDialogState extends State<TargetedRoastLockDialog> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.roast.durationSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        t.cancel();
        setState(() => _remainingSeconds = 0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isLocked = _remainingSeconds > 0;

    return PopScope(
      canPop: false,
      child: AppDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.neonPurple, width: 2.5),
        ),
        title: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 8),
                Text(
                  'ROAST ATTACK!',
                  style: textTheme.headlineSmall?.copyWith(
                    color: AppColors.neonPurple,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('🔥', style: TextStyle(fontSize: 28)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'From @${widget.roast.senderUsername}',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppColors.panelDecoration(
                accent: AppColors.neonPurple,
                fill: AppColors.neonPurple.withValues(alpha: 0.12),
                radius: 12,
              ),
              child: Text(
                '"${widget.roast.roastText}"',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isLocked)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.neonPurple,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Screen locked for $_remainingSeconds seconds…',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            else
              Text(
                'Screen unlocked! You may dismiss.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.successText,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLocked ? null : () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonPurple,
                foregroundColor:
                    AppColors.isDark ? AppColors.background : Colors.white,
                disabledBackgroundColor:
                    AppColors.textSecondary.withValues(alpha: 0.2),
                disabledForegroundColor:
                    AppColors.textSecondary.withValues(alpha: 0.6),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isLocked ? AppColors.outline : AppColors.neonPurple,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                isLocked
                    ? '🔒 LOCKED (${_remainingSeconds}S)'
                    : 'OUCH, THAT HURT! (DISMISS)',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
