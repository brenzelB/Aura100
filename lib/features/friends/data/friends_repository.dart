import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/social_models.dart';

/// Friendships plus the social inbox: quest invites and pokes.
class FriendsRepository {
  FriendsRepository(this._client);

  final SupabaseClient _client;

  /// The user's accepted friends, alphabetical.
  ///
  /// A friendship is one row with requester/addressee — which side is
  /// "me" varies, so the other party is resolved here. RLS already
  /// limits the rows to friendships the user is part of.
  Future<List<Friend>> fetchFriends() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      final rows = await _client.from('friendships').select(
          'requester_id, addressee_id, created_at, '
          'requester:profiles!friendships_requester_id_fkey(username, avatar_emoji), '
          'addressee:profiles!friendships_addressee_id_fkey(username, avatar_emoji)')
          .eq('status', 'accepted');

      final friends = rows.map((row) {
        final iAmRequester = row['requester_id'] == userId;
        final otherId =
            (iAmRequester ? row['addressee_id'] : row['requester_id'])
                as String;
        final other = (iAmRequester ? row['addressee'] : row['requester'])
            as Map<String, dynamic>;
        return Friend(
          userId: otherId,
          username: other['username'] as String,
          avatarEmoji: other['avatar_emoji'] as String?,
          friendsSince: DateTime.parse(row['created_at'] as String),
        );
      }).toList()
        ..sort((a, b) =>
            a.username.toLowerCase().compareTo(b.username.toLowerCase()));
      debugPrint('✅ [FriendsRepository.fetchFriends] ${friends.length} friends');
      return friends;
    } on PostgrestException catch (e) {
      _log('fetchFriends', e);
      rethrow;
    }
  }

  /// Friend requests addressed TO the user, newest first.
  Future<List<FriendRequest>> fetchFriendRequests() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      final rows = await _client
          .from('friendships')
          .select('id, requester_id, created_at, '
              'requester:profiles!friendships_requester_id_fkey'
              '(username, avatar_emoji)')
          .eq('addressee_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final requests = rows.map((row) {
        final from = row['requester'] as Map<String, dynamic>;
        return FriendRequest(
          id: row['id'] as String,
          fromUserId: row['requester_id'] as String,
          fromName: from['username'] as String,
          fromAvatarEmoji: from['avatar_emoji'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();
      debugPrint('✅ [FriendsRepository.fetchFriendRequests] '
          '${requests.length} pending');
      return requests;
    } on PostgrestException catch (e) {
      _log('fetchFriendRequests', e);
      rethrow;
    }
  }

  /// Sends a friend request. Returns 'accepted' when the other player
  /// had already asked (mutual request = instant friends), else
  /// 'pending'.
  Future<String> sendFriendRequest(String username) async {
    try {
      final status = await _client
          .rpc<String>('send_friend_request', params: {'p_username': username});
      debugPrint(
          '✅ [FriendsRepository.sendFriendRequest] "$username" → $status');
      return status;
    } on PostgrestException catch (e) {
      _log('sendFriendRequest', e);
      rethrow;
    }
  }

  /// Accepts or declines a friend request (declining removes the row,
  /// so they may ask again later).
  Future<void> respondToFriendRequest({
    required String friendshipId,
    required bool accept,
  }) async {
    try {
      await _client.rpc<void>('respond_to_friend_request', params: {
        'p_friendship_id': friendshipId,
        'p_accept': accept,
      });
      debugPrint('✅ [FriendsRepository.respondToFriendRequest] '
          '$friendshipId → ${accept ? 'accepted' : 'declined'}');
    } on PostgrestException catch (e) {
      _log('respondToFriendRequest', e);
      rethrow;
    }
  }

  /// Unfriends someone (works from either side).
  Future<void> removeFriend(String userId) async {
    try {
      await _client.rpc<void>('remove_friend', params: {'p_user_id': userId});
      debugPrint('✅ [FriendsRepository.removeFriend] removed $userId');
    } on PostgrestException catch (e) {
      _log('removeFriend', e);
      rethrow;
    }
  }

  /// Pending invites addressed to the logged-in user, newest first.
  Future<List<QuestInvite>> fetchMyInvites() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      // Two FKs point at profiles → the inviter needs an explicit hint.
      final rows = await _client
          .from('invites')
          .select('id, created_at, challenges(title), '
              'inviter:profiles!invites_inviter_id_fkey(username)')
          .eq('invitee_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final invites = rows
          .map((row) => QuestInvite(
                id: row['id'] as String,
                questTitle: (row['challenges']
                    as Map<String, dynamic>)['title'] as String,
                inviterName: (row['inviter']
                    as Map<String, dynamic>)['username'] as String,
                createdAt: DateTime.parse(row['created_at'] as String),
              ))
          .toList();
      debugPrint(
          '✅ [FriendsRepository.fetchMyInvites] ${invites.length} pending');
      return invites;
    } on PostgrestException catch (e) {
      _log('fetchMyInvites', e);
      rethrow;
    }
  }

  /// Accepts (joins the quest in the same transaction) or declines.
  Future<void> respondToInvite({
    required String inviteId,
    required bool accept,
  }) async {
    try {
      await _client.rpc<void>('respond_to_invite', params: {
        'p_invite_id': inviteId,
        'p_accept': accept,
      });
      debugPrint('✅ [FriendsRepository.respondToInvite] '
          '$inviteId → ${accept ? 'accepted' : 'declined'}');
    } on PostgrestException catch (e) {
      _log('respondToInvite', e);
      rethrow;
    }
  }

  /// Recent pokes received by the logged-in user (history — seen or not).
  Future<List<Nudge>> fetchMyNudges() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      final rows = await _client
          .from('nudges')
          .select('challenge_id, created_at, seen_at, reaction, '
              'challenges(title), '
              'sender:profiles!nudges_from_user_fkey(username)')
          .eq('to_user', userId)
          .order('created_at', ascending: false)
          .limit(20);

      final nudges = rows.map(_nudgeFromRow).toList();
      debugPrint(
          '✅ [FriendsRepository.fetchMyNudges] ${nudges.length} pokes');
      return nudges;
    } on PostgrestException catch (e) {
      _log('fetchMyNudges', e);
      rethrow;
    }
  }

  /// UNSEEN pokes only — the actionable Home inbox.
  Future<List<Nudge>> fetchUnseenNudges() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    try {
      final rows = await _client
          .from('nudges')
          .select('challenge_id, created_at, seen_at, reaction, '
              'challenges(title), '
              'sender:profiles!nudges_from_user_fkey(username)')
          .eq('to_user', userId)
          .isFilter('seen_at', null)
          .order('created_at', ascending: false);
      return rows.map(_nudgeFromRow).toList();
    } on PostgrestException catch (e) {
      _log('fetchUnseenNudges', e);
      rethrow;
    }
  }

  /// Reactions the user received on pokes THEY sent, not yet seen —
  /// the passive poke-back feed.
  Future<List<PokeBack>> fetchPokeBacks() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    try {
      final rows = await _client
          .from('nudges')
          .select('created_at, reaction, challenges(title), '
              'reactor:profiles!nudges_to_user_fkey(username)')
          .eq('from_user', userId)
          .not('reaction', 'is', null)
          .isFilter('reaction_seen_at', null)
          .order('created_at', ascending: false);
      return rows
          .map((row) => PokeBack(
                reactorName: (row['reactor']
                    as Map<String, dynamic>)['username'] as String,
                questTitle: (row['challenges']
                    as Map<String, dynamic>)['title'] as String,
                reaction: row['reaction'] as String,
                createdAt: DateTime.parse(row['created_at'] as String),
              ))
          .toList();
    } on PostgrestException catch (e) {
      _log('fetchPokeBacks', e);
      rethrow;
    }
  }

  /// Dismiss a quest's pokes (mark seen, no reaction).
  Future<void> dismissQuestPokes(String challengeId) async {
    try {
      await _client.rpc<int>('dismiss_quest_pokes',
          params: {'p_challenge_id': challengeId});
    } on PostgrestException catch (e) {
      _log('dismissQuestPokes', e);
      rethrow;
    }
  }

  /// Fire one emoji back at everyone who poked you in this quest.
  Future<void> reactToQuestPokes(String challengeId, String reaction) async {
    try {
      await _client.rpc<int>('react_to_quest_pokes',
          params: {'p_challenge_id': challengeId, 'p_reaction': reaction});
    } on PostgrestException catch (e) {
      _log('reactToQuestPokes', e);
      rethrow;
    }
  }

  /// Mark all poke-backs the sender has now seen.
  Future<void> ackPokeBacks() async {
    try {
      await _client.rpc<int>('ack_poke_backs');
    } on PostgrestException catch (e) {
      _log('ackPokeBacks', e);
    }
  }

  // ── Safety: reporting and blocking ─────────────────────────────

  /// Ids the current user has blocked. Blocking is mutual in effect:
  /// neither side can poke, roast, rob or duel the other afterwards.
  Future<Set<String>> fetchBlockedIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return <String>{};
    try {
      final rows = await _client
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', userId);
      return rows.map((r) => r['blocked_id'] as String).toSet();
    } on PostgrestException catch (e) {
      _log('fetchBlockedIds', e);
      rethrow;
    }
  }

  /// Blocks a player and ends any friendship with them.
  Future<void> blockUser(String userId) async {
    try {
      await _client.rpc<void>('block_user', params: {'p_user_id': userId});
      debugPrint('✅ [FriendsRepository.blockUser] $userId');
    } on PostgrestException catch (e) {
      _log('blockUser', e);
      rethrow;
    }
  }

  Future<void> unblockUser(String userId) async {
    try {
      await _client.rpc<void>('unblock_user', params: {'p_user_id': userId});
    } on PostgrestException catch (e) {
      _log('unblockUser', e);
      rethrow;
    }
  }

  /// Files a report for review. [reason] is one of the values the server
  /// accepts: harassment, offensive_name, cheating, spam, other.
  Future<void> reportUser({
    required String userId,
    required String reason,
    String? details,
    String? challengeId,
  }) async {
    try {
      await _client.rpc<void>('report_user', params: {
        'p_user_id': userId,
        'p_reason': reason,
        'p_details': details,
        'p_challenge_id': challengeId,
      });
      debugPrint('✅ [FriendsRepository.reportUser] $userId ($reason)');
    } on PostgrestException catch (e) {
      _log('reportUser', e);
      rethrow;
    }
  }

  static Nudge _nudgeFromRow(Map<String, dynamic> row) => Nudge(
        challengeId: row['challenge_id'] as String,
        questTitle:
            (row['challenges'] as Map<String, dynamic>)['title'] as String,
        fromName:
            (row['sender'] as Map<String, dynamic>)['username'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        seenAt: row['seen_at'] == null
            ? null
            : DateTime.parse(row['seen_at'] as String),
        reaction: row['reaction'] as String?,
      );

  static void _log(String method, PostgrestException e) {
    debugPrint(
      '⛔ [FriendsRepository.$method] PostgrestException\n'
      '   code:    ${e.code}\n'
      '   message: ${e.message}\n'
      '   details: ${e.details}',
    );
  }
}
