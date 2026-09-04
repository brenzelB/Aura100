/// The running score between the logged-in player and one friend.
///
/// Counted only over quests both of them are actually in — comparing
/// totals across quests the other never joined would be meaningless.
class HeadToHead {
  const HeadToHead({
    required this.friendId,
    required this.username,
    required this.sharedQuests,
    required this.myCheckIns,
    required this.theirCheckIns,
    required this.myAura,
    required this.theirAura,
    required this.duelsWon,
    required this.duelsLost,
    this.avatarEmoji,
  });

  final String friendId;
  final String username;
  final String? avatarEmoji;

  /// Quests both are in (any status — a quest someone lost still counts
  /// towards the history between them).
  final int sharedQuests;

  final int myCheckIns;
  final int theirCheckIns;

  /// Aura held in those shared quests, summed.
  final int myAura;
  final int theirAura;

  /// Dice duels between exactly these two, decided.
  final int duelsWon;
  final int duelsLost;

  bool get hasHistory => sharedQuests > 0;

  /// Ahead on check-ins — the figure the headline is built on, because
  /// it is the one both players can influence every single day.
  bool get amIAhead => myCheckIns > theirCheckIns;
  bool get isTied => myCheckIns == theirCheckIns;

  /// `12 : 8` — always mine first.
  String get scoreLine => '$myCheckIns : $theirCheckIns';

  String get duelLine => '$duelsWon : $duelsLost';
}
