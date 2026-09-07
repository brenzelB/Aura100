import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
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
    this.discardedCount = 0,
  });

  final int syncedCount;
  final int auraGained;
  final List<String> syncedTitles;
  final int failedCount;
  final bool networkError;
  final int discardedCount;

  bool get hasSynced => syncedCount > 0;
}

/// Service that monitors device connectivity and automatically synchronizes
/// pending offline check-ins with Supabase.
class OfflineSyncService with WidgetsBindingObserver {
  OfflineSyncService({
    OfflineCheckInQueue? queue,
    Connectivity? connectivity,
    String? Function()? currentUserIdGetter,
    DateTime Function()? now,
  })  : _queue = queue ?? const OfflineCheckInQueue(),
        _connectivity = connectivity ?? Connectivity(),
        _currentUserIdGetter = currentUserIdGetter ??
            (() => Supabase.instance.client.auth.currentUser?.id),
        _now = now ?? DateTime.now;

  final OfflineCheckInQueue _queue;
  final Connectivity _connectivity;
  final String? Function() _currentUserIdGetter;
  final DateTime Function() _now;
  bool _disposed = false;
  Future<void> Function()? _resume;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;
  bool get isDisposed => _disposed;

  /// Starts listening for connectivity changes to trigger automatic sync.
  void initialize(Future<void> Function() onSyncCompleted,
      Future<SyncResult> Function() syncCallback) {
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
    _resume = () => _runCallback(syncCallback, onSyncCompleted);
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
        unawaited(_runCallback(syncCallback, onSyncCompleted));
      }
    });
    unawaited(_runCallback(syncCallback, onSyncCompleted));
  }

  Future<void> _runCallback(Future<SyncResult> Function() sync,
      Future<void> Function() completed) async {
    if (_disposed) return;
    try {
      await sync();
      if (!_disposed) await completed();
    } catch (error) {
      debugPrint('Offline sync deferred: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _resume != null) {
      unawaited(_resume!());
    }
  }

  /// Synchronizes all queued check-ins against Supabase.
  Future<SyncResult> syncPendingCheckIns(ChallengeRepository repo) async {
    final owner = _queue.userId;
    if (_disposed ||
        _isSyncing ||
        owner == null ||
        _currentUserIdGetter() != owner) {
      debugPrint('⏳ [OfflineSyncService] Sync already in progress, skipping');
      return const SyncResult(syncedCount: 0, auraGained: 0, syncedTitles: []);
    }

    _isSyncing = true;
    int syncedCount = 0;
    int totalAura = 0;
    int failedCount = 0;
    int discardedCount = 0;
    bool networkError = false;
    final syncedTitles = <String>[];

    try {
      final pending = await _queue.getPending();
      for (final item in pending) {
        if (_disposed || _currentUserIdGetter() != owner) break;
        if (item.userId != owner) continue;
        final nowUtc = _now().toUtc();
        final todayDate = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);

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
          discardedCount++;
          continue;
        }

        try {
          final gained = await repo.logCheckIn(item.challengeId);
          if (_disposed || _currentUserIdGetter() != owner) break;
          await _queue.remove(item.challengeId, date: item.date);
          syncedCount++;
          totalAura += gained;
          syncedTitles.add(item.questTitle);
          debugPrint(
              '✅ [OfflineSyncService] Synced "${item.questTitle}" (+$gained Aura)');
        } on PostgrestException catch (e) {
          if (_disposed || _currentUserIdGetter() != owner) break;
          // Check if it's "Already checked in today" - if so, consider done & remove
          if (e.message.toLowerCase().contains('already checked in')) {
            debugPrint(
                'ℹ [OfflineSyncService] Already recorded on server: "${item.questTitle}"');
            await _queue.remove(item.challengeId, date: item.date);
            syncedCount++;
            syncedTitles.add(item.questTitle);
          } else if (e.message.toLowerCase().contains('not found') ||
              e.message.toLowerCase().contains('already ended') ||
              e.message.toLowerCase().contains('quest is over') ||
              e.message.toLowerCase().contains('not an active participant') ||
              e.message
                  .toLowerCase()
                  .contains('goal for this period already reached')) {
            debugPrint(
                '⚠ [OfflineSyncService] Unrecoverable quest error: "${e.message}", dropping item');
            await _queue.remove(item.challengeId, date: item.date);
            failedCount++;
            discardedCount++;
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
      discardedCount: discardedCount,
    );
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _resume = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }
}
