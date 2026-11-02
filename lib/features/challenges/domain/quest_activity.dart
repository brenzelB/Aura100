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
    this.roastKey,
    this.startedAt,
    this.endedAt,
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
  final int? roastKey;

  /// The two ends of a measured run, on a clock quest.
  ///
  /// The total alone ("+10h 02m") does not say whether that was
  /// yesterday evening into this morning or a long afternoon. Null on
  /// every other kind of row, and on a clock entry whose session row is
  /// gone.
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Both ends known, so the span can actually be printed.
  bool get hasSpan => startedAt != null && endedAt != null;

  /// The day this belongs to in a reader's life.
  ///
  /// The feed used to stamp every row with the age of the ROW — "1d"
  /// for anything banked between 24 and 48 hours ago. Nobody fasts in
  /// row-ages. A measured run is dated by when it ENDED; everything
  /// else by when it was recorded, which for those is the same moment.
  DateTime get happenedAt => endedAt ?? createdAt;

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
