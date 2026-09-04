/// A dice duel waiting for the logged-in user's answer.
class IncomingDuel {
  const IncomingDuel({
    required this.id,
    required this.questTitle,
    required this.challengerName,
    required this.challengerAvatar,
    required this.stake,
    required this.createdAt,
  });

  final String id;
  final String questTitle;
  final String challengerName;
  final String? challengerAvatar;
  final int stake;
  final DateTime createdAt;

  int get pot => stake * 2;
}

/// A duel as it appears in the quest's duel history — any status,
/// seen from either side.
class QuestDuel {
  const QuestDuel({
    required this.id,
    required this.challengerId,
    required this.challengerName,
    required this.challengerAvatar,
    required this.opponentId,
    required this.opponentName,
    required this.opponentAvatar,
    required this.stake,
    required this.status,
    required this.challengerDice,
    required this.opponentDice,
    required this.winnerId,
    required this.createdAt,
  });

  final String id;
  final String challengerId;
  final String challengerName;
  final String? challengerAvatar;
  final String opponentId;
  final String opponentName;
  final String? opponentAvatar;
  final int stake;

  /// 'pending' | 'resolved' | 'declined' | 'expired'
  final String status;

  /// Null until resolved.
  final List<int>? challengerDice;
  final List<int>? opponentDice;
  final String? winnerId;

  final DateTime createdAt;

  bool isChallenger(String userId) => challengerId == userId;

  /// The other player, from [userId]'s perspective.
  String otherName(String userId) =>
      isChallenger(userId) ? opponentName : challengerName;
  String? otherAvatar(String userId) =>
      isChallenger(userId) ? opponentAvatar : challengerAvatar;

  List<int>? myDice(String userId) =>
      isChallenger(userId) ? challengerDice : opponentDice;
  List<int>? theirDice(String userId) =>
      isChallenger(userId) ? opponentDice : challengerDice;

  bool wonBy(String userId) => winnerId == userId;
}

/// The server's verdict — dice are rolled in the RPC; the client only
/// animates what is already decided.
class DuelResult {
  const DuelResult({
    required this.challengerDice,
    required this.opponentDice,
    required this.winnerId,
    required this.pot,
  });

  final List<int> challengerDice;
  final List<int> opponentDice;
  final String winnerId;
  final int pot;

  factory DuelResult.fromJson(Map<String, dynamic> json) => DuelResult(
        challengerDice: (json['challenger_dice'] as List)
            .map((e) => e as int)
            .toList(),
        opponentDice:
            (json['opponent_dice'] as List).map((e) => e as int).toList(),
        winnerId: json['winner_id'] as String,
        pot: json['pot'] as int,
      );
}
