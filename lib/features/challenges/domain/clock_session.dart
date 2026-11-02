/// One stretch of tracked time on a CLOCK quest.
///
/// The clock itself never runs in the app. Only [startedAt] is stored,
/// and the interface renders `now - startedAt`. That is what lets a
/// fast survive an app restart, flight mode, a dead battery and a new
/// phone — none of which a client-side stopwatch would.
class ClockSession {
  const ClockSession({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    this.entryId,
  });

  final String id;
  final String challengeId;
  final String userId;
  final DateTime startedAt;

  /// Null while the clock is still running.
  final DateTime? endedAt;

  /// The progress entry this session became on stopping. Null while
  /// running, and null again if that entry was later deleted from the
  /// history — the session still happened either way.
  final String? entryId;

  bool get isRunning => endedAt == null;

  /// How long this session has run. [now] is only consulted while the
  /// clock is still going.
  Duration elapsed(DateTime now) =>
      (endedAt ?? now).toUtc().difference(startedAt.toUtc());

  double minutesAt(DateTime now) => elapsed(now).inSeconds / 60.0;

  factory ClockSession.fromJson(Map<String, dynamic> json) => ClockSession(
        id: json['id'] as String,
        challengeId: json['challenge_id'] as String,
        userId: json['user_id'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: json['ended_at'] == null
            ? null
            : DateTime.parse(json['ended_at'] as String),
        entryId: json['entry_id'] as String?,
      );
}

/// What the server reports back after stopping the clock: the progress
/// result plus the span that produced it.
class ClockStopResult {
  const ClockStopResult({
    required this.minutes,
    required this.total,
    required this.target,
    required this.completed,
    required this.overshoot,
    this.gained,
  });

  /// The length of the session just closed.
  final double minutes;

  /// The period's total after this session, and the goal it counts to.
  final double total;
  final double target;

  final bool completed;
  final bool overshoot;

  /// Aura paid out, only on the session that first crosses the goal.
  final int? gained;

  factory ClockStopResult.fromJson(Map<String, dynamic> json) =>
      ClockStopResult(
        minutes: (json['minutes'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        target: (json['target'] as num).toDouble(),
        completed: json['completed'] as bool,
        overshoot: (json['overshoot'] ?? false) as bool,
        gained: (json['gained'] as num?)?.toInt(),
      );
}
