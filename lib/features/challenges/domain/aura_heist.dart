/// What the server reports right after an Aura Heist attempt — the dice
/// are rolled server-side at purchase, so the attacker learns hit/miss
/// immediately.
class AuraHeistResult {
  const AuraHeistResult({
    required this.succeeded,
    required this.chance,
    required this.cost,
    required this.newBalance,
  });

  final bool succeeded;

  /// 0.25 / 0.50 / 0.75 — the odds for the chosen tier.
  final double chance;
  final int cost;

  /// The attacker's remaining quest aura after paying.
  final int newBalance;

  factory AuraHeistResult.fromJson(Map<String, dynamic> json) =>
      AuraHeistResult(
        succeeded: json['succeeded'] as bool,
        chance: (json['chance'] as num).toDouble(),
        cost: (json['cost'] as num).toInt(),
        newBalance: (json['new_balance'] as num).toInt(),
      );
}

/// A landed heist the victim has not seen yet — the aura was taken on
/// their last check-in. Drives the "you got robbed" notice.
class RobbedNotice {
  const RobbedNotice({
    required this.id,
    required this.challengeId,
    required this.attackerUsername,
    required this.stolenAmount,
    required this.resolvedAt,
  });

  final String id;
  final String challengeId;
  final String attackerUsername;
  final int stolenAmount;
  final DateTime resolvedAt;

  factory RobbedNotice.fromJson(Map<String, dynamic> json) {
    var name = 'Someone';
    final attacker = json['attacker'];
    if (attacker is Map && attacker['username'] != null) {
      name = attacker['username'] as String;
    }
    return RobbedNotice(
      id: json['id'] as String,
      challengeId: json['challenge_id'] as String,
      attackerUsername: name,
      stolenAmount: (json['stolen_amount'] as num?)?.toInt() ?? 0,
      resolvedAt: DateTime.parse(json['resolved_at'] as String),
    );
  }
}
