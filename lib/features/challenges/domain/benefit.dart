/// A purchasable perk in ONE challenge's shop — mirrors a `benefits`
/// row plus whether the logged-in user already owns it.
class Benefit {
  const Benefit({
    required this.id,
    required this.challengeId,
    required this.title,
    required this.description,
    required this.cost,
    this.readyCount = 0,
    this.usedCount = 0,
  });

  final String id;
  final String challengeId;
  final String title;
  final String description;
  final int cost;

  /// Purchases not yet consumed by the settlement engine.
  final int readyCount;

  /// Purchases the engine already used up (shield absorbed a strike,
  /// half damage softened a penalty).
  final int usedCount;

  bool get owned => readyCount > 0 || usedCount > 0;

  /// Items the engine (or a check-in) spends: they stack up and stay
  /// buyable. Strike Repair is consumed the instant it is bought.
  static const consumables = {
    'Streak Shield',
    'Double Down',
    'Strike Repair',
    'Targeted Roast',
    'Aura Heist',
    'Aura Ward',
  };

  /// Own-once emblems worn next to the player's name in the party. Both
  /// also grant a permanent per-check-in aura multiplier (Title Badge
  /// +20%, Aura Lord ×2). Highest flex last.
  static const titles = ['Title Badge', 'Aura Lord'];

  /// Consumables can be stocked up and get spent; emblems
  /// (Title Badge, Aura Lord) are own-once.
  bool get isConsumable => consumables.contains(title);

  /// Whether this benefit is an own-once emblem/title.
  bool get isTitle => titles.contains(title);

  /// The best emblem in a set of owned benefit names, or null.
  static String? bestTitle(Iterable<String> owned) {
    String? best;
    for (final t in titles) {
      if (owned.contains(t)) best = t;
    }
    return best;
  }

  /// Every owned emblem, weakest→strongest, for showing all badges.
  static List<String> ownedTitles(Iterable<String> owned) => [
        for (final t in titles)
          if (owned.contains(t)) t
      ];

  factory Benefit.fromJson(Map<String, dynamic> json) => Benefit(
        id: json['id'] as String,
        challengeId: json['challenge_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        cost: json['cost'] as int,
      );

  Benefit copyWith({int? readyCount, int? usedCount}) => Benefit(
        id: id,
        challengeId: challengeId,
        title: title,
        description: description,
        cost: cost,
        readyCount: readyCount ?? this.readyCount,
        usedCount: usedCount ?? this.usedCount,
      );
}
