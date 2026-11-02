import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/text/durations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import '../../domain/clock_session.dart';
import '../quest_amount.dart';

/// START / STOP for a CLOCK quest, inline on the card and on Home.
///
/// The readout is computed from the session's start instant on every
/// tick, never accumulated locally. A dropped frame, a backgrounded
/// app or a phone asleep for nine hours therefore cost nothing: the
/// next frame shows the truth again.
class ClockControls extends ConsumerStatefulWidget {
  const ClockControls(
      {super.key, required this.challenge, this.compact = false});

  final Challenge challenge;
  final bool compact;

  @override
  ConsumerState<ClockControls> createState() => _ClockControlsState();
}

class _ClockControlsState extends ConsumerState<ClockControls> {
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// One ticker, alive only while a clock is actually running. A card
  /// with a stopped clock must not wake the device once a second.
  void _syncTicker(bool running) {
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  Future<void> _start() async {
    final messenger = ScaffoldMessenger.of(context);
    final owner = ref.read(currentUserProvider)?.id;
    if (owner == null) return;
    final session = await ref
        .read(clockControllerProvider(widget.challenge.id).notifier)
        .start();
    if (!mounted || ref.read(currentUserProvider)?.id != owner) return;
    if (session == null) {
      final error =
          ref.read(clockControllerProvider(widget.challenge.id)).error;
      showActionFeedback(messenger,
          error: true,
          message: error is PostgrestException
              ? error.message
              : 'Could not start the clock. Check your connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final session =
        ref.watch(openClockSessionProvider(challenge.id)).valueOrNull;
    final busy = ref.watch(clockControllerProvider(challenge.id)).isLoading;
    _syncTicker(session != null);

    if (session == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ElevatedButton.icon(
          onPressed: busy || challenge.amIOut ? null : _start,
          icon: const Icon(Icons.play_arrow_rounded, size: 20),
          label: const Text('START THE CLOCK'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.neonPurple,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _RunningPanel(
        challenge: challenge,
        session: session,
        busy: busy,
        compact: widget.compact,
      ),
    );
  }
}

class _RunningPanel extends ConsumerWidget {
  const _RunningPanel({
    required this.challenge,
    required this.session,
    required this.busy,
    required this.compact,
  });

  final Challenge challenge;
  final ClockSession session;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final elapsed = session.elapsed(DateTime.now());
    // Past a day the clock has almost certainly been forgotten rather
    // than earned, so the panel says so instead of quietly counting on.
    final suspicious = elapsed.inHours >= 24;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppColors.panelDecoration(
          accent: suspicious ? AppColors.danger : AppColors.neonGreen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined,
                  size: 16,
                  color: suspicious ? AppColors.danger : AppColors.successText),
              const SizedBox(width: 6),
              Text(
                'CLOCK RUNNING',
                style: textTheme.labelMedium?.copyWith(
                  color: suspicious ? AppColors.danger : AppColors.successText,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatStopwatch(elapsed),
              style:
                  (compact ? textTheme.headlineSmall : textTheme.displaySmall)
                      ?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            suspicious
                ? 'Running for over a day. If you already stopped, correct '
                    'the time when you bank it.'
                : 'Started ${TimeOfDay.fromDateTime(session.startedAt.toLocal()).format(context)}',
            style: textTheme.bodySmall?.copyWith(
                color: suspicious ? AppColors.danger : AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy
                      ? null
                      : () => showClockStopSheet(context, ref, challenge),
                  icon: const Icon(Icons.stop_rounded, size: 20),
                  label: const Text('STOP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonGreen,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Banks a running clock — or throws it away.
///
/// The end time is adjustable because forgetting to stop is the normal
/// failure of this kind of tracking, not an edge case. You break the
/// fast at 13:00 and remember at 22:00; without this the entry is a
/// lie and the leaderboard is nonsense.
Future<void> showClockStopSheet(
  BuildContext context,
  WidgetRef ref,
  Challenge challenge,
) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: AppShapes.sheet,
      builder: (_) => _ClockStopSheet(challenge: challenge),
    );

class _ClockStopSheet extends ConsumerStatefulWidget {
  const _ClockStopSheet({required this.challenge});

  final Challenge challenge;

  @override
  ConsumerState<_ClockStopSheet> createState() => _ClockStopSheetState();
}

class _ClockStopSheetState extends ConsumerState<_ClockStopSheet> {
  /// Null means "now" — and keeps meaning now as the seconds pass,
  /// which a timestamp captured on open would not.
  TimeOfDay? _endsAt;
  String? _error;
  Timer? _tick;

  Challenge get challenge => widget.challenge;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _endsAt == null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// The chosen end as a real instant, resolved against today.
  DateTime _resolveEnd(DateTime now) {
    final picked = _endsAt;
    if (picked == null) return now;
    return DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endsAt ?? TimeOfDay.now(),
      helpText: 'WHEN DID YOU ACTUALLY STOP?',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _endsAt = picked;
      _error = null;
    });
  }

  Future<void> _stop(ClockSession session) async {
    final now = DateTime.now();
    final end = _resolveEnd(now);
    if (!end.isAfter(session.startedAt.toLocal())) {
      setState(() => _error = 'That is before the clock even started.');
      return;
    }
    if (end.isAfter(now.add(const Duration(seconds: 5)))) {
      setState(() => _error = 'That is still in the future.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final owner = ref.read(currentUserProvider)?.id;
    if (owner == null) return;

    final result = await ref
        .read(clockControllerProvider(challenge.id).notifier)
        .stop(endedAt: _endsAt == null ? null : end);
    if (!mounted || ref.read(currentUserProvider)?.id != owner) return;

    if (result == null) {
      final error = ref.read(clockControllerProvider(challenge.id)).error;
      setState(() => _error = error is PostgrestException
          ? error.message
          : 'Could not stop the clock. Check your connection and try again.');
      return;
    }

    navigator.pop();
    showActionFeedback(
      messenger,
      message: result.completed && !result.overshoot
          ? 'Goal reached · ${challenge.amountWithUnit(result.total)}'
          : '${challenge.addedLabel(result.minutes)} banked · '
              '${challenge.progressLabel(result.total, result.target)}',
      confirmedAura: result.gained,
    );
  }

  Future<void> _discard() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dropped = await ref
        .read(clockControllerProvider(challenge.id).notifier)
        .discard();
    if (!mounted) return;
    navigator.pop();
    if (dropped) {
      showActionFeedback(messenger,
          message: 'Clock discarded. Nothing logged.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final session =
        ref.watch(openClockSessionProvider(challenge.id)).valueOrNull;
    final busy = ref.watch(clockControllerProvider(challenge.id)).isLoading;

    if (session == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text('The clock is not running.'),
      );
    }

    final now = DateTime.now();
    final end = _resolveEnd(now);
    final started = session.startedAt.toLocal();
    final span = end.difference(started);
    final valid = span.inSeconds > 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BANK THIS SESSION',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.successText,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    valid ? formatStopwatch(span) : '--:--:--',
                    style: textTheme.displaySmall?.copyWith(
                      color: valid
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _Row(
                label: 'STARTED',
                value: TimeOfDay.fromDateTime(started).format(context),
              ),
              const SizedBox(height: 8),
              _Row(
                label: 'STOPPED',
                value: _endsAt == null
                    ? 'now'
                    : TimeOfDay.fromDateTime(end).format(context),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Correcting the time must stay reachable after it
                    // has been corrected once - and so must going back.
                    if (_endsAt != null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                  _endsAt = null;
                                  _error = null;
                                }),
                        child: Text('NOW',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    TextButton(
                      onPressed: busy ? null : _pickEnd,
                      child: Text('CHANGE',
                          style: TextStyle(color: AppColors.accentText)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Left it running? Set the time you actually stopped.',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: busy || !valid ? null : () => _stop(session),
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text('STOP & BANK'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonGreen,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: busy ? null : _discard,
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text('DISCARD — LOG NOTHING',
                    style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
