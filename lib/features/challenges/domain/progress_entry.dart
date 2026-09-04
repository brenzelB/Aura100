/// One logged step towards a progress quest's target — "+20" with the
/// moment it was logged. The history is built from these.
class ProgressEntry {
  const ProgressEntry({
    required this.id,
    required this.amount,
    required this.periodStart,
    required this.createdAt,
  });

  final String id;
  final double amount;

  /// Which period this counted towards (UTC midnight).
  final DateTime periodStart;
  final DateTime createdAt;

  factory ProgressEntry.fromJson(Map<String, dynamic> json) => ProgressEntry(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        periodStart: DateTime.parse('${json['period_start']}T00:00:00Z'),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// One period's worth of history: what was logged, and whether the
/// target was reached.
class ProgressPeriod {
  const ProgressPeriod({
    required this.periodStart,
    required this.entries,
    required this.total,
    required this.target,
  });

  final DateTime periodStart;

  /// Newest first — the order the history list shows.
  final List<ProgressEntry> entries;
  final double total;
  final double target;

  bool get reached => total >= target;

  double get ratio => target <= 0 ? 0 : (total / target).clamp(0.0, 1.0);

  int get percent => (ratio * 100).round();

  /// Groups raw entries into periods, newest period first.
  static List<ProgressPeriod> group(
    List<ProgressEntry> entries,
    double target,
  ) {
    final byPeriod = <DateTime, List<ProgressEntry>>{};
    for (final entry in entries) {
      (byPeriod[entry.periodStart] ??= []).add(entry);
    }

    final periods = byPeriod.entries.map((e) {
      final list = [...e.value]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ProgressPeriod(
        periodStart: e.key,
        entries: list,
        total: list.fold<double>(0, (sum, it) => sum + it.amount),
        target: target,
      );
    }).toList()
      ..sort((a, b) => b.periodStart.compareTo(a.periodStart));

    return periods;
  }
}

/// What the server reports back after logging progress.
class ProgressResult {
  const ProgressResult({
    required this.total,
    required this.target,
    required this.completed,
    required this.overshoot,
    required this.gained,
  });

  final double total;
  final double target;

  /// True when the period's target is met (this entry or an earlier one).
  final bool completed;

  /// True when this entry was logged AFTER the goal was already met —
  /// bonus reps, documented but not counted towards the goal.
  final bool overshoot;

  /// Aura paid out by the auto check-in — only on the entry that first
  /// crosses the target.
  final int? gained;

  factory ProgressResult.fromJson(Map<String, dynamic> json) => ProgressResult(
        total: (json['total'] as num).toDouble(),
        target: (json['target'] as num).toDouble(),
        completed: json['completed'] as bool,
        overshoot: (json['overshoot'] ?? false) as bool,
        gained: (json['gained'] as num?)?.toInt(),
      );
}

/// Cumulative reps across all periods — lifetime, this month, this week.
/// Built from every logged entry (overshoot included).
class ProgressTotals {
  const ProgressTotals({
    required this.lifetime,
    required this.thisMonth,
    required this.thisWeek,
  });

  final double lifetime;
  final double thisMonth;
  final double thisWeek;

  /// [now] is local time so "this week/month" match the player's calendar.
  static ProgressTotals from(List<ProgressEntry> entries, DateTime now) {
    // Monday-based week, calendar month — both at local midnight.
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    var life = 0.0, month = 0.0, week = 0.0;
    for (final e in entries) {
      final t = e.createdAt.toLocal();
      final day = DateTime(t.year, t.month, t.day);
      life += e.amount;
      if (!day.isBefore(monthStart)) month += e.amount;
      if (!day.isBefore(weekStart)) week += e.amount;
    }
    return ProgressTotals(lifetime: life, thisMonth: month, thisWeek: week);
  }
}
