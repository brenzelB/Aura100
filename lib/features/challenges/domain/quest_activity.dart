/// One thing that happened to somebody in a quest — the party's shared
/// timeline of wins and losses.
///
/// Merged from three sources (settlement events, check-ins and progress
/// entries) so the feed reads as one story rather than three tables.
class QuestActivity {
  const QuestActivity({
    required this.kind,
    required this.username,
    required this.isMe,
    required this.createdAt,
    this.avatarEmoji,
    this.amount,
    this.detail,
  });

  /// Settlement kinds ('penalty', 'strike', 'failed', 'completed',
  /// 'bonus', 'milestone', 'duel_won', …) plus two synthetic ones:
  /// 'check_in' and 'progress'.
  final String kind;

  final String username;
  final String? avatarEmoji;
  final bool isMe;
  final DateTime createdAt;

  /// Aura delta, streak length or logged amount — depends on [kind].
  final num? amount;

  /// Free text the row needs to make sense: the item bought, the mate
  /// roasted, the slice of day a lockout covers.
  final String? detail;

  /// Good news or bad news? Drives the colour in the feed.
  bool get isPositive => const {
        'check_in',
        'progress',
        'completed',
        'bonus',
        'milestone',
        'shield_saved',
        'duel_won',
        'versus_won',
        'strike_repaired',
      }.contains(kind);

  bool get isBad => const {
        'penalty',
        'strike',
        'failed',
        'duel_lost',
        'versus_lost',
      }.contains(kind);
}
