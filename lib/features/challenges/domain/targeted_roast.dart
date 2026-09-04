/// Model for a targeted roast attack sent by a player to a teammate.
class TargetedRoast {
  const TargetedRoast({
    required this.id,
    required this.challengeId,
    required this.senderId,
    required this.senderUsername,
    required this.targetId,
    required this.roastText,
    required this.durationSeconds,
    required this.createdAt,
    this.acknowledgedAt,
  });

  final String id;
  final String challengeId;
  final String senderId;
  final String senderUsername;
  final String targetId;
  final String roastText;
  final int durationSeconds; // 3 or 5
  final DateTime createdAt;
  final DateTime? acknowledgedAt;

  factory TargetedRoast.fromJson(Map<String, dynamic> json) {
    String senderName = 'Teammate';
    if (json['sender'] is Map && json['sender']['username'] != null) {
      senderName = json['sender']['username'] as String;
    } else if (json['sender_username'] != null) {
      senderName = json['sender_username'] as String;
    }

    return TargetedRoast(
      id: json['id'] as String,
      challengeId: json['challenge_id'] as String,
      senderId: json['sender_id'] as String,
      senderUsername: senderName,
      targetId: json['target_id'] as String,
      roastText: json['roast_text'] as String,
      durationSeconds: json['duration_seconds'] as int? ?? 3,
      createdAt: DateTime.parse(json['created_at'] as String),
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'] as String)
          : null,
    );
  }
}
