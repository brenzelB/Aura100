import 'challenge.dart';

/// Pure timeline/statistics logic for the challenge detail view.
/// No Flutter, no Supabase — fully unit-testable. `today` is always
/// injected so tests are deterministic.

enum DayStatus {
  /// Checked in on this day.
  done,

  /// Day is in the past (and after joining) but required a check-in
  /// that didn't happen. Only used for DAILY quests — for weekly and
  /// monthly quests, misses exist at the period level, not per day.
  missed,

  /// The current day, check-in still pending.
  today,

  /// Day hasn't arrived yet.
  future,

  /// Day was before the user joined the quest — doesn't count.
  notJoined,

  /// Past day without a check-in in a weekly/monthly quest — perfectly
  /// fine, the target is per period.
  rest,
}

class TimelineDay {
  const TimelineDay({
    required this.date,
    required this.status,
    required this.isToday,
    this.checkedAt,
  });

  final DateTime date;
  final DayStatus status;

  /// True for the current day even when already checked in (the grid
  /// highlights it with a border on top of the done color).
  final bool isToday;

  /// When the check-in happened (for the day-details sheet).
  final DateTime? checkedAt;
}

class ChallengeStats {
  const ChallengeStats({
    required this.doneCount,
    required this.missedCount,
    required this.accountableCount,
    required this.longestStreak,
    required this.currentStreak,
    required this.unit,
  });

  /// Fulfilled units: days (daily) or periods (weekly/monthly).
  final int doneCount;

  /// Units that failed their target.
  final int missedCount;

  /// Units counting toward the success rate: every resolved unit,
  /// plus the current one once it's fulfilled.
  final int accountableCount;

  final int longestStreak;

  /// Streak of consecutive fulfilled units ending now.
  final int currentStreak;

  /// 'days' / 'weeks' / 'months' — for the stat tile captions.
  final String unit;

  /// 0..1, or null before any unit is accountable.
  double? get successRate =>
      accountableCount == 0 ? null : doneCount / accountableCount;
}

class ChallengeTimeline {
  const ChallengeTimeline({required this.days, required this.stats});

  final List<TimelineDay> days;
  final ChallengeStats stats;

  /// Builds the day-by-day timeline of [challenge] from the user's
  /// check-ins ([checkIns] maps UTC date → check-in timestamp).
  ///
  /// Stats are per-day for daily quests and per-period (7/30-day
  /// blocks anchored to the start date — mirroring the server's
  /// log_check_in logic) for weekly/monthly quests.
  static ChallengeTimeline build({
    required Challenge challenge,
    required Map<DateTime, DateTime> checkIns,
    required DateTime today, // UTC date (midnight)
  }) {
    final start = _dateOnly(challenge.startsOn);
    final joined = _dateOnly(challenge.joinedOn ?? challenge.startsOn);
    final activeFrom = joined.isAfter(start) ? joined : start;
    final todayDate = _dateOnly(today);
    final daily = challenge.checkinPeriod == CheckinPeriod.daily;
    // Endless quests show the most recent year, aligned to the original
    // period boundaries so weekly/monthly statistics remain comparable.
    final periodLen = challenge.checkinPeriod.lengthDays;
    final elapsed = todayDate.difference(start).inDays;
    final windowOffset = challenge.isEndless && elapsed > 364
        ? ((elapsed - 364 + periodLen - 1) ~/ periodLen) * periodLen
        : 0;
    final windowStart = start.add(Duration(days: windowOffset));
    final endExclusive = challenge.isEndless
        ? (todayDate.isBefore(start) ? start : todayDate)
            .add(const Duration(days: 1))
        : start.add(Duration(days: challenge.durationDays));

    // ── Day-by-day grid ─────────────────────────────────────────
    final days = <TimelineDay>[];
    for (var date = windowStart;
        date.isBefore(endExclusive);
        date = date.add(const Duration(days: 1))) {
      final checkedAt = checkIns[date];
      final isToday = date == todayDate;

      final DayStatus status;
      if (checkedAt != null) {
        status = DayStatus.done;
      } else if (!challenge.runsOn(date)) {
        // A weekday the creator switched off. Never a miss, whether it
        // is behind us or still ahead — the quest simply rests.
        status = DayStatus.rest;
      } else if (date.isAfter(todayDate)) {
        status = DayStatus.future;
      } else if (date.isBefore(activeFrom)) {
        status = DayStatus.notJoined;
      } else if (isToday) {
        status = DayStatus.today;
      } else {
        status = daily ? DayStatus.missed : DayStatus.rest;
      }

      days.add(TimelineDay(
        date: date,
        status: status,
        isToday: isToday,
        checkedAt: checkedAt,
      ));
    }

    // ── Stats: units are days (daily) or periods (weekly/monthly) ──
    // One unified pass over anchored periods; for daily quests the
    // period length is 1, which reproduces the per-day semantics.
    final target = daily ? 1 : challenge.checkinsPerPeriod;

    var done = 0;
    var missed = 0;
    var accountable = 0;
    // true = fulfilled, false = failed; resolved units in order.
    final resolved = <bool>[];

    var pStart = windowStart;
    while (pStart.isBefore(endExclusive)) {
      final naturalEnd = pStart.add(Duration(days: periodLen));
      final pEnd =
          challenge.isEndless ? naturalEnd : _min(naturalEnd, endExclusive);

      // Skip periods from before the user joined (fair for late joiners).
      if (pStart.isBefore(activeFrom)) {
        pStart = pEnd;
        continue;
      }

      // How many days of this period does the quest actually run on?
      // None → the period never counted; it is not a miss and not an
      // accountable unit. Mirrors settle_periods exactly.
      var activeDays = 0;
      for (var d = pStart;
          d.isBefore(pEnd);
          d = d.add(const Duration(days: 1))) {
        if (challenge.runsOn(d)) activeDays++;
      }
      if (activeDays == 0) {
        pStart = pEnd;
        continue;
      }

      final doneInPeriod = checkIns.keys
          .where((d) => !d.isBefore(pStart) && d.isBefore(pEnd))
          .length;
      // The bar cannot ask for more check-ins than there are days to
      // give — the server caps the same way.
      final fulfilled =
          doneInPeriod >= (target < activeDays ? target : activeDays);
      final completed = !pEnd.isAfter(todayDate);

      if (completed) {
        accountable++;
        if (fulfilled) {
          done++;
          resolved.add(true);
        } else {
          missed++;
          resolved.add(false);
        }
      } else if (!pStart.isAfter(todayDate) && fulfilled) {
        // Current period, target already reached → counts as done.
        accountable++;
        done++;
        resolved.add(true);
      }
      // Current-but-unfulfilled and future periods stay pending.

      pStart = pEnd;
    }

    return ChallengeTimeline(
      days: days,
      stats: ChallengeStats(
        doneCount: done,
        missedCount: missed,
        accountableCount: accountable,
        longestStreak: _longestRun(resolved),
        currentStreak: _tailRun(resolved),
        unit: challenge.checkinPeriod.unitLabel,
      ),
    );
  }

  static int _longestRun(List<bool> resolved) {
    var longest = 0;
    var run = 0;
    for (final ok in resolved) {
      run = ok ? run + 1 : 0;
      if (run > longest) longest = run;
    }
    return longest;
  }

  static int _tailRun(List<bool> resolved) {
    var streak = 0;
    for (final ok in resolved.reversed) {
      if (!ok) break;
      streak++;
    }
    return streak;
  }

  static DateTime _min(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  static DateTime _dateOnly(DateTime dt) =>
      DateTime.utc(dt.year, dt.month, dt.day);
}
