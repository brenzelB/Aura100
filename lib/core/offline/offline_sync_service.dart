import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/challenges/data/challenge_repository.dart';
import 'offline_check_in_queue.dart';

/// Result summary of an offline check-in sync run.
class SyncResult {
  const SyncResult({
    required this.syncedCount,
    required this.auraGained,
    required this.syncedTitles,
    this.failedCount = 0,
    this.networkError = false,
  });

  final int syncedCount;
  final int auraGained;
  final List<String> syncedTitles;
  final int failedCount;
  final bool networkError;

  bool get hasSynced => syncedCount > 0;
}

/// Service that monitors device connectivity and automatically synchronizes
/// pending offline check-ins with Supabase.
class OfflineSyncService {
  OfflineSyncService({
    OfflineCheckInQueue? queue,
    Connectivity? connectivity,
    String? Function()? currentUserIdGetter,
  })  : _queue = queue ?? const OfflineCheckInQueue(),
        _connectivity = connectivity ?? Connectivity(),
        _currentUserIdGetter = currentUserIdGetter;

  final OfflineCheckInQueue _queue;
  final Connectivity _connectivity;
  final String? Function()? _currentUserIdGetter;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  /// Starts listening for connectivity changes to trigger automatic sync.
  void initialize(Future<void> Function() onSyncCompleted,
      Future<SyncResult> Function() syncCallback) {
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn);

      if (isOnline) {
        debugPrint(
            '🌐 [OfflineSyncService] Network restored, attempting sync...');
        syncCallback().then((result) {
          onSyncCompleted();
        });
      }
    });
  }

  /// Synchronizes all queued check-ins against Supabase.
  Future<SyncResult> syncPendingCheckIns(ChallengeRepository repo) async {
    if (_isSyncing) {
      debugPrint('⏳ [OfflineSyncService] Sync already in progress, skipping');
      return const SyncResult(syncedCount: 0, auraGained: 0, syncedTitles: []);
    }

    final pending = await _queue.getPending();
    if (pending.isEmpty) {
      return const SyncResult(syncedCount: 0, auraGained: 0, syncedTitles: []);
    }

    _isSyncing = true;
    int syncedCount = 0;
    int totalAura = 0;
    int failedCount = 0;
    bool networkError = false;
    final syncedTitles = <String>[];

    debugPrint(
        '🔄 [OfflineSyncService] Starting sync for ${pending.length} pending check-in(s)...');

    try {
      final nowUtc = DateTime.now().toUtc();
      final todayDate = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      String? currentUserId;
      if (_currentUserIdGetter != null) {
        currentUserId = _currentUserIdGetter();
      } else {
        try {
          currentUserId = Supabase.instance.client.auth.currentUser?.id;
        } catch (_) {
          // Uninitialized in unit tests or offline environments
        }
      }

      for (final item in pending) {
        // Cross-user safety: skip if check-in belongs to another user
        if (item.userId.isNotEmpty &&
            currentUserId != null &&
            item.userId != currentUserId) {
          debugPrint(
              '⚠ [OfflineSyncService] Skipping check-in for "${item.questTitle}" '
              '(belongs to user ${item.userId}, current is $currentUserId)');
          continue;
        }

        // Enforce same-day policy: if the check-in is from a previous calendar day
        // that has already rolled over on the server, we drop it gracefully
        // because log_check_in only records check-ins for the current UTC day.
        final itemDate =
            DateTime.utc(item.date.year, item.date.month, item.date.day);

        if (itemDate != todayDate) {
          debugPrint(
              '⚠ [OfflineSyncService] Dropping expired check-in for "${item.questTitle}" '
              'from ${item.date.toIso8601String()} (calendar day already rolled over)');
          await _queue.remove(item.challengeId, date: item.date);
          failedCount++;
          continue;
        }

        try {
          final gained = await repo.logCheckIn(item.challengeId);
          await _queue.remove(item.challengeId, date: item.date);
          syncedCount++;
          totalAura += gained;
          syncedTitles.add(item.questTitle);
          debugPrint(
              '✅ [OfflineSyncService] Synced "${item.questTitle}" (+$gained Aura)');
        } on PostgrestException catch (e) {
          // Check if it's "Already checked in today" - if so, consider done & remove
          if (e.message.toLowerCase().contains('already checked in')) {
            debugPrint(
                'ℹ [OfflineSyncService] Already recorded on server: "${item.questTitle}"');
            await _queue.remove(item.challengeId, date: item.date);
            syncedCount++;
            syncedTitles.add(item.questTitle);
          } else if (e.message.toLowerCase().contains('not found') ||
              e.message.toLowerCase().contains('already ended') ||
              e.message.toLowerCase().contains('over') ||
              e.message.toLowerCase().contains('not an active participant')) {
            debugPrint(
                '⚠ [OfflineSyncService] Unrecoverable quest error: "${e.message}", dropping item');
            await _queue.remove(item.challengeId, date: item.date);
            failedCount++;
          } else {
            debugPrint('⚠ [OfflineSyncService] Server error: ${e.message}');
            failedCount++;
          }
        } catch (e) {
          debugPrint(
              '🔌 [OfflineSyncService] Network/connection error while syncing: $e');
          networkError = true;
          // Connection is down again, halt the rest of the queue for next window
          break;
        }
      }
    } finally {
      _isSyncing = false;
    }

    debugPrint('🏁 [OfflineSyncService] Sync finished: $syncedCount synced '
        '(+$totalAura Aura), $failedCount failed, networkError=$networkError');

    return SyncResult(
      syncedCount: syncedCount,
      auraGained: totalAura,
      syncedTitles: syncedTitles,
      failedCount: failedCount,
      networkError: networkError,
    );
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }
}
