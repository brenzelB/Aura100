/// One member of a quest's party — participant row + profile + the
/// social status the party list shows.
class QuestMember {
  const QuestMember({
    required this.userId,
    required this.username,
    required this.questAura,
    required this.isOwner,
    required this.isMe,
    required this.checkedToday,
    required this.doneThisPeriod,
    required this.checkinsThisPeriod,
    required this.gear,
    this.avatarEmoji,
    this.team,
    this.totalCheckins = 0,
    this.progressInPeriod = 0,
    this.status = 'active',
    this.lastActivityAt,
  });

  final String userId;
  final String username;

  /// The member's avatar emoji; null → initial letter.
  final String? avatarEmoji;
  final int questAura;

  /// Creator of the quest (crown in the UI).
  final bool isOwner;

  /// The logged-in user themselves (no nudge button).
  final bool isMe;

  /// Checked in today (UTC).
  final bool checkedToday;

  /// Reached the current period's check-in target (== checkedToday
  /// for daily quests).
  final bool doneThisPeriod;

  final int checkinsThisPeriod;

  /// Titles of shop benefits this member owns in the quest.
  final List<String> gear;

  /// 'red' / 'blue' in a versus quest, null otherwise.
  final String? team;

  /// All check-ins over the whole quest — feeds the versus scoreboard.
  final int totalCheckins;

  /// How much this member logged towards the CURRENT period's target
  /// (progress quests only) — the party sees each other's numbers.
  final double progressInPeriod;

  /// Participation status: 'active' / 'eliminated' / 'completed' /
  /// 'failed'.
  final String status;

  /// When this member last put something on the board — a check-in on a
  /// tick-off quest, a progress entry on a counting one. Null means they
  /// have not logged anything in this quest yet.
  ///
  /// The party list shows it so everyone can see who leaves it to the
  /// last minute. That is also the intelligence a Blackout runs on:
  /// knowing someone always logs at eight in the morning is what makes
  /// picking the morning slot worth 250 aura.
  final DateTime? lastActivityAt;

  /// Knocked out of a Last Man Standing quest.
  bool get isEliminated => status == 'eliminated';

  /// Ran out of strikes in any other mode.
  bool get hasFailed => status == 'failed';

  /// Out of the running, whichever way it happened. They keep their seat
  /// and keep watching — the party list just stops treating them as a
  /// rival: no poking, no duelling, no roasting.
  bool get isOut => isEliminated || hasFailed;

  bool get isWinner => status == 'completed';
}
