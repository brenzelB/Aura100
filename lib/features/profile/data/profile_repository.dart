import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';

/// Reads and edits the player's own profile.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  /// The logged-in user's own profile, or null when logged out.
  ///
  /// The profile row is guaranteed to exist for every user — the
  /// `handle_new_user` DB trigger creates it at signup.
  Future<Profile?> fetchCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final json = await _client
          .from('profiles')
          .select('id, username, avatar_emoji, created_at')
          .eq('id', userId)
          .single();
      return Profile.fromJson(json);
    } on PostgrestException catch (e) {
      _log('fetchCurrentProfile', e);
      rethrow;
    }
  }

  /// The account's email (from auth, not the profiles table).
  String? get currentEmail => _client.auth.currentUser?.email;

  /// Lifetime stats via the `get_my_stats` RPC.
  Future<PlayerStats?> fetchStats() async {
    if (_client.auth.currentUser == null) return null;

    try {
      // The function returns a one-row table.
      final rows = await _client.rpc<List<dynamic>>('get_my_stats');
      if (rows.isEmpty) return null;
      final stats = PlayerStats.fromJson(rows.first as Map<String, dynamic>);
      debugPrint('✅ [ProfileRepository.fetchStats] '
          '${stats.questsJoined} quests, ${stats.totalCheckins} check-ins');
      return stats;
    } on PostgrestException catch (e) {
      _log('fetchStats', e);
      rethrow;
    }
  }

  /// Renames the player. Clients may only ever write `username`
  /// (column-level grant), and RLS restricts it to their own row.
  ///
  /// Throws a [PostgrestException]; code 23505 means the name is taken.
  Future<void> updateUsername(String username) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from('profiles')
          .update({'username': username})
          .eq('id', userId);
      debugPrint('✅ [ProfileRepository.updateUsername] → "$username"');
    } on PostgrestException catch (e) {
      _log('updateUsername', e);
      rethrow;
    }
  }

  /// Sets (or clears, with null) the avatar emoji. Like `username`,
  /// this column is client-writable by grant + RLS on the own row.
  Future<void> updateAvatarEmoji(String? emoji) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from('profiles')
          .update({'avatar_emoji': emoji})
          .eq('id', userId);
      debugPrint('✅ [ProfileRepository.updateAvatarEmoji] '
          '→ ${emoji ?? '(cleared)'}');
    } on PostgrestException catch (e) {
      _log('updateAvatarEmoji', e);
      rethrow;
    }
  }

  /// Resets player stats via `reset_my_stats` RPC.
  Future<void> resetStats() async {
    try {
      await _client.rpc<void>('reset_my_stats');
      debugPrint('✅ [ProfileRepository.resetStats] stats reset');
    } on PostgrestException catch (e) {
      _log('resetStats', e);
      rethrow;
    }
  }

  /// Deletes the account for good via `delete_my_account`: owned
  /// quests are handed to the longest-standing member (or removed if
  /// nobody else is in them), then every trace of the user goes.
  Future<void> deleteAccount() async {
    try {
      await _client.rpc<void>('delete_my_account');
      debugPrint('✅ [ProfileRepository.deleteAccount] account deleted');
    } on PostgrestException catch (e) {
      _log('deleteAccount', e);
      rethrow;
    }
  }

  static void _log(String method, PostgrestException e) {
    debugPrint(
      '⛔ [ProfileRepository.$method] PostgrestException\n'
      '   code:    ${e.code}\n'
      '   message: ${e.message}\n'
      '   details: ${e.details}',
    );
  }
}
