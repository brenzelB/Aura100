/// A two-hour lockout bought in the quest shop.
///
/// The attacker picks a quest mate and a slice of the day; for those two
/// hours the target cannot log a thing in that quest — no check-in, no
/// reps. Which of the two it is follows from the quest type; nobody
/// chooses that.
///
/// The window is computed in the TARGET's local time on the server, so
/// "morning" is their morning even if the two players sit in different
/// time zones.
class Blackout {
  const Blackout({
    required this.id,
    required this.challengeId,
    required this.attackerId,
    required this.targetId,
    required this.daypart,
    required this.startsAt,
    required this.endsAt,
    required this.cost,
    this.attackerName,
    this.challengeTitle,
    this.acknowledgedAt,
  });

  final String id;
  final String challengeId;
  final String attackerId;
  final String targetId;

  /// 'morning' / 'noon' / 'evening'.
  final String daypart;

  final DateTime startsAt;
  final DateTime endsAt;
  final int cost;

  /// Who cast it — only filled in where the UI needs to name them.
  final String? attackerName;

  /// Which quest it belongs to — the home banner names it, because from
  /// there the player has no other clue which quest was hit.
  final String? challengeTitle;

  /// The target has seen the notice.
  final DateTime? acknowledgedAt;

  factory Blackout.fromJson(Map<String, dynamic> json) => Blackout(
        id: json['id'] as String,
        challengeId: json['challenge_id'] as String,
        attackerId: json['attacker_id'] as String,
        targetId: json['target_id'] as String,
        daypart: json['daypart'] as String,
        startsAt: DateTime.parse(json['starts_at'] as String).toUtc(),
        endsAt: DateTime.parse(json['ends_at'] as String).toUtc(),
        cost: json['cost'] as int,
        attackerName: ((json['attacker'] ?? json['profiles'])
            as Map<String, dynamic>?)?['username'] as String?,
        challengeTitle:
            (json['challenges'] as Map<String, dynamic>?)?['title'] as String?,
        acknowledgedAt: json['acknowledged_at'] == null
            ? null
            : DateTime.parse(json['acknowledged_at'] as String).toUtc(),
      );

  bool get isRunning {
    final now = DateTime.now().toUtc();
    return !now.isBefore(startsAt) && now.isBefore(endsAt);
  }

  /// Already over. A player who was offline the whole time only ever
  /// meets a blackout in this state — hence the notice on the home
  /// screen, which is the one place they cannot miss it.
  bool get hasEnded => DateTime.now().toUtc().isAfter(endsAt);

  /// How much of the lockout is left. Zero once it has run out.
  Duration get remaining {
    final left = endsAt.difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  /// `1h 12m` / `47m` / `< 1m` — the countdown the blocked player sees.
  String get remainingLabel {
    final left = remaining;
    if (left.inMinutes < 1) return '< 1m';
    final hours = left.inHours;
    final minutes = left.inMinutes % 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  static const dayparts = ['morning', 'noon', 'evening'];

  static String emojiFor(String daypart) => switch (daypart) {
        'morning' => '🌅',
        'noon' => '☀️',
        _ => '🌙',
      };

  static String labelFor(String daypart) => switch (daypart) {
        'morning' => 'MORNING',
        'noon' => 'NOON',
        _ => 'NIGHT',
      };

  /// The window in the target's own local time — the server anchors on
  /// exactly these hours.
  static String hoursFor(String daypart) => switch (daypart) {
        'morning' => '07:00 – 09:00',
        'noon' => '12:00 – 14:00',
        _ => '20:00 – 22:00',
      };
}
