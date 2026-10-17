/// Free rock-paper-scissors. These models deliberately have no currency fields.
enum DuelMove {
  rock('Rock', '✊'),
  paper('Paper', '✋'),
  scissors('Scissors', '✌️');

  const DuelMove(this.label, this.symbol);
  final String label, symbol;
  bool beats(DuelMove other) => switch ((this, other)) {
        (rock, scissors) || (scissors, paper) || (paper, rock) => true,
        _ => false,
      };
  static DuelMove? parse(Object? value) =>
      values.where((move) => move.name == value).firstOrNull;
}

class IncomingDuel {
  const IncomingDuel(
      {required this.id,
      required this.questTitle,
      required this.challengerName,
      required this.challengerAvatar,
      required this.createdAt,
      this.status = 'pending',
      this.isChallenger = false});
  final String id, questTitle;

  /// The other player, including accepted outgoing invitations.
  final String challengerName;
  final String? challengerAvatar;
  final DateTime createdAt;
  final String status;
  final bool isChallenger;
}

class QuestDuel {
  const QuestDuel(
      {required this.id,
      required this.challengerId,
      required this.challengerName,
      required this.challengerAvatar,
      required this.opponentId,
      required this.opponentName,
      required this.opponentAvatar,
      required this.status,
      required this.winnerId,
      required this.createdAt,
      this.challengerScore = 0,
      this.opponentScore = 0,
      this.roastKey = 0});
  final String id,
      challengerId,
      challengerName,
      opponentId,
      opponentName,
      status;
  final String? challengerAvatar, opponentAvatar, winnerId;
  final DateTime createdAt;
  final int challengerScore, opponentScore, roastKey;
  bool isChallenger(String userId) => challengerId == userId;
  String otherName(String userId) =>
      isChallenger(userId) ? opponentName : challengerName;
  String? otherAvatar(String userId) =>
      isChallenger(userId) ? opponentAvatar : challengerAvatar;
  bool wonBy(String userId) => winnerId == userId;
  String scoreFor(String userId) => isChallenger(userId)
      ? '$challengerScore : $opponentScore'
      : '$opponentScore : $challengerScore';
}

class DuelResult {
  const DuelResult(
      {required this.id,
      required this.status,
      required this.challengerId,
      required this.opponentId,
      required this.round,
      required this.challengerScore,
      required this.opponentScore,
      required this.roastKey,
      this.winnerId,
      this.myMove,
      this.lastChallengerMove,
      this.lastOpponentMove});
  final String id, status, challengerId, opponentId;
  final int round, challengerScore, opponentScore, roastKey;
  final String? winnerId;
  final DuelMove? myMove, lastChallengerMove, lastOpponentMove;
  bool get isFinished => status == 'resolved';
  String scoreFor(String userId) => userId == challengerId
      ? '$challengerScore : $opponentScore'
      : '$opponentScore : $challengerScore';
  factory DuelResult.fromJson(Map<String, dynamic> json) => DuelResult(
      id: json['id'] as String,
      status: json['status'] as String,
      challengerId: json['challenger_id'] as String,
      opponentId: json['opponent_id'] as String,
      round: json['round_number'] as int,
      challengerScore: json['challenger_score'] as int,
      opponentScore: json['opponent_score'] as int,
      roastKey: json['roast_key'] as int,
      winnerId: json['winner_id'] as String?,
      myMove: DuelMove.parse(json['my_move']),
      lastChallengerMove: DuelMove.parse(json['last_challenger_move']),
      lastOpponentMove: DuelMove.parse(json['last_opponent_move']));
}
