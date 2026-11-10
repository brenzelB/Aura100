import 'dart:async';
import '../../../../core/text/server_message.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/text/durations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../../../core/widgets/app_states.dart';
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

  Future<void> _start() =>
      startClockWithFeedback(context, ref, widget.challenge);

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final session =
        ref.watch(openClockSessionProvider(challenge.id)).valueOrNull;
    final busy = ref.watch(clockControllerProvider(challenge.id)).isLoading;
    _syncTicker(session != null);

    if (session == null) {
      // A rest day takes no entries, so a clock started now could not
      // be banked today. Say so instead of offering the button.
      final rests = !challenge.runsToday;
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: busy || challenge.amIOut || rests ? null : _start,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(rests ? 'RESTS TODAY' : 'START THE CLOCK'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            if (rests) ...[
              const SizedBox(height: 6),
              Text(
                clockRestDayHint(challenge),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
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
                ? 'Running for over a day. Stop it now, then correct the '
                    'entry in the history if it ran too long.'
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

  /// A corrected START. Null means "leave the clock's own start alone".
  ///
  /// This is what makes a forgotten START enterable at all: begin the
  /// clock now, stop it, then say it really ran from yesterday 20:00.
  /// A clock quest has no keypad, so without this that fast is lost.
  TimeOfDay? _startsAt;

  /// How many days back [_startsAt] sits. A fast crossing midnight
  /// started yesterday, and a long one the day before.
  int _startDaysAgo = 0;

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

  /// The chosen start as a real instant, or the clock's own.
  DateTime _resolveStart(DateTime now, ClockSession session) {
    final picked = _startsAt;
    if (picked == null) return session.startedAt.toLocal();
    final today =
        DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    return today.subtract(Duration(days: _startDaysAgo));
  }

  Future<void> _pickStart(ClockSession session) async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _startsAt ?? TimeOfDay.fromDateTime(session.startedAt.toLocal()),
      helpText: 'WHEN DID IT ACTUALLY START?',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startsAt = picked;
      _error = null;
      // A time later in the day than the end cannot be today, so the
      // obvious reading is yesterday. The live duration above shows
      // the result either way, and the day chips can override it.
      final end = _resolveEnd(now);
      final asToday =
          DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      _startDaysAgo = asToday.isBefore(end) ? 0 : 1;
    });
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
    final start = _resolveStart(now, session);
    if (!end.isAfter(start)) {
      setState(() => _error = 'The end has to come after the start.');
      return;
    }
    if (end.isAfter(now.add(const Duration(seconds: 5))) ||
        start.isAfter(now)) {
      setState(() => _error = 'That is still in the future.');
      return;
    }
    // A run is filed on the day it ended, and only the running day
    // takes entries. Saying so here beats a refusal from the server
    // that talks about "an earlier day" at half past midnight.
    final reset = clockDayStart(now);
    if (end.isBefore(reset)) {
      setState(() => _error = 'The end has to be after '
          '${TimeOfDay.fromDateTime(reset).format(context)} today, when the '
          'quest day began. Stop the clock now, then correct the entry in '
          'the history.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final owner = ref.read(currentUserProvider)?.id;
    if (owner == null) return;

    final result =
        await ref.read(clockControllerProvider(challenge.id).notifier).stop(
              endedAt: _endsAt == null ? null : end,
              startedAt: _startsAt == null ? null : start,
            );
    if (!mounted || ref.read(currentUserProvider)?.id != owner) return;

    if (result == null) {
      final error = ref.read(clockControllerProvider(challenge.id)).error;
      setState(() => _error = serverMessage(error,
          'Could not stop the clock. Check your connection and try again.'));
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

  Future<void> _discard(ClockSession session) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final elapsed = session.elapsed(DateTime.now());
    // Seconds on the clock are a mis-tap; hours are somebody's fast.
    if (elapsed.inMinutes >= 1) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AppDialog(
          backgroundColor: AppColors.surface,
          title: const Text('DISCARD THIS RUN?'),
          content: Text(
            '${formatStopwatch(elapsed)} on the clock will be thrown away. '
            'Nothing is logged and this cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('KEEP IT',
                  style: TextStyle(color: AppColors.accentText)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('DISCARD', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final dropped = await ref
        .read(clockControllerProvider(challenge.id).notifier)
        .discard();
    if (!mounted) return;
    if (!dropped) {
      final error = ref.read(clockControllerProvider(challenge.id)).error;
      setState(() => _error = serverMessage(error,
          'Could not discard the clock. Check your connection and try again.'));
      return;
    }
    navigator.pop();
    showActionFeedback(messenger, message: 'Clock discarded. Nothing logged.');
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
    final started = _resolveStart(now, session);
    final span = end.difference(started);
    final valid = span.inSeconds > 0 && !started.isAfter(now);

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
                value: _startDayLabel(started, now,
                    TimeOfDay.fromDateTime(started).format(context)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_startsAt != null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                  _startsAt = null;
                                  _startDaysAgo = 0;
                                  _error = null;
                                }),
                        child: Text('RESET',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    TextButton(
                      onPressed: busy ? null : () => _pickStart(session),
                      child: Text('CHANGE',
                          style: TextStyle(color: AppColors.accentText)),
                    ),
                  ],
                ),
              ),
              // Which day the start sits on. Only worth asking once a
              // start has been named - a fast across midnight began
              // yesterday, and the duration above proves it.
              if (_startsAt != null) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final day in const [
                      (0, 'TODAY'),
                      (1, 'YESTERDAY'),
                      (2, '2 DAYS AGO'),
                    ])
                      ChoiceChip(
                        label: Text(day.$2),
                        selected: _startDaysAgo == day.$1,
                        onSelected: busy
                            ? null
                            : (_) => setState(() {
                                  _startDaysAgo = day.$1;
                                  _error = null;
                                }),
                      ),
                  ],
                ),
              ],
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
                'Forgot to start or to stop? Set the real times here.',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              if (!challenge.runsToday) ...[
                const SizedBox(height: 12),
                Text(
                  'This quest rests today, so nothing can be banked right '
                  'now. ${clockRestDayHint(challenge)}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.warningText),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: busy || !valid || !challenge.runsToday
                    ? null
                    : () => _stop(session),
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
                onPressed: busy ? null : () => _discard(session),
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

/// Starts the clock and tells the player how it went.
///
/// Every START in the app goes through here, so a refused start is
/// never silent and a successful one is never invisible - which is
/// what a button that only changes a row in a database would be.
Future<void> startClockWithFeedback(
  BuildContext context,
  WidgetRef ref,
  Challenge challenge,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final owner = ref.read(currentUserProvider)?.id;
  if (owner == null) return;
  if (!challenge.runsToday) {
    showActionFeedback(messenger,
        error: true, message: clockRestDayHint(challenge));
    return;
  }
  final session =
      await ref.read(clockControllerProvider(challenge.id).notifier).start();
  if (ref.read(currentUserProvider)?.id != owner) return;
  if (session == null) {
    final error = ref.read(clockControllerProvider(challenge.id)).error;
    showActionFeedback(messenger,
        error: true,
        message: serverMessage(error,
            'Could not start the clock. Check your connection and try again.'));
    return;
  }
  showActionFeedback(messenger, message: 'Clock started · ${challenge.title}');
}

/// The local instant the current quest day began. Quest days are
/// shared by everyone in a quest and turn over at the same moment
/// worldwide; this is that moment on this device's clock.
DateTime clockDayStart(DateTime now) {
  final utc = now.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day).toLocal();
}

/// "This quest rests today. It runs again on Mon."
String clockRestDayHint(Challenge challenge) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final today = DateTime.now().toUtc();
  for (var i = 1; i <= 7; i++) {
    final day = today.add(Duration(days: i));
    if (challenge.runsOn(day)) {
      return 'This quest rests today. It runs again on '
          '${names[day.weekday - 1]}.';
    }
  }
  return 'This quest rests today.';
}

/// START / running time for a CLOCK quest in one button-sized control.
///
/// Used wherever a progress quest would show "+ ADD": the quest card,
/// the Home agenda and the done list. While the clock runs it shows the
/// live time, so a running clock is visible from every list it sits in.
class ClockQuickButton extends ConsumerStatefulWidget {
  const ClockQuickButton(
      {super.key, required this.challenge, this.expand = false});

  final Challenge challenge;

  /// Fill the available width (the featured card on Home).
  final bool expand;

  @override
  ConsumerState<ClockQuickButton> createState() => _ClockQuickButtonState();
}

class _ClockQuickButtonState extends ConsumerState<ClockQuickButton> {
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final sessionAsync = ref.watch(openClockSessionProvider(challenge.id));
    final session = sessionAsync.valueOrNull;
    final busy = ref.watch(clockControllerProvider(challenge.id)).isLoading;
    _syncTicker(session != null);
    final minimum = Size(widget.expand ? double.infinity : 0, 48);
    const textStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);

    if (session != null) {
      return ElevatedButton.icon(
        key: const ValueKey('clock-quick-running'),
        onPressed:
            busy ? null : () => showClockStopSheet(context, ref, challenge),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonGreen,
          foregroundColor: Colors.black,
          minimumSize: minimum,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: textStyle
              .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        icon: const Icon(Icons.stop_rounded, size: 18),
        label: Text(formatStopwatch(session.elapsed(DateTime.now()))),
      );
    }

    final rests = !challenge.runsToday;
    // Until the first answer arrives it is unknown whether a clock is
    // already running, and a second START would only be refused.
    final unknown = sessionAsync.isLoading && !sessionAsync.hasValue;
    return ElevatedButton.icon(
      key: const ValueKey('clock-quick-start'),
      onPressed: busy || unknown || rests || challenge.amIOut
          ? null
          : () => startClockWithFeedback(context, ref, challenge),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.neonPurple,
        foregroundColor: Colors.white,
        minimumSize: minimum,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: textStyle,
      ),
      icon: const Icon(Icons.play_arrow_rounded, size: 18),
      label: Text(rests ? 'RESTS TODAY' : 'START'),
    );
  }
}

/// "20:00" today, "yesterday 20:00" before that. A bare time on a row
/// labelled STARTED would read as today and quietly hide 18 hours.
String _startDayLabel(DateTime started, DateTime now, String time) {
  final startDay = DateTime(started.year, started.month, started.day);
  final today = DateTime(now.year, now.month, now.day);
  final back = today.difference(startDay).inDays;
  return switch (back) {
    <= 0 => time,
    1 => 'yesterday $time',
    _ => '$back days ago, $time',
  };
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
