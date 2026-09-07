import 'package:flutter/foundation.dart';

/// Represents a quest check-in logged while the device was offline.
///
/// Persisted locally in [SharedPreferences] and processed as soon as
/// network connectivity is restored.
@immutable
class PendingCheckIn {
  const PendingCheckIn({
    required this.challengeId,
    required this.questTitle,
    required this.timestamp,
    required this.date,
  });

  /// The target challenge/quest ID.
  final String challengeId;

  /// Human-readable title for UI toasts and sync reports.
  final String questTitle;

  /// Exact wall-clock time when the user tapped the check-in button.
  final DateTime timestamp;

  /// Normalized UTC day (e.g. 2026-09-04 00:00:00Z) this check-in belongs to.
  final DateTime date;

  Map<String, dynamic> toJson() => {
        'challenge_id': challengeId,
        'quest_title': questTitle,
        'timestamp': timestamp.toIso8601String(),
        'date': date.toIso8601String(),
      };

  factory PendingCheckIn.fromJson(Map<String, dynamic> json) {
    return PendingCheckIn(
      challengeId: json['challenge_id'] as String,
      questTitle: (json['quest_title'] as String?) ?? 'Quest',
      timestamp: DateTime.parse(json['timestamp'] as String),
      date: DateTime.parse(json['date'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingCheckIn &&
          runtimeType == other.runtimeType &&
          challengeId == other.challengeId &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day;

  @override
  int get hashCode => Object.hash(challengeId, date.year, date.month, date.day);

  @override
  String toString() =>
      'PendingCheckIn($questTitle [$challengeId] on ${date.toIso8601String()})';
}
