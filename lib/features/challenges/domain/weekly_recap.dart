/// What the last full week looked like — the numbers a player would
/// tell a friend about, and nothing else.
///
/// Deliberately built from data the app already keeps (check-ins,
/// progress entries, settlement events, duels). It adds no rule, no
/// setting and no decision: it only says out loud what already happened.
class WeeklyRecap {
  const WeeklyRecap({
    required this.weekStart,
    required this.weekEnd,
    required this.checkIns,
    required this.activeDays,
    required this.auraGained,
    required this.auraLost,
    required this.strikes,
    required this.questsFinished,
    required this.duelsWon,
    required this.duelsLost,
    required this.previousCheckIns,
    this.bestDay,
    this.bestDayCount = 0,
  });

  /// Monday of the week being reported (UTC date, midnight).
  final DateTime weekStart;

  /// Sunday of that week (inclusive, UTC date).
  final DateTime weekEnd;

  /// Everything the player logged: check-ins plus progress entries.
  final int checkIns;

  /// Days they showed up at all (0–7) — the honest habit number.
  final int activeDays;

  final int auraGained;

  /// Positive number; what penalties and heists took.
  final int auraLost;

  final int strikes;
  final int questsFinished;
  final int duelsWon;
  final int duelsLost;

  /// The same figure for the week before, so the card can say whether
  /// things went up or down without the player doing the arithmetic.
  final int previousCheckIns;

  /// The single busiest day of the week, if there was any activity.
  final DateTime? bestDay;
  final int bestDayCount;

  int get auraNet => auraGained - auraLost;

  /// Difference to the week before. Positive = a better week.
  int get checkInDelta => checkIns - previousCheckIns;

  /// Nothing happened at all — the card stays away rather than
  /// congratulating someone on a week of zeroes.
  bool get isEmpty => checkIns == 0 && auraLost == 0 && strikes == 0;

  /// A stable key for "this recap has been seen", so it appears once and
  /// then leaves the player alone until the next Monday.
  String get storageKey =>
      'recap_seen_${weekStart.toIso8601String().split('T').first}';
}
