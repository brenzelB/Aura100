import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/challenges/application/challenge_providers.dart';
import '../../features/friends/application/friends_providers.dart';
import '../../features/home/application/home_providers.dart';

/// Push instead of poll.
///
/// The app used to keep two 8-second timers alive, each invalidating a
/// handful of providers per tick regardless of whether anything had
/// changed. This opens ONE realtime channel instead and refetches only
/// what an actual database event touched.
///
/// The screens keep a slow timer as a safety net (see [fallbackInterval]):
/// if the socket is down — flaky mobile network, backgrounded app, a
/// backend without realtime — the app still catches up, just later.
/// Correctness never depends on the socket being healthy.
///
/// Row Level Security applies to realtime too, so a client is only ever
/// handed rows it could have read anyway.
class RealtimeSync {
  RealtimeSync(this._ref, this._userId);

  final Ref _ref;
  final String _userId;
  RealtimeChannel? _channel;

  /// How long the screens wait between safety-net refreshes while the
  /// socket is healthy. Long on purpose — realtime does the real work.
  static const fallbackInterval = Duration(seconds: 45);

  /// True once the socket is live; the screens back their timers off to
  /// [fallbackInterval] only then.
  final ValueNotifier<bool> connected = ValueNotifier(false);

  void start() {
    final client = Supabase.instance.client;
    final channel = client.channel('aura-sync-$_userId');

    // ── Aimed at me: the notification surfaces ──────────────
    _on(channel, 'targeted_roasts', column: 'target_id', value: _userId,
        onEvent: () => _ref.invalidate(targetedRoastsProvider));

    _on(channel, 'aura_heists', column: 'target_id', value: _userId,
        onEvent: () {
      _ref.invalidate(robbedNoticesProvider);
      _ref.invalidate(myChallengesProvider);
    });

    // A Blackout aimed at me. The row lands the moment it is bought,
    // which is usually BEFORE the window opens — the card only shows
    // itself once the clock is inside it, so nothing is given away.
    _on(channel, 'blackouts', column: 'target_id', value: _userId,
        onEvent: () {
      _ref.invalidate(myBlackoutProvider);
      _ref.invalidate(unseenBlackoutsProvider);
    });

    // Pokes arrive addressed to me; reactions come back on rows I sent,
    // so both directions have to be watched.
    _on(channel, 'nudges', column: 'to_user', value: _userId, onEvent: () {
      _ref.invalidate(unseenNudgesProvider);
      _ref.invalidate(myNudgesProvider);
    });
    _on(channel, 'nudges', column: 'from_user', value: _userId,
        onEvent: () => _ref.invalidate(pokeBacksProvider));

    _on(channel, 'duels', column: 'opponent_id', value: _userId, onEvent: () {
      _ref.invalidate(incomingDuelsProvider);
      _ref.invalidate(questDuelsProvider);
    });
    _on(channel, 'duels', column: 'challenger_id', value: _userId,
        onEvent: () {
      _ref.invalidate(questDuelsProvider);
      _ref.invalidate(myChallengesProvider);
    });

    // Somebody wants something from me — a friendship or a quest. Both
    // used to be invisible until the Friends tab happened to be opened,
    // which is exactly the tab you do NOT open when you are unaware that
    // anything is waiting.
    _on(channel, 'friendships', column: 'addressee_id', value: _userId,
        onEvent: () {
      _ref.invalidate(friendRequestsProvider);
      _ref.invalidate(myFriendsProvider);
    });
    // My own request being accepted arrives as an UPDATE on a row where
    // I am the requester, not the addressee — so it needs its own watch.
    _on(channel, 'friendships', column: 'requester_id', value: _userId,
        onEvent: () => _ref.invalidate(myFriendsProvider));

    _on(channel, 'invites', column: 'invitee_id', value: _userId,
        onEvent: () => _ref.invalidate(myInvitesProvider));

    // ── My own standing: aura, strikes, settlement outcomes ──
    _on(channel, 'settlement_events', column: 'user_id', value: _userId,
        onEvent: () {
      _ref.invalidate(settlementEventsProvider);
      _ref.invalidate(myChallengesProvider);
      _ref.invalidate(questActivityProvider);
    });

    _on(channel, 'challenge_participants', column: 'user_id', value: _userId,
        onEvent: () {
      _ref.invalidate(myChallengesProvider);
      _ref.invalidate(homeAgendaProvider);
    });

    // ── Party activity: unfiltered, because these are other people's
    //    rows. RLS still limits them to quests I am actually in. ──────
    _on(channel, 'check_ins', onEvent: () {
      _ref.invalidate(questMembersProvider);
      _ref.invalidate(questActivityProvider);
    });
    _on(channel, 'progress_entries', onEvent: () {
      _ref.invalidate(questMembersProvider);
      _ref.invalidate(questActivityProvider);
    });
    _on(channel, 'slips', onEvent: () {
      _ref.invalidate(questMembersProvider);
      _ref.invalidate(questActivityProvider);
    });

    channel.subscribe((status, error) {
      final live = status == RealtimeSubscribeStatus.subscribed;
      connected.value = live;
      debugPrint('📡 [RealtimeSync] $status${error == null ? '' : ' — $error'}');
      // Coming back after a drop means we may have missed events.
      if (live) _refreshEverything();
    });

    _channel = channel;
  }

  /// Subscribes to every change on [table], optionally narrowed to rows
  /// where [column] equals [value] so the server does the filtering.
  void _on(
    RealtimeChannel channel,
    String table, {
    String? column,
    String? value,
    required void Function() onEvent,
  }) {
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      filter: (column == null || value == null)
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: column,
              value: value,
            ),
      callback: (_) => onEvent(),
    );
  }

  /// Full catch-up — used when the socket (re)connects.
  void _refreshEverything() {
    _ref.invalidate(myChallengesProvider);
    _ref.invalidate(homeAgendaProvider);
    _ref.invalidate(settlementEventsProvider);
    _ref.invalidate(targetedRoastsProvider);
    _ref.invalidate(robbedNoticesProvider);
    _ref.invalidate(unseenNudgesProvider);
    _ref.invalidate(pokeBacksProvider);
    _ref.invalidate(incomingDuelsProvider);
    // Matters for a player who was offline while a lockout started —
    // without this they would keep tapping a button the server refuses,
    // and would never see the notice for one they slept through.
    _ref.invalidate(myBlackoutProvider);
    _ref.invalidate(unseenBlackoutsProvider);
  }

  void dispose() {
    final channel = _channel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
      _channel = null;
    }
    connected.dispose();
  }
}

/// Keeps exactly one [RealtimeSync] alive for the signed-in user and
/// tears it down on logout. Watch it once, high in the widget tree.
final realtimeSyncProvider = Provider<RealtimeSync?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final sync = RealtimeSync(ref, user.id)..start();
  ref.onDispose(sync.dispose);
  return sync;
});
