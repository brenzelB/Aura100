/// What the settlement engine did — one row of `settlement_events`.
class SettlementEvent {
  const SettlementEvent({
    required this.kind,
    required this.amount,
    required this.challengeId,
    required this.questTitle,
    required this.createdAt,
    this.canOpenQuest = true,
  });

  /// 'penalty' | 'strike' | 'shield_saved' | 'failed' | 'completed' |
  /// 'bonus' | 'duel_won' | 'duel_lost' | 'versus_won' | 'versus_lost' |
  /// 'milestone' | 'strike_repaired'
  final String kind;

  /// Aura delta (negative for penalties) or streak/strike count.
  final int? amount;

  final String challengeId;
  final String questTitle;
  final DateTime createdAt;

  /// Own events can outlive membership; RLS then hides the joined quest.
  final bool canOpenQuest;

  factory SettlementEvent.fromJson(Map<String, dynamic> row) {
    final quest = row['challenges'] as Map<String, dynamic>?;
    return SettlementEvent(
      kind: row['kind'] as String,
      amount: (row['amount'] as num?)?.toInt(),
      challengeId: row['challenge_id'] as String,
      questTitle: quest?['title'] as String? ?? 'Unavailable quest',
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      canOpenQuest: quest != null,
    );
  }
}

/// A finished quest in the trophy room: the frozen end state.
class Trophy {
  const Trophy({
    required this.challengeId,
    required this.questTitle,
    required this.finalAura,
    required this.completed,
    required this.perfect,
    required this.finishedAt,
  });

  /// Identifies the quest when removing this entry from the room.
  final String challengeId;

  final String questTitle;

  /// Frozen aura (incl. completion bonus, or the 25% salvage on fail).
  final int finalAura;

  final bool completed;

  /// Completed without a single missed period.
  final bool perfect;

  final DateTime? finishedAt;
}
