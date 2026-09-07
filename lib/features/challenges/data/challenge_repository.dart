import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/aura_heist.dart';
import '../domain/benefit.dart';
import '../domain/blackout.dart';
import '../domain/challenge.dart';
import '../domain/duel.dart';
import '../domain/progress_entry.dart';
import '../domain/quest_activity.dart';
import '../domain/quest_member.dart';
import '../domain/settlement.dart';
import '../domain/slip_result.dart';
import '../domain/targeted_roast.dart';
import '../domain/weekly_recap.dart';
import '../../friends/domain/head_to_head.dart';

/// Creates and reads habit challenges + their quest shops.
class ChallengeRepository {
  ChallengeRepository(this._client);

  final SupabaseClient _client;

  /// Every quest the logged-in user still has a seat in, newest first —
  /// including their per-challenge aura.
  ///
  /// Losing does not end membership. A player whose status turned
  /// `failed` or `eliminated` keeps the quest on their list and watches
  /// it play out; only `completed` quests move on to the trophy shelf.
  Future<List<Challenge>> fetchMyActiveChallenges() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      final rows = await _client
          .from('challenge_participants')
          .select('challenge_aura, strikes_used, periods_missed, created_at, '
              'team, status, '
              'challenges('
              'id, creator_id, title, description, duration_days, aura_gain, '
              'aura_penalty, max_strikes, starts_on, checkin_period, '
              'checkins_per_period, mode, goal_type, target_value, unit, '
              'daily_allowance, active_weekdays, '
              'lifecycle, is_endless, started_at, created_at)')
          .eq('user_id', userId)
          .inFilter('status', const ['active', 'failed', 'eliminated'])
          .order('created_at', ascending: false);

      final questIds = rows
          .map((r) =>
              (r['challenges'] as Map<String, dynamic>)['id'] as String)
          .toList();
      if (questIds.isEmpty) return const [];

      // Which of these were checked in TODAY? (RLS → own rows only.)
      final checkedRows = await _client
          .from('check_ins')
          .select('challenge_id')
          .eq('user_id', userId)
          .eq('checked_on', _todayUtc());
      final checkedIds =
          checkedRows.map((r) => r['challenge_id'] as String).toSet();

      // Party size per quest (active members; RLS lets every signed-in
      // user read participant rows, so counts include quest-mates).
      final memberRows = await _client
          .from('challenge_participants')
          .select('challenge_id')
          .inFilter('challenge_id', questIds)
          .eq('status', 'active');
      final membersByQuest = <String, int>{};
      for (final row in memberRows) {
        final id = row['challenge_id'] as String;
        membersByQuest[id] = (membersByQuest[id] ?? 0) + 1;
      }

      // Which UNUSED benefits does the user own per quest? Consumed
      // shields/half-damages are spent and no longer count as gear.
      final purchaseRows = await _client
          .from('benefit_purchases')
          .select('challenge_id, benefits(title)')
          .eq('user_id', userId)
          .inFilter('challenge_id', questIds)
          .isFilter('consumed_at', null);
      final ownedByChallenge = <String, Set<String>>{};
      for (final row in purchaseRows) {
        final title =
            (row['benefits'] as Map<String, dynamic>?)?['title'] as String?;
        if (title == null) continue;
        (ownedByChallenge[row['challenge_id'] as String] ??= {}).add(title);
      }

      // Collect current period start dates across active challenges to prevent
      // PostgREST 1000-row limit truncation from dropping active period entries.
      final currentPeriodStarts = rows
          .map((r) => _dateOnly(Challenge.fromJson(
                  r['challenges'] as Map<String, dynamic>)
              .currentPeriodStart))
          .toSet()
          .toList();

      // Progress quests: how much is logged in the CURRENT period.
      // Constrained to currentPeriodStarts to never hit row truncation.
      final progressRows = await _client
          .from('progress_entries')
          .select('challenge_id, amount, period_start')
          .eq('user_id', userId)
          .inFilter('challenge_id', questIds)
          .inFilter('period_start', currentPeriodStarts);
      final progressByQuest = <String, List<(String, double)>>{};
      for (final row in progressRows) {
        (progressByQuest[row['challenge_id'] as String] ??= []).add((
          row['period_start'] as String,
          (row['amount'] as num).toDouble(),
        ));
      }

      // Avoid quests: how many slips are on the board this period.
      // Constrained to currentPeriodStarts to never hit row truncation.
      final slipRows = await _client
          .from('slips')
          .select('challenge_id, period_start')
          .eq('user_id', userId)
          .inFilter('challenge_id', questIds)
          .inFilter('period_start', currentPeriodStarts);
      final slipsByQuest = <String, List<String>>{};
      for (final row in slipRows) {
        (slipsByQuest[row['challenge_id'] as String] ??= [])
            .add(row['period_start'] as String);
      }

      final result = rows.map((row) {
        final challenge =
            Challenge.fromJson(row['challenges'] as Map<String, dynamic>);
        // Only the entries belonging to the period we are in right now.
        var progress = 0.0;
        if (challenge.isProgress) {
          final current = _dateOnly(challenge.currentPeriodStart);
          for (final (periodStart, amount)
              in progressByQuest[challenge.id] ?? const <(String, double)>[]) {
            if (periodStart == current) progress += amount;
          }
        }
        var slips = 0;
        if (challenge.isAvoid) {
          final current = _dateOnly(challenge.currentPeriodStart);
          for (final periodStart
              in slipsByQuest[challenge.id] ?? const <String>[]) {
            if (periodStart == current) slips++;
          }
        }
        return challenge.copyWith(
          progressInPeriod: progress,
          slipsInPeriod: slips,
          myAura: row['challenge_aura'] as int,
          strikesUsed: row['strikes_used'] as int,
          periodsMissed: row['periods_missed'] as int,
          memberCount: membersByQuest[challenge.id] ?? 1,
          checkedInToday: checkedIds.contains(challenge.id),
          joinedOn: DateTime.parse(row['created_at'] as String).toUtc(),
          myTeam: row['team'] as String?,
          ownedBenefits:
              (ownedByChallenge[challenge.id] ?? const {}).toList()..sort(),
          myStatus: (row['status'] ?? 'active') as String,
        );
      }).toList();
      debugPrint(
          '✅ [ChallengeRepository.fetchMyActiveChallenges] ${result.length} active, '
          '${checkedIds.length} checked in today');
      return result;
    } on PostgrestException catch (e) {
      _log('fetchMyActiveChallenges', e);
      rethrow;
    }
  }

  /// The user's check-ins for MANY quests at once, grouped by quest id
  /// (each inner map: UTC day → check-in timestamp).
  ///
  /// One request for the whole Home dashboard instead of one per quest.
  Future<Map<String, Map<DateTime, DateTime>>> fetchCheckInsForChallenges(
    List<String> challengeIds,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || challengeIds.isEmpty) return const {};

    try {
      final rows = await _client
          .from('check_ins')
          .select('challenge_id, checked_on, created_at')
          .eq('user_id', userId)
          .inFilter('challenge_id', challengeIds);

      final byQuest = <String, Map<DateTime, DateTime>>{};
      for (final row in rows) {
        final questId = row['challenge_id'] as String;
        (byQuest[questId] ??= {})[
                DateTime.parse('${row['checked_on']}T00:00:00Z')] =
            DateTime.parse(row['created_at'] as String);
      }
      debugPrint('✅ [ChallengeRepository.fetchCheckInsForChallenges] '
          '${rows.length} check-ins across ${challengeIds.length} quests');
      return byQuest;
    } on PostgrestException catch (e) {
      _log('fetchCheckInsForChallenges', e);
      rethrow;
    }
  }

  /// Logs today's check-in and adds the gain to THIS challenge's aura —
  /// server-side via `log_check_in` (validates schedule window, strikes
  /// and once-per-day). Returns the aura gained.
  Future<int> logCheckIn(String challengeId) async {
    try {
      final gained = await _client.rpc<int>('log_check_in', params: {
        'p_challenge_id': challengeId,
      });
      debugPrint('✅ [ChallengeRepository.logCheckIn] +$gained aura '
          '(challenge $challengeId)');
      return gained;
    } on PostgrestException catch (e) {
      _log('logCheckIn', e);
      rethrow;
    }
  }

  /// The user's full check-in history for ONE challenge:
  /// UTC day → timestamp of the check-in (for the timeline).
  Future<Map<DateTime, DateTime>> fetchCheckIns(String challengeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const {};

    try {
      final rows = await _client
          .from('check_ins')
          .select('checked_on, created_at')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);
      final map = <DateTime, DateTime>{
        for (final row in rows)
          DateTime.parse('${row['checked_on']}T00:00:00Z'):
              DateTime.parse(row['created_at'] as String),
      };
      debugPrint(
          '✅ [ChallengeRepository.fetchCheckIns] ${map.length} check-ins '
          '(challenge $challengeId)');
      return map;
    } on PostgrestException catch (e) {
      _log('fetchCheckIns', e);
      rethrow;
    }
  }

  /// Creates a challenge (with strikes + custom schedule), joins the
  /// creator and stocks its shop — one atomic `create_challenge` call.
  Future<String> createChallenge({
    required String title,
    required String description,
    required int durationDays,
    required int auraGain,
    required int auraPenalty,
    required int maxStrikes,
    required DateTime startsOn,
    required CheckinPeriod checkinPeriod,
    required int checkinsPerPeriod,
    QuestMode mode = QuestMode.solo,
    GoalType goalType = GoalType.check,
    double? targetValue,
    String? unit,
    bool isEndless = false,
    int dailyAllowance = 0,
    List<int> activeWeekdays = const [1, 2, 3, 4, 5, 6, 7],
  }) async {
    try {
      final id = await _client.rpc<String>('create_challenge', params: {
        'p_title': title,
        'p_description': description,
        'p_duration_days': durationDays,
        'p_aura_gain': auraGain,
        'p_aura_penalty': auraPenalty,
        'p_max_strikes': maxStrikes,
        'p_starts_on': _dateOnly(startsOn),
        'p_checkin_period': checkinPeriod.name,
        'p_checkins_per_period': checkinsPerPeriod,
        'p_mode': mode.dbValue,
        'p_goal_type': goalType.dbValue,
        'p_target_value': targetValue,
        'p_unit': unit,
        'p_is_endless': isEndless,
        'p_daily_allowance': dailyAllowance,
        'p_active_weekdays': activeWeekdays,
      });
      debugPrint(
          '✅ [ChallengeRepository.createChallenge] created "$title" ($id)');
      return id;
    } on PostgrestException catch (e) {
      _log('createChallenge', e);
      rethrow;
    }
  }

  /// The quest's shared activity feed: what every member achieved and
  /// lost in THIS quest, newest first. Merges settlement events,
  /// check-ins and progress entries into one story.
  Future<List<QuestActivity>> fetchQuestActivity(String challengeId) async {
    final myId = _client.auth.currentUser?.id;

    try {
      // Who is in the party (names + avatars for the feed rows).
      final memberRows = await _client
          .from('challenge_participants')
          .select('user_id, profiles(username, avatar_emoji)')
          .eq('challenge_id', challengeId);
      final names = <String, (String, String?)>{};
      for (final row in memberRows) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        if (profile == null) continue;
        names[row['user_id'] as String] = (
          profile['username'] as String,
          profile['avatar_emoji'] as String?,
        );
      }

      final results = await Future.wait([
        _client
            .from('settlement_events')
            .select('user_id, kind, amount, created_at')
            .eq('challenge_id', challengeId)
            .order('created_at', ascending: false)
            .limit(40),
        _client
            .from('check_ins')
            .select('user_id, created_at')
            .eq('challenge_id', challengeId)
            .order('created_at', ascending: false)
            .limit(40),
        _client
            .from('progress_entries')
            .select('user_id, amount, created_at')
            .eq('challenge_id', challengeId)
            .order('created_at', ascending: false)
            .limit(40),
        // Shop purchases — quest mates may read each other's rows.
        _client
            .from('benefit_purchases')
            .select('user_id, created_at, benefits(title)')
            .eq('challenge_id', challengeId)
            .order('created_at', ascending: false)
            .limit(40),
        // Roasts are open to the whole party by design; the burn is
        // meant to be public.
        _client
            .from('targeted_roasts')
            .select('sender_id, target_id, created_at')
            .eq('challenge_id', challengeId)
            .order('created_at', ascending: false)
            .limit(40),
        // Lockouts. RLS hands these out only to attacker and target, so
        // the rest of the party never learns who got hit — deliberate,
        // the item lives off not being seen coming.
        _client
            .from('blackouts')
            .select('attacker_id, target_id, daypart, created_at')
            .eq('challenge_id', challengeId)
            .order('created_at', ascending: false)
            .limit(40),
      ]);

      QuestActivity? build(
        Map<String, dynamic> row,
        String kind,
        num? amount, {
        String userKey = 'user_id',
        String? detail,
      }) {
        final uid = row[userKey] as String;
        final who = names[uid];
        if (who == null) return null; // left the quest
        return QuestActivity(
          kind: kind,
          username: who.$1,
          avatarEmoji: who.$2,
          isMe: uid == myId,
          amount: amount,
          detail: detail,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }

      final feed = <QuestActivity>[];
      void addAll(List<Map<String, dynamic>> rows,
          QuestActivity? Function(Map<String, dynamic>) map) {
        for (final row in rows) {
          final item = map(row);
          if (item != null) feed.add(item);
        }
      }

      addAll(results[0],
          (r) => build(r, r['kind'] as String, r['amount'] as num?));
      addAll(results[1], (r) => build(r, 'check_in', null));
      addAll(results[2], (r) => build(r, 'progress', r['amount'] as num?));
      addAll(
          results[3],
          (r) => build(r, 'purchase', null,
              detail: (r['benefits'] as Map<String, dynamic>?)?['title']
                  as String?));
      // Roasts and blackouts are attributed to the ATTACKER; the detail
      // names who caught it, so the row reads "@a roasted @b".
      addAll(
          results[4],
          (r) => build(r, 'roast', null,
              userKey: 'sender_id',
              detail: names[r['target_id'] as String]?.$1));
      addAll(
          results[5],
          (r) => build(r, 'blackout', null,
              userKey: 'attacker_id',
              detail: names[r['target_id'] as String]?.$1));
      feed.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final trimmed = feed.take(60).toList();
      debugPrint('✅ [ChallengeRepository.fetchQuestActivity] '
          '${trimmed.length} entries (challenge $challengeId)');
      return trimmed;
    } on PostgrestException catch (e) {
      _log('fetchQuestActivity', e);
      rethrow;
    }
  }

  /// Kicks a lobby quest into gear (creator only, server-enforced).
  /// Freezes the roster and starts the clock today.
  Future<void> startQuest(String challengeId) async {
    try {
      await _client
          .rpc<void>('start_quest', params: {'p_challenge_id': challengeId});
      debugPrint('✅ [ChallengeRepository.startQuest] started $challengeId');
    } on PostgrestException catch (e) {
      _log('startQuest', e);
      rethrow;
    }
  }

  /// Logs a partial amount towards a progress quest's target. The
  /// server adds it up and, once the target is met, records the real
  /// check-in (aura, streaks, settlement) on its own.
  Future<ProgressResult> addProgress({
    required String challengeId,
    required double amount,
  }) async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>('add_progress',
          params: {'p_challenge_id': challengeId, 'p_amount': amount});
      final result = ProgressResult.fromJson(json);
      debugPrint('✅ [ChallengeRepository.addProgress] +$amount → '
          '${result.total}/${result.target} (done: ${result.completed})');
      return result;
    } on PostgrestException catch (e) {
      _log('addProgress', e);
      rethrow;
    }
  }

  /// Corrects a mistyped entry: sets one of the user's OWN entries in
  /// the current period to [amount]. The server refuses if it would drop
  /// an already-completed period back below its goal.
  Future<ProgressResult> editProgressEntry({
    required String entryId,
    required double amount,
  }) async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>(
          'edit_progress_entry',
          params: {'p_entry_id': entryId, 'p_amount': amount});
      // edit/delete return total/target/completed but no overshoot/gained.
      final result = ProgressResult.fromJson({
        'overshoot': false,
        'gained': null,
        ...json,
      });
      debugPrint('✅ [ChallengeRepository.editProgressEntry] '
          '$entryId → $amount (total ${result.total})');
      return result;
    } on PostgrestException catch (e) {
      _log('editProgressEntry', e);
      rethrow;
    }
  }

  /// Removes one of the user's OWN entries in the current period. Same
  /// guard as [editProgressEntry].
  Future<ProgressResult> deleteProgressEntry({required String entryId}) async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>(
          'delete_progress_entry',
          params: {'p_entry_id': entryId});
      final result = ProgressResult.fromJson({
        'overshoot': false,
        'gained': null,
        ...json,
      });
      debugPrint('✅ [ChallengeRepository.deleteProgressEntry] '
          '$entryId (total ${result.total})');
      return result;
    } on PostgrestException catch (e) {
      _log('deleteProgressEntry', e);
      rethrow;
    }
  }

  /// Every progress entry the user logged in this quest, newest first —
  /// the raw material for the history on the detail screen.
  Future<List<ProgressEntry>> fetchProgressEntries(String challengeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      final rows = await _client
          .from('progress_entries')
          .select('id, amount, period_start, created_at')
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final entries = rows.map(ProgressEntry.fromJson).toList();
      debugPrint('✅ [ChallengeRepository.fetchProgressEntries] '
          '${entries.length} entries (challenge $challengeId)');
      return entries;
    } on PostgrestException catch (e) {
      _log('fetchProgressEntries', e);
      rethrow;
    }
  }

  /// This challenge's shop stock, with `owned` filled in from the
  /// user's purchases.
  Future<List<Benefit>> fetchBenefits(String challengeId) async {
    try {
      final rows = await _client
          .from('benefits')
          .select('id, challenge_id, title, description, cost')
          .eq('challenge_id', challengeId)
          .order('cost', ascending: true); // cheapest first

      // Own purchases in this challenge, split into ready vs consumed.
      final userId = _client.auth.currentUser?.id;
      final purchases = await _client
          .from('benefit_purchases')
          .select('benefit_id, consumed_at')
          .eq('challenge_id', challengeId)
          .eq('user_id', userId ?? '');
      final ready = <String, int>{};
      final used = <String, int>{};
      for (final row in purchases) {
        final id = row['benefit_id'] as String;
        if (row['consumed_at'] == null) {
          ready[id] = (ready[id] ?? 0) + 1;
        } else {
          used[id] = (used[id] ?? 0) + 1;
        }
      }

      final benefits = rows
          .map((r) => Benefit.fromJson(r).copyWith(
                readyCount: ready[r['id'] as String] ?? 0,
                usedCount: used[r['id'] as String] ?? 0,
              ))
          .toList();

      debugPrint('✅ [ChallengeRepository.fetchBenefits] '
          '${benefits.length} benefits, ${purchases.length} purchases');
      return benefits;
    } on PostgrestException catch (e) {
      _log('fetchBenefits', e);
      rethrow;
    }
  }

  /// Buys a benefit from THIS challenge's aura via `purchase_benefit`
  /// (server checks participation + balance, deducts, links the
  /// purchase — one transaction). Returns the new challenge balance.
  Future<int> purchaseBenefit(String benefitId) async {
    try {
      final newBalance = await _client.rpc<int>('purchase_benefit', params: {
        'p_benefit_id': benefitId,
      });
      debugPrint('✅ [ChallengeRepository.purchaseBenefit] bought $benefitId '
          '— new balance: $newBalance');
      return newBalance;
    } on PostgrestException catch (e) {
      _log('purchaseBenefit', e);
      rethrow;
    }
  }

  /// The quest's party: all active members with their check-in status
  /// for the CURRENT period, quest aura and owned gear. Sorted by
  /// quest aura (mini leaderboard).
  Future<List<QuestMember>> fetchQuestMembers(Challenge challenge) async {
    final myId = _client.auth.currentUser?.id;

    try {
      // Everyone who ever took a seat stays on the roster, greyed out
      // once they are out of the running. Used to be Last Man Standing
      // only; now it holds for every mode, because losing no longer
      // removes anyone from a quest.
      final rows = await _client
          .from('challenge_participants')
          .select('user_id, challenge_aura, team, status, '
              'profiles(username, avatar_emoji)')
          .eq('challenge_id', challenge.id)
          .order('challenge_aura', ascending: false);

      // Current period bounds (anchored to starts_on, like the server).
      final today = _parseDay(_todayUtc());
      final start = DateTime.utc(challenge.startsOn.year,
          challenge.startsOn.month, challenge.startsOn.day);
      final len = challenge.checkinPeriod.lengthDays;
      final daysIn = today.difference(start).inDays;
      final periodStart =
          start.add(Duration(days: daysIn < 0 ? 0 : (daysIn ~/ len) * len));
      var periodEnd = periodStart.add(Duration(days: len));
      final endExclusive = start.add(Duration(days: challenge.durationDays));
      if (periodEnd.isAfter(endExclusive)) periodEnd = endExclusive;
      final target = challenge.checkinPeriod == CheckinPeriod.daily
          ? 1
          : challenge.checkinsPerPeriod;

      // Everyone's check-ins over the WHOLE quest (quest-mates may
      // see each other since the social migration). One query feeds
      // both the current-period status and the versus scoreboard.
      final checkRows = await _client
          .from('check_ins')
          .select('user_id, checked_on')
          .eq('challenge_id', challenge.id);
      final countByUser = <String, int>{};
      final totalByUser = <String, int>{};
      final todayByUser = <String>{};
      final periodStartStr = _dateOnly(periodStart);
      final periodEndStr = _dateOnly(periodEnd);
      for (final row in checkRows) {
        final uid = row['user_id'] as String;
        final day = row['checked_on'] as String;
        totalByUser[uid] = (totalByUser[uid] ?? 0) + 1;
        // Date-only ISO strings compare correctly as strings.
        if (day.compareTo(periodStartStr) >= 0 &&
            day.compareTo(periodEndStr) < 0) {
          countByUser[uid] = (countByUser[uid] ?? 0) + 1;
        }
        if (day == _todayUtc()) todayByUser.add(uid);
      }

      // Everyone's progress in the CURRENT period (progress quests) —
      // the party is meant to see each other's numbers.
      final progressByUser = <String, double>{};
      if (challenge.isProgress) {
        final progressRows = await _client
            .from('progress_entries')
            .select('user_id, amount')
            .eq('challenge_id', challenge.id)
            .eq('period_start', _dateOnly(challenge.currentPeriodStart));
        for (final row in progressRows) {
          final uid = row['user_id'] as String;
          progressByUser[uid] =
              (progressByUser[uid] ?? 0) + (row['amount'] as num).toDouble();
        }
      }

      // When did each member last put something on the board? A counting
      // quest is fed by progress entries, everything else by check-ins —
      // the same split the Blackout item follows.
      final lastByUser = <String, DateTime>{};
      final activityRows = await _client
          .from(challenge.isProgress ? 'progress_entries' : 'check_ins')
          .select('user_id, created_at')
          .eq('challenge_id', challenge.id)
          .order('created_at', ascending: false);
      for (final row in activityRows) {
        final uid = row['user_id'] as String;
        // Rows arrive newest first, so the first hit per member wins.
        lastByUser.putIfAbsent(
            uid, () => DateTime.parse(row['created_at'] as String).toUtc());
      }

      // Everyone's gear in this quest.
      final purchaseRows = await _client
          .from('benefit_purchases')
          .select('user_id, benefits(title)')
          .eq('challenge_id', challenge.id);
      final gearByUser = <String, Set<String>>{};
      for (final row in purchaseRows) {
        final title =
            (row['benefits'] as Map<String, dynamic>?)?['title'] as String?;
        if (title == null) continue;
        (gearByUser[row['user_id'] as String] ??= {}).add(title);
      }

      final members = rows.map((row) {
        final uid = row['user_id'] as String;
        final count = countByUser[uid] ?? 0;
        final profile = row['profiles'] as Map<String, dynamic>;
        return QuestMember(
          userId: uid,
          username: profile['username'] as String,
          avatarEmoji: profile['avatar_emoji'] as String?,
          questAura: row['challenge_aura'] as int,
          isOwner: uid == challenge.creatorId,
          isMe: uid == myId,
          checkedToday: todayByUser.contains(uid),
          doneThisPeriod: count >= target,
          checkinsThisPeriod: count,
          gear: (gearByUser[uid] ?? const {}).toList()..sort(),
          team: row['team'] as String?,
          totalCheckins: totalByUser[uid] ?? 0,
          progressInPeriod: progressByUser[uid] ?? 0,
          status: (row['status'] ?? 'active') as String,
          lastActivityAt: lastByUser[uid],
        );
      }).toList();
      debugPrint('✅ [ChallengeRepository.fetchQuestMembers] '
          '${members.length} members (challenge ${challenge.id})');
      return members;
    } on PostgrestException catch (e) {
      _log('fetchQuestMembers', e);
      rethrow;
    }
  }

  /// Invites a player (by username) into the quest via the
  /// `invite_to_challenge` RPC. Server validates membership,
  /// existence and duplicates - errors carry readable messages.
  Future<void> inviteToChallenge({
    required String challengeId,
    required String username,
  }) async {
    try {
      await _client.rpc<String>('invite_to_challenge', params: {
        'p_challenge_id': challengeId,
        'p_username': username,
      });
      debugPrint('✅ [ChallengeRepository.inviteToChallenge] '
          'invited "$username" to $challengeId');
    } on PostgrestException catch (e) {
      _log('inviteToChallenge', e);
      rethrow;
    }
  }

  /// Pokes a quest-mate (max once per day, enforced server-side).
  /// Lands in their in-app pokes inbox on the Friends tab.
  Future<void> nudgeParticipant({
    required String challengeId,
    required String userId,
  }) async {
    try {
      await _client.rpc<void>('nudge_participant', params: {
        'p_challenge_id': challengeId,
        'p_to_user': userId,
      });
      debugPrint('✅ [ChallengeRepository.nudgeParticipant] '
          'nudged $userId in $challengeId');
    } on PostgrestException catch (e) {
      _log('nudgeParticipant', e);
      rethrow;
    }
  }

  static DateTime _parseDay(String yyyyMmDd) =>
      DateTime.parse('${yyyyMmDd}T00:00:00Z');

  /// Abandons a quest via the `leave_challenge` RPC: removes the user
  /// and, if they owned the quest, hands the crown to the
  /// longest-standing remaining member — one transaction.
  ///
  /// Returns the new owner's username, or null when there was no
  /// handover (not the owner, or nobody left behind).
  Future<String?> leaveChallenge(String challengeId) async {
    try {
      final newOwner = await _client.rpc<String?>('leave_challenge',
          params: {'p_challenge_id': challengeId});
      debugPrint('✅ [ChallengeRepository.leaveChallenge] left $challengeId'
          '${newOwner == null ? '' : ' — new owner: $newOwner'}');
      return newOwner;
    } on PostgrestException catch (e) {
      _log('leaveChallenge', e);
      rethrow;
    }
  }

  /// Challenges a quest-mate to a dice duel. The stake goes into
  /// escrow immediately; guardrails (min 10, max 25% of aura, one
  /// open duel per pair) are enforced server-side.
  Future<void> createDuel({
    required String challengeId,
    required String opponentId,
    required int stake,
  }) async {
    try {
      await _client.rpc<String>('create_duel', params: {
        'p_challenge_id': challengeId,
        'p_opponent_id': opponentId,
        'p_stake': stake,
      });
      debugPrint('✅ [ChallengeRepository.createDuel] '
          'staked $stake vs $opponentId');
    } on PostgrestException catch (e) {
      _log('createDuel', e);
      rethrow;
    }
  }

  /// Duels waiting for the user's answer, newest first.
  Future<List<IncomingDuel>> fetchIncomingDuels() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      final rows = await _client
          .from('duels')
          .select('id, stake, created_at, challenges(title), '
              'challenger:profiles!duels_challenger_id_fkey'
              '(username, avatar_emoji)')
          .eq('opponent_id', userId)
          .eq('status', 'pending')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false);

      final duels = rows.map((row) {
        final challenger = row['challenger'] as Map<String, dynamic>;
        return IncomingDuel(
          id: row['id'] as String,
          questTitle:
              (row['challenges'] as Map<String, dynamic>)['title'] as String,
          challengerName: challenger['username'] as String,
          challengerAvatar: challenger['avatar_emoji'] as String?,
          stake: row['stake'] as int,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();
      debugPrint(
          '✅ [ChallengeRepository.fetchIncomingDuels] ${duels.length} pending');
      return duels;
    } on PostgrestException catch (e) {
      _log('fetchIncomingDuels', e);
      rethrow;
    }
  }

  /// The duel history of ONE quest, seen by the logged-in user
  /// (RLS already limits rows to duels they are part of).
  Future<List<QuestDuel>> fetchQuestDuels(String challengeId) async {
    if (_client.auth.currentUser == null) return const [];

    try {
      final rows = await _client
          .from('duels')
          .select('id, challenger_id, opponent_id, stake, status, '
              'challenger_d1, challenger_d2, opponent_d1, opponent_d2, '
              'winner_id, created_at, '
              'challenger:profiles!duels_challenger_id_fkey'
              '(username, avatar_emoji), '
              'opponent:profiles!duels_opponent_id_fkey'
              '(username, avatar_emoji)')
          .eq('challenge_id', challengeId)
          .order('created_at', ascending: false)
          .limit(20);

      final duels = rows.map((row) {
        final challenger = row['challenger'] as Map<String, dynamic>;
        final opponent = row['opponent'] as Map<String, dynamic>;
        final resolved = row['status'] == 'resolved';
        return QuestDuel(
          id: row['id'] as String,
          challengerId: row['challenger_id'] as String,
          challengerName: challenger['username'] as String,
          challengerAvatar: challenger['avatar_emoji'] as String?,
          opponentId: row['opponent_id'] as String,
          opponentName: opponent['username'] as String,
          opponentAvatar: opponent['avatar_emoji'] as String?,
          stake: row['stake'] as int,
          status: row['status'] as String,
          challengerDice: resolved
              ? [row['challenger_d1'] as int, row['challenger_d2'] as int]
              : null,
          opponentDice: resolved
              ? [row['opponent_d1'] as int, row['opponent_d2'] as int]
              : null,
          winnerId: row['winner_id'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();
      debugPrint(
          '✅ [ChallengeRepository.fetchQuestDuels] ${duels.length} duels');
      return duels;
    } on PostgrestException catch (e) {
      _log('fetchQuestDuels', e);
      rethrow;
    }
  }

  /// Accepts (server rolls, returns the result) or declines (refunds
  /// the challenger; returns null).
  Future<DuelResult?> respondToDuel({
    required String duelId,
    required bool accept,
  }) async {
    try {
      final json = await _client
          .rpc<Map<String, dynamic>>('respond_to_duel', params: {
        'p_duel_id': duelId,
        'p_accept': accept,
      });
      debugPrint('✅ [ChallengeRepository.respondToDuel] '
          '$duelId → ${json['status']}');
      if (json['status'] != 'resolved') return null;
      return DuelResult.fromJson(json);
    } on PostgrestException catch (e) {
      _log('respondToDuel', e);
      rethrow;
    }
  }

  /// The user's recent settlement events (penalties, strikes, saves,
  /// completions) — what the engine did while they were away.
  Future<List<SettlementEvent>> fetchRecentEvents() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      final rows = await _client
          .from('settlement_events')
          .select('kind, amount, challenge_id, period_start, created_at, '
              'challenges(title)')
          .eq('user_id', userId)
          .gte('created_at',
              DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String())
          .order('created_at', ascending: false)
          .limit(15);

      final events = rows
          .map((row) => SettlementEvent(
                kind: row['kind'] as String,
                amount: row['amount'] as int?,
                challengeId: row['challenge_id'] as String,
                questTitle: (row['challenges']
                    as Map<String, dynamic>)['title'] as String,
                createdAt: DateTime.parse(row['created_at'] as String),
              ))
          .toList();
      debugPrint(
          '✅ [ChallengeRepository.fetchRecentEvents] ${events.length} events');
      return events;
    } on PostgrestException catch (e) {
      _log('fetchRecentEvents', e);
      rethrow;
    }
  }

  /// Removes one finished quest from the user's trophy room. A soft
  /// hide — the participation row stays so team scoring and the other
  /// players' history are untouched.
  Future<void> hideTrophy(String challengeId) async {
    try {
      await _client
          .rpc<void>('hide_trophy', params: {'p_challenge_id': challengeId});
      debugPrint('✅ [ChallengeRepository.hideTrophy] hid $challengeId');
    } on PostgrestException catch (e) {
      _log('hideTrophy', e);
      rethrow;
    }
  }

  /// Finished quests for the trophy room: completed (and failed)
  /// participations with their frozen aura.
  Future<List<Trophy>> fetchTrophies() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      final rows = await _client
          .from('challenge_participants')
          .select('challenge_id, status, challenge_aura, periods_missed, '
              'finished_at, challenges(title)')
          .eq('user_id', userId)
          .inFilter('status', ['completed', 'failed'])
          // Entries the user removed from their room stay out of it.
          .isFilter('trophy_hidden_at', null)
          .order('finished_at', ascending: false);

      final trophies = rows
          .map((row) => Trophy(
                challengeId: row['challenge_id'] as String,
                questTitle: (row['challenges']
                    as Map<String, dynamic>)['title'] as String,
                finalAura: row['challenge_aura'] as int,
                completed: row['status'] == 'completed',
                perfect: row['status'] == 'completed' &&
                    (row['periods_missed'] as int) == 0,
                finishedAt: row['finished_at'] == null
                    ? null
                    : DateTime.parse(row['finished_at'] as String),
              ))
          .toList();
      debugPrint(
          '✅ [ChallengeRepository.fetchTrophies] ${trophies.length} trophies');
      return trophies;
    } on PostgrestException catch (e) {
      _log('fetchTrophies', e);
      rethrow;
    }
  }

  // ── Targeted Roasts ──────────────────────────────────────────

  /// Buys and fires a targeted roast via `send_targeted_roast` (server
  /// checks membership + balance, deducts aura, creates the roast — one
  /// transaction). Returns the sender's new challenge balance.
  Future<int> sendTargetedRoast({
    required String challengeId,
    required String targetId,
    required String roastText,
    required int durationSeconds,
  }) async {
    try {
      final newBalance =
          await _client.rpc<int>('send_targeted_roast', params: {
        'p_challenge_id': challengeId,
        'p_target_id': targetId,
        'p_roast_text': roastText,
        'p_duration_seconds': durationSeconds,
      });
      debugPrint('✅ [ChallengeRepository.sendTargetedRoast] '
          '→ $targetId (${durationSeconds}s), ⚡$newBalance left');
      return newBalance;
    } on PostgrestException catch (e) {
      _log('sendTargetedRoast', e);
      rethrow;
    }
  }

  /// Roasts aimed at the current user that were not dismissed yet —
  /// what the home banner and the lock screens key off.
  Future<List<TargetedRoast>> fetchUnacknowledgedTargetedRoasts() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      final rows = await _client
          .from('targeted_roasts')
          .select('*, sender:profiles!sender_id(username)')
          .eq('target_id', userId)
          .isFilter('acknowledged_at', null)
          .order('created_at', ascending: true);
      return rows.map(TargetedRoast.fromJson).toList();
    } on PostgrestException catch (e) {
      _log('fetchUnacknowledgedTargetedRoasts', e);
      rethrow;
    }
  }

  /// Marks a targeted roast as acknowledged by the victim (the lock
  /// countdown has run out and they dismissed it).
  Future<void> acknowledgeTargetedRoast(String roastId) async {
    try {
      await _client
          .from('targeted_roasts')
          .update({'acknowledged_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', roastId);
    } on PostgrestException catch (e) {
      _log('acknowledgeTargetedRoast', e);
    }
  }

  // ── Negative ("avoid") quests ──────────────────────────────────

  /// Records one slip. The server decides whether it still fits inside
  /// the period's allowance or breaks it (penalty + strike right away).
  Future<SlipResult> logSlip(String challengeId) async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>('log_slip',
          params: {'p_challenge_id': challengeId});
      final result = SlipResult.fromJson(json);
      debugPrint('✅ [ChallengeRepository.logSlip] $challengeId → '
          '${result.count}/${result.allowance} (over: ${result.over})');
      return result;
    } on PostgrestException catch (e) {
      _log('logSlip', e);
      rethrow;
    }
  }

  /// Takes back the most recent slip of the current period. Refused once
  /// the period already broke its limit — that consequence is booked.
  Future<SlipResult> undoLastSlip(String challengeId) async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>('undo_last_slip',
          params: {'p_challenge_id': challengeId});
      return SlipResult.fromJson({
        'just_failed': false,
        'struck': false,
        'shielded': false,
        'aura': 0,
        ...json,
      });
    } on PostgrestException catch (e) {
      _log('undoLastSlip', e);
      rethrow;
    }
  }

  // ── Aura Heist ─────────────────────────────────────────────────

  /// Buys and rolls an Aura Heist against a quest mate via
  /// `attempt_aura_heist`. The roll is server-side; the result says
  /// whether the hit landed (a hit waits for the victim's next check-in).
  Future<AuraHeistResult> attemptAuraHeist({
    required String challengeId,
    required String targetId,
    required int cost,
  }) async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>(
          'attempt_aura_heist',
          params: {
            'p_challenge_id': challengeId,
            'p_target_id': targetId,
            'p_cost': cost,
          });
      final result = AuraHeistResult.fromJson(json);
      debugPrint('✅ [ChallengeRepository.attemptAuraHeist] '
          '→ $targetId ($cost) hit=${result.succeeded}');
      return result;
    } on PostgrestException catch (e) {
      _log('attemptAuraHeist', e);
      rethrow;
    }
  }

  /// Buys a Blackout and arms it on [targetId] for the next [daypart]
  /// window in THEIR local time. The server does the whole calculation;
  /// the client never sends a timestamp.
  // ── Erinnerungen ─────────────────────────────────────────────────

  /// The reminder time this player set for this quest, or null.
  ///
  /// Returns a plain hour/minute pair rather than a TimeOfDay: that is a
  /// widget-layer type, and the data layer has no business importing the
  /// UI framework.
  ///
  /// Read straight from the table rather than through an RPC: row level
  /// security already limits it to the caller's own rows, so a function
  /// would add a layer without adding a rule.
  Future<({int hour, int minute})?> fetchQuestReminder(
      String challengeId) async {
    try {
      final rows = await _client
          .from('quest_reminders')
          .select('remind_at, enabled')
          .eq('challenge_id', challengeId)
          .limit(1);
      if (rows.isEmpty) return null;
      final row = rows.first;
      if (row['enabled'] != true) return null;
      // Postgres liefert "HH:MM:SS".
      final parts = (row['remind_at'] as String).split(':');
      return (hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } on PostgrestException catch (e) {
      _log('fetchQuestReminder', e);
      return null;
    }
  }

  /// Every reminder this player has, keyed by quest id.
  ///
  /// One query for the whole list — the settings screen shows all quests
  /// at once, and asking per quest would be a request per row.
  Future<Map<String, ({int hour, int minute})>> fetchQuestReminders() async {
    try {
      final rows = await _client
          .from('quest_reminders')
          .select('challenge_id, remind_at, enabled');
      final out = <String, ({int hour, int minute})>{};
      for (final row in rows) {
        if (row['enabled'] != true) continue;
        final parts = (row['remind_at'] as String).split(':');
        out[row['challenge_id'] as String] =
            (hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      debugPrint('✅ [ChallengeRepository.fetchQuestReminders] ${out.length} set');
      return out;
    } on PostgrestException catch (e) {
      _log('fetchQuestReminders', e);
      return const {};
    }
  }

  Future<void> setQuestReminder({
    required String challengeId,
    required int hour,
    required int minute,
  }) async {
    final value = '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:00';
    await _client.rpc<void>('set_quest_reminder', params: {
      'p_challenge_id': challengeId,
      'p_remind_at': value,
    });
    debugPrint('✅ [ChallengeRepository.setQuestReminder] $challengeId → $value');
  }

  Future<void> clearQuestReminder(String challengeId) async {
    await _client.rpc<void>('clear_quest_reminder', params: {
      'p_challenge_id': challengeId,
    });
    debugPrint('✅ [ChallengeRepository.clearQuestReminder] $challengeId');
  }

  Future<Blackout> castBlackout({
    required String challengeId,
    required String targetId,
    required String daypart,
  }) async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>(
        'cast_blackout',
        params: {
          'p_challenge_id': challengeId,
          'p_target_id': targetId,
          'p_daypart': daypart,
        },
      );
      debugPrint('✅ [ChallengeRepository.castBlackout] → $targetId '
          '($daypart, ${json['starts_at']})');
      return Blackout(
        id: '',
        challengeId: challengeId,
        attackerId: _client.auth.currentUser?.id ?? '',
        targetId: targetId,
        daypart: daypart,
        startsAt: DateTime.parse(json['starts_at'] as String).toUtc(),
        endsAt: DateTime.parse(json['ends_at'] as String).toUtc(),
        cost: json['cost'] as int,
        attackerName: null,
      );
    } on PostgrestException catch (e) {
      _log('castBlackout', e);
      rethrow;
    }
  }

  /// The lockout currently running on ME in this quest, if any.
  ///
  /// RLS only hands out rows where the caller is attacker or target, so
  /// nobody can scout who is about to be hit.
  Future<Blackout?> fetchMyBlackout(String challengeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final rows = await _client
          .from('blackouts')
          .select('*, profiles!attacker_id(username)')
          .eq('challenge_id', challengeId)
          .eq('target_id', userId)
          .lte('starts_at', nowIso)
          .gt('ends_at', nowIso)
          .order('ends_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return Blackout.fromJson(rows.first);
    } on PostgrestException catch (e) {
      _log('fetchMyBlackout', e);
      rethrow;
    }
  }

  /// Lockouts aimed at me that have already STARTED and that I have
  /// never seen — the ones I slept through.
  ///
  /// Without this a player who was offline for the whole two hours never
  /// learns it happened; they just find a missed day and no explanation.
  Future<List<Blackout>> fetchUnseenBlackouts() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    try {
      final rows = await _client
          .from('blackouts')
          .select('*, attacker:profiles!attacker_id(username), '
              'challenges(title)')
          .eq('target_id', userId)
          .lte('starts_at', DateTime.now().toUtc().toIso8601String())
          .isFilter('acknowledged_at', null)
          .order('starts_at', ascending: true);
      return rows.map(Blackout.fromJson).toList();
    } on PostgrestException catch (e) {
      _log('fetchUnseenBlackouts', e);
      rethrow;
    }
  }

  /// Marks the lockout notices in this quest as seen.
  Future<void> ackBlackouts(String challengeId) async {
    try {
      await _client.rpc<void>('ack_blackouts',
          params: {'p_challenge_id': challengeId});
    } on PostgrestException catch (e) {
      _log('ackBlackouts', e);
    }
  }

  /// Reports the device's UTC offset so the server can put a Blackout
  /// into the right slice of THIS player's day. Failures are swallowed —
  /// a wrong offset is a nuisance, a crash on startup is not acceptable.
  Future<void> reportTimezone() async {
    try {
      final minutes = DateTime.now().timeZoneOffset.inMinutes;
      await _client
          .rpc<void>('set_my_timezone', params: {'p_offset_minutes': minutes});
      debugPrint('✅ [ChallengeRepository.reportTimezone] UTC${minutes >= 0 ? '+' : ''}$minutes min');
    } catch (e) {
      debugPrint('⚠️ [ChallengeRepository.reportTimezone] $e');
    }
  }

  /// Every day the user logged something, across ALL quests, for the
  /// last year — the source for the contribution grid on the profile.
  ///
  /// Returns UTC day → how many things were logged that day (check-ins
  /// and progress entries together), so a busy day reads darker.
  Future<Map<DateTime, int>> fetchActivityByDay({int days = 365}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const {};

    final from = DateTime.now().toUtc().subtract(Duration(days: days));
    final fromDay = _dateOnly(from);

    try {
      final results = await Future.wait([
        _client
            .from('check_ins')
            .select('checked_on')
            .eq('user_id', userId)
            .gte('checked_on', fromDay),
        _client
            .from('progress_entries')
            .select('created_at')
            .eq('user_id', userId)
            .gte('created_at', from.toIso8601String()),
      ]);

      final byDay = <DateTime, int>{};
      void bump(DateTime day) {
        final key = DateTime.utc(day.year, day.month, day.day);
        byDay[key] = (byDay[key] ?? 0) + 1;
      }

      for (final row in results[0]) {
        bump(DateTime.parse('${row['checked_on']}T00:00:00Z'));
      }
      for (final row in results[1]) {
        bump(DateTime.parse(row['created_at'] as String).toUtc());
      }

      debugPrint('✅ [ChallengeRepository.fetchActivityByDay] '
          '${byDay.length} active days');
      return byDay;
    } on PostgrestException catch (e) {
      _log('fetchActivityByDay', e);
      rethrow;
    }
  }

  /// The numbers for the last COMPLETED week (Monday–Sunday, UTC).
  ///
  /// Everything is read for that fixed window, plus the same count for
  /// the week before so the card can show a direction of travel.
  Future<WeeklyRecap?> fetchWeeklyRecap() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    // Monday of the current week, then step back one week: we only ever
    // report a week that is fully in the past.
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final start = thisMonday.subtract(const Duration(days: 7));
    final end = thisMonday; // exclusive
    final prevStart = start.subtract(const Duration(days: 7));

    try {
      final results = await Future.wait([
        _client
            .from('check_ins')
            .select('checked_on')
            .eq('user_id', userId)
            .gte('checked_on', _dateOnly(prevStart))
            .lt('checked_on', _dateOnly(end)),
        _client
            .from('progress_entries')
            .select('created_at')
            .eq('user_id', userId)
            .gte('created_at', prevStart.toIso8601String())
            .lt('created_at', end.toIso8601String()),
        _client
            .from('settlement_events')
            .select('kind, amount, created_at')
            .eq('user_id', userId)
            .gte('created_at', start.toIso8601String())
            .lt('created_at', end.toIso8601String()),
        _client
            .from('duels')
            .select('challenger_id, opponent_id, winner_id, resolved_at')
            .not('winner_id', 'is', null)
            .gte('resolved_at', start.toIso8601String())
            .lt('resolved_at', end.toIso8601String()),
      ]);

      // ── Logged activity, split into last week and the one before ──
      var checkIns = 0;
      var previous = 0;
      final perDay = <DateTime, int>{};

      void count(DateTime day) {
        final d = DateTime.utc(day.year, day.month, day.day);
        if (!d.isBefore(start) && d.isBefore(end)) {
          checkIns++;
          perDay[d] = (perDay[d] ?? 0) + 1;
        } else if (!d.isBefore(prevStart) && d.isBefore(start)) {
          previous++;
        }
      }

      for (final row in results[0]) {
        count(DateTime.parse('${row['checked_on']}T00:00:00Z'));
      }
      for (final row in results[1]) {
        count(DateTime.parse(row['created_at'] as String).toUtc());
      }

      // ── What the settlement engine handed out ─────────────────────
      var gained = 0;
      var lost = 0;
      var strikes = 0;
      var finished = 0;
      for (final row in results[2]) {
        final kind = row['kind'] as String;
        final amount = (row['amount'] as int?) ?? 0;
        if (kind == 'strike') strikes++;
        if (kind == 'completed') finished++;
        if (amount > 0) {
          gained += amount;
        } else {
          lost += amount.abs();
        }
      }

      var duelsWon = 0;
      var duelsLost = 0;
      for (final row in results[3]) {
        final challenger = row['challenger_id'] as String?;
        final opponent = row['opponent_id'] as String?;
        if (challenger != userId && opponent != userId) continue;
        if (row['winner_id'] == userId) {
          duelsWon++;
        } else {
          duelsLost++;
        }
      }

      DateTime? bestDay;
      var bestCount = 0;
      perDay.forEach((day, n) {
        if (n > bestCount) {
          bestCount = n;
          bestDay = day;
        }
      });

      final recap = WeeklyRecap(
        weekStart: start,
        weekEnd: end.subtract(const Duration(days: 1)),
        checkIns: checkIns,
        activeDays: perDay.length,
        auraGained: gained,
        auraLost: lost,
        strikes: strikes,
        questsFinished: finished,
        duelsWon: duelsWon,
        duelsLost: duelsLost,
        previousCheckIns: previous,
        bestDay: bestDay,
        bestDayCount: bestCount,
      );
      debugPrint('✅ [ChallengeRepository.fetchWeeklyRecap] '
          '${recap.checkIns} logged, ${recap.activeDays} active days');
      return recap;
    } on PostgrestException catch (e) {
      _log('fetchWeeklyRecap', e);
      rethrow;
    }
  }

  /// The running score against one friend, over the quests they share.
  ///
  /// Quest-mates may read each other's participant rows and check-ins,
  /// so this needs no privileged access — but it is scoped to shared
  /// quests, which is also the only place the comparison means anything.
  Future<HeadToHead> fetchHeadToHead({
    required String friendId,
    required String username,
    String? avatarEmoji,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final empty = HeadToHead(
      friendId: friendId,
      username: username,
      avatarEmoji: avatarEmoji,
      sharedQuests: 0,
      myCheckIns: 0,
      theirCheckIns: 0,
      myAura: 0,
      theirAura: 0,
      duelsWon: 0,
      duelsLost: 0,
    );
    if (userId == null) return empty;

    try {
      // Which quests are we both in?
      final rows = await _client
          .from('challenge_participants')
          .select('challenge_id, user_id, challenge_aura')
          .inFilter('user_id', [userId, friendId]);

      final mine = <String, int>{};
      final theirs = <String, int>{};
      for (final row in rows) {
        final quest = row['challenge_id'] as String;
        final aura = (row['challenge_aura'] as int?) ?? 0;
        if (row['user_id'] == userId) {
          mine[quest] = aura;
        } else {
          theirs[quest] = aura;
        }
      }
      final shared =
          mine.keys.where((id) => theirs.containsKey(id)).toList();
      if (shared.isEmpty) return empty;

      final results = await Future.wait([
        _client
            .from('check_ins')
            .select('user_id')
            .inFilter('challenge_id', shared)
            .inFilter('user_id', [userId, friendId]),
        _client
            .from('duels')
            .select('challenger_id, opponent_id, winner_id')
            .not('winner_id', 'is', null)
            .inFilter('challenge_id', shared),
      ]);

      var myCheckIns = 0;
      var theirCheckIns = 0;
      for (final row in results[0]) {
        if (row['user_id'] == userId) {
          myCheckIns++;
        } else {
          theirCheckIns++;
        }
      }

      var won = 0;
      var lost = 0;
      for (final row in results[1]) {
        final a = row['challenger_id'] as String?;
        final b = row['opponent_id'] as String?;
        // Only duels fought between exactly these two.
        final pair = {a, b};
        if (!pair.contains(userId) || !pair.contains(friendId)) continue;
        if (row['winner_id'] == userId) {
          won++;
        } else {
          lost++;
        }
      }

      var myAura = 0;
      var theirAura = 0;
      for (final id in shared) {
        myAura += mine[id] ?? 0;
        theirAura += theirs[id] ?? 0;
      }

      debugPrint('✅ [ChallengeRepository.fetchHeadToHead] '
          '@$username: ${shared.length} shared, $myCheckIns:$theirCheckIns');
      return HeadToHead(
        friendId: friendId,
        username: username,
        avatarEmoji: avatarEmoji,
        sharedQuests: shared.length,
        myCheckIns: myCheckIns,
        theirCheckIns: theirCheckIns,
        myAura: myAura,
        theirAura: theirAura,
        duelsWon: won,
        duelsLost: lost,
      );
    } on PostgrestException catch (e) {
      _log('fetchHeadToHead', e);
      rethrow;
    }
  }

  /// Landed heists aimed at the current user they have not seen yet —
  /// the aura was already taken on their last check-in.
  Future<List<RobbedNotice>> fetchUnseenRobbedNotices() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    try {
      final rows = await _client
          .from('aura_heists')
          .select('*, attacker:profiles!attacker_id(username)')
          .eq('target_id', userId)
          .eq('succeeded', true)
          .not('resolved_at', 'is', null)
          .isFilter('acknowledged_at', null)
          .order('resolved_at', ascending: true);
      return rows.map(RobbedNotice.fromJson).toList();
    } on PostgrestException catch (e) {
      _log('fetchUnseenRobbedNotices', e);
      rethrow;
    }
  }

  /// Marks a landed heist as seen by the victim.
  Future<void> acknowledgeRobbedNotice(String heistId) async {
    try {
      await _client
          .from('aura_heists')
          .update({'acknowledged_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', heistId);
    } on PostgrestException catch (e) {
      _log('acknowledgeRobbedNotice', e);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────

  static void _log(String method, PostgrestException e) {
    debugPrint(
      '⛔ [ChallengeRepository.$method] PostgrestException\n'
      '   code:    ${e.code}\n'
      '   message: ${e.message}\n'
      '   details: ${e.details}',
    );
  }

  /// Today's date in UTC as `yyyy-MM-dd` (matches DB day boundaries).
  static String _todayUtc() => _dateOnly(DateTime.now().toUtc());

  static String _dateOnly(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}
