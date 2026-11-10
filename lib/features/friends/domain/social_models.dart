/// An accepted friend.
class Friend {
  const Friend({
    required this.userId,
    required this.username,
    required this.friendsSince,
    this.avatarEmoji,
  });

  final String userId;
  final String username;
  final String? avatarEmoji;
  final DateTime friendsSince;
}

/// An incoming friend request awaiting a decision.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromName,
    required this.createdAt,
    this.fromAvatarEmoji,
  });

  final String id;
  final String fromUserId;
  final String fromName;
  final String? fromAvatarEmoji;
  final DateTime createdAt;
}

/// A pending invitation into a quest (the invitee's view).
class QuestInvite {
  const QuestInvite({
    required this.id,
    required this.questTitle,
    required this.inviterName,
    required this.createdAt,
    this.rules,
  });

  final String id;
  final String questTitle;
  final String inviterName;
  final DateTime createdAt;

  /// What joining commits to, in one line: "CO-OP · 30 days · daily ·
  /// -50 Aura per miss · 1 strike". Null when the quest row could not
  /// be read, so an old server never breaks the invite list.
  final String? rules;

  /// Builds [rules] from the invited quest's row.
  static String? describe(Map<String, dynamic>? quest) {
    if (quest == null) return null;
    final mode = switch (quest['mode']) {
      'coop' => 'CO-OP · everyone pays for a miss',
      'versus' => 'TEAM BATTLE',
      'last_man_standing' => 'LAST STANDING',
      _ => 'FREE FOR ALL',
    };
    final days = quest['duration_days'] as int?;
    final length = quest['is_endless'] == true
        ? 'endless'
        : days == null
            ? null
            : '$days day${days == 1 ? '' : 's'}';
    final per = (quest['checkins_per_period'] as int?) ?? 1;
    final rhythm = switch (quest['checkin_period']) {
      'weekly' => '${per}x a week',
      'monthly' => '${per}x a month',
      _ => 'daily',
    };
    final goal = switch (quest['goal_type']) {
      'avoid' => 'avoid',
      'progress' => quest['tracking'] == 'clock' ? 'stopwatch' : 'progress',
      _ => null,
    };
    final penalty = quest['aura_penalty'] as int?;
    final strikes = quest['max_strikes'] as int?;
    return [
      mode,
      if (length != null) length,
      rhythm,
      if (goal != null) goal,
      if (penalty != null && penalty > 0) '-$penalty Aura per miss',
      if (strikes != null) '$strikes strike${strikes == 1 ? '' : 's'} allowed',
    ].join(' · ');
  }
}

/// A poke received from a quest-mate.
class Nudge {
  const Nudge({
    required this.challengeId,
    required this.questTitle,
    required this.fromName,
    required this.createdAt,
    this.seenAt,
    this.reaction,
  });

  final String challengeId;
  final String questTitle;
  final String fromName;
  final DateTime createdAt;

  /// When the recipient dismissed / reacted / checked in. Null = unseen.
  final DateTime? seenAt;

  /// The emoji the recipient fired back, if any.
  final String? reaction;

  bool get isSeen => seenAt != null;

  /// "3m ago" / "5h ago" / "2d ago" — for the pokes list.
  String timeAgo(DateTime now) {
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(0, 59)}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Unseen pokes for ONE quest, collapsed into a single inbox card.
class PokeGroup {
  const PokeGroup({
    required this.challengeId,
    required this.questTitle,
    required this.fromNames,
    required this.latest,
  });

  final String challengeId;
  final String questTitle;

  /// Distinct pokers, newest first.
  final List<String> fromNames;
  final DateTime latest;

  int get count => fromNames.length;

  /// "@A", "@A & 1 other", "@A & 3 others".
  String get who {
    if (fromNames.isEmpty) return 'Someone';
    if (fromNames.length == 1) return '@${fromNames.first}';
    return '@${fromNames.first} & ${fromNames.length - 1} '
        'other${fromNames.length - 1 == 1 ? '' : 's'}';
  }

  /// Groups unseen pokes by quest, newest group first.
  static List<PokeGroup> group(Iterable<Nudge> unseen) {
    final byQuest = <String, List<Nudge>>{};
    for (final n in unseen) {
      (byQuest[n.challengeId] ??= []).add(n);
    }
    final groups = byQuest.entries.map((e) {
      final list = [...e.value]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final names = <String>[];
      for (final n in list) {
        if (!names.contains(n.fromName)) names.add(n.fromName);
      }
      return PokeGroup(
        challengeId: e.key,
        questTitle: list.first.questTitle,
        fromNames: names,
        latest: list.first.createdAt,
      );
    }).toList()
      ..sort((a, b) => b.latest.compareTo(a.latest));
    return groups;
  }
}

/// A reaction the current user received on a poke THEY sent — shown in
/// their passive poke-back feed, never the actionable inbox.
class PokeBack {
  const PokeBack({
    required this.reactorName,
    required this.questTitle,
    required this.reaction,
    required this.createdAt,
  });

  /// The quest-mate who reacted (the original poke's recipient).
  final String reactorName;
  final String questTitle;
  final String reaction;
  final DateTime createdAt;
}
