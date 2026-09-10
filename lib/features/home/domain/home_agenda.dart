import '../../challenges/domain/challenge.dart';

/// What the player has to do today, and what is about to go wrong.
/// Pure logic — no Flutter, no Supabase; `today` is injected so tests
/// are deterministic.

/// One running quest, seen through "what's left in the current period".
class AgendaItem {
  const AgendaItem({
    required this.challenge,
    required this.doneInPeriod,
    required this.target,
    required this.daysLeftInPeriod,
    required this.strikesUsed,
    required this.checkedInToday,
  });

  final Challenge challenge;

  /// Check-ins already logged in the current period.
  final int doneInPeriod;

  /// Check-ins the current period asks for (1 for daily quests).
  final int target;

  /// Whole days left in the current period; 0 = today is the last one.
  final int daysLeftInPeriod;

  /// Strikes burnt — the SETTLED figure from the hourly engine
  /// (shield-absorbed misses excluded), via challenge.strikesUsed.
  final int strikesUsed;

  /// The period's quota is full — nothing left to do until it resets.
  bool get goalMet => doneInPeriod >= target;

  /// Already logged today. Only one check-in per day is possible; the
  /// database enforces it with a unique constraint.
  final bool checkedInToday;

  /// Nothing left to do TODAY — either the period is complete, or today's
  /// one allowed check-in is already used.
  ///
  /// This, not [goalMet], decides whether a quest still belongs on the
  /// home screen. A quest that wants three check-ins a week is not
  /// "open" on a day it has already been ticked: the button would only
  /// answer "come back tomorrow", which is a demand the player cannot
  /// meet and therefore just noise.
  bool get doneForToday => goalMet || checkedInToday;

  /// Check-ins still needed in this period.
  int get remaining => (target - doneInPeriod).clamp(0, target);

  /// The strike budget is already blown: the quest is lost, the server
  /// just hasn't been told yet (strikes are evaluated lazily, on the
  /// next check-in attempt). Nothing can save it — don't pretend.
  bool get isDoomed => strikesUsed > challenge.maxStrikes;

  /// The last strike is on the table: check in today and it survives,
  /// miss and it's over. Actionable — unlike [isDoomed].
  bool get isCritical =>
      !doneForToday && !isDoomed && strikesUsed == challenge.maxStrikes;

  /// True when the period ends today — no second chance left.
  bool get deadlineToday => daysLeftInPeriod <= 0;

  /// Short label for the card: "today" / "2x left · 4d".
  String get demandLabel {
    if (challenge.checkinPeriod == CheckinPeriod.daily) return 'due today';
    final left =
        daysLeftInPeriod == 0 ? 'last day' : '${daysLeftInPeriod}d left';
    return '${remaining}x to go · $left';
  }
}

class HomeAgenda {
  const HomeAgenda({
    required this.open,
    required this.done,
    required this.upcoming,
  });

  /// Running quests whose current period still needs check-ins,
  /// most urgent first.
  final List<AgendaItem> open;

  /// Running quests whose current period is already satisfied.
  final List<AgendaItem> done;

  /// Quests that haven't started yet.
  final List<Challenge> upcoming;

  /// The subset of [open] that dies on the next miss — still savable.
  List<AgendaItem> get atRisk => open.where((i) => i.isCritical).toList();

  /// Quests whose strike budget is already gone: they only linger in
  /// the list until the server notices. Shown so the player knows.
  List<AgendaItem> get doomed => open.where((i) => i.isDoomed).toList();

  int get totalRunning => open.length + done.length;

  /// 0..1 for the progress ring; null when nothing is running.
  double? get completion =>
      totalRunning == 0 ? null : done.length / totalRunning;

  /// Show locally saved actions immediately, even while a server refresh waits
  /// for a network timeout. The caller passes only this account's current day.
  HomeAgenda withPendingCheckIns(Set<String> questIds) {
    if (!open.any((i) => questIds.contains(i.challenge.id))) return this;
    return HomeAgenda(
      open: open.where((i) => !questIds.contains(i.challenge.id)).toList(),
      done: [
        ...done,
        for (final item in open)
          if (questIds.contains(item.challenge.id))
            AgendaItem(
              challenge: item.challenge,
              doneInPeriod: item.doneInPeriod + 1,
              target: item.target,
              daysLeftInPeriod: item.daysLeftInPeriod,
              strikesUsed: item.strikesUsed,
              checkedInToday: true,
            ),
      ],
      upcoming: upcoming,
    );
  }

  static HomeAgenda build({
    required List<Challenge> challenges,
    required Map<String, Map<DateTime, DateTime>> checkInsByQuest,
    required DateTime today,
  }) {
    final todayDate = DateTime.utc(today.year, today.month, today.day);
    final open = <AgendaItem>[];
    final done = <AgendaItem>[];
    final upcoming = <Challenge>[];

    for (final challenge in challenges) {
      // Out of the running: the quest stays reachable from the Challenges
      // tab so the player can keep watching, but today's agenda is a
      // to-do list — and there is nothing left for them to do here.
      if (challenge.amIOut) continue;

      // A rest day: the quest demands nothing today and the server would
      // refuse an entry anyway. Listing it as "open" would only nag.
      if (!challenge.runsOn(todayDate)) continue;

      // A lobby quest hasn't started — it waits in the "upcoming" list.
      if (challenge.isLobby) {
        upcoming.add(challenge);
        continue;
      }

      final start = DateTime.utc(challenge.startsOn.year,
          challenge.startsOn.month, challenge.startsOn.day);
      // Endless quests never reach an end date.
      final endExclusive = challenge.isEndless
          ? null
          : start.add(Duration(days: challenge.durationDays));

      if (todayDate.isBefore(start)) {
        upcoming.add(challenge);
        continue;
      }
      // Over and done with — nothing to do here.
      if (endExclusive != null && !todayDate.isBefore(endExclusive)) continue;

      final checkIns = checkInsByQuest[challenge.id] ?? const {};
      final periodLen = challenge.checkinPeriod.lengthDays;
      final target = challenge.checkinPeriod == CheckinPeriod.daily
          ? 1
          : challenge.checkinsPerPeriod;

      // Current period, anchored to the start date (mirrors the server).
      final daysIn = todayDate.difference(start).inDays;
      final periodStart =
          start.add(Duration(days: (daysIn ~/ periodLen) * periodLen));
      var periodEnd = periodStart.add(Duration(days: periodLen));
      if (endExclusive != null && periodEnd.isAfter(endExclusive)) {
        periodEnd = endExclusive;
      }

      final doneInPeriod = checkIns.keys
          .where((d) => !d.isBefore(periodStart) && d.isBefore(periodEnd))
          .length;

      final item = AgendaItem(
        challenge: challenge,
        doneInPeriod: doneInPeriod,
        target: target,
        daysLeftInPeriod: periodEnd.difference(todayDate).inDays - 1,
        // The settled figure from the engine — not recomputed here,
        // because shields absorb strikes and only the server knows.
        strikesUsed: challenge.strikesUsed,
        checkedInToday: checkIns.containsKey(todayDate),
      );
      (item.doneForToday ? done : open).add(item);
    }

    // Most urgent first: critical, then tightest deadline, then the
    // biggest aura on the line. (Doomed ones sink — nothing to do.)
    open.sort((a, b) {
      if (a.isDoomed != b.isDoomed) return a.isDoomed ? 1 : -1;
      if (a.isCritical != b.isCritical) return a.isCritical ? -1 : 1;
      final byDeadline = a.daysLeftInPeriod.compareTo(b.daysLeftInPeriod);
      if (byDeadline != 0) return byDeadline;
      return b.challenge.auraGain.compareTo(a.challenge.auraGain);
    });

    return HomeAgenda(open: open, done: done, upcoming: upcoming);
  }
}
