/// The player's public profile — mirrors one row of the `profiles` table.
///
/// NOTE: aura is NOT part of the profile anymore. Aura lives strictly
/// per challenge on `challenge_participants.challenge_aura`.
class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.createdAt,
    this.avatarEmoji,
  });

  final String id;
  final String username;

  /// The emoji the player picked as their avatar; null → initial letter.
  final String? avatarEmoji;

  /// When the player signed up ("member since").
  final DateTime createdAt;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String,
        avatarEmoji: json['avatar_emoji'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Lifetime numbers shown on the profile screen (from `get_my_stats`).
class PlayerStats {
  const PlayerStats({
    required this.questsJoined,
    required this.activeQuests,
    required this.totalCheckins,
    required this.totalAura,
    required this.gearOwned,
    required this.friends,
    this.lifetimeXp = 0,
  });

  final int questsJoined;
  final int activeQuests;
  final int totalCheckins;

  /// Sum of the per-quest balances — aura itself stays challenge-scoped.
  final int totalAura;

  final int gearOwned;
  final int friends;
  final int lifetimeXp;

  /// A reset has a real level zero; any earned XP uses the established
  /// progression where the first 500 XP are level 1.
  int get level => lifetimeXp == 0 ? 0 : 1 + lifetimeXp ~/ 500;
  int get xpInLevel => lifetimeXp % 500;

  factory PlayerStats.fromJson(Map<String, dynamic> json) => PlayerStats(
        questsJoined: json['quests_joined'] as int,
        activeQuests: json['active_quests'] as int,
        totalCheckins: json['total_checkins'] as int,
        totalAura: json['total_aura'] as int,
        gearOwned: json['gear_owned'] as int,
        friends: json['friends'] as int,
        lifetimeXp: (json['lifetime_xp'] as num?)?.toInt() ?? 0,
      );
}
