import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pending_check_in.dart';

/// Manages the local persistent FIFO queue of offline check-ins via [SharedPreferences].
class OfflineCheckInQueue {
  const OfflineCheckInQueue({this.userId});

  /// The active user ID for queue isolation, or null for global/unauthenticated fallback.
  final String? userId;

  static const String defaultStorageKey = 'pending_offline_checkins';

  /// Dynamically scopes storage key to the active user.
  String get storageKey => (userId != null && userId!.isNotEmpty)
      ? 'pending_offline_checkins_$userId'
      : defaultStorageKey;

  /// Reads all pending check-ins currently stored on device for this user scope.
  Future<List<PendingCheckIn>> getPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var rawList = prefs.getStringList(storageKey);

      // Migration fallback: if user-scoped key is not yet set, inspect legacy global key
      if (rawList == null && userId != null && userId!.isNotEmpty) {
        final legacy = prefs.getStringList(defaultStorageKey);
        if (legacy != null && legacy.isNotEmpty) {
          rawList = legacy;
        }
      }

      rawList ??= [];
      final result = <PendingCheckIn>[];
      for (final item in rawList) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          final parsed = PendingCheckIn.fromJson(map);
          // If queue is user-scoped and parsed item has a different non-empty userId, ignore it
          if (userId != null &&
              userId!.isNotEmpty &&
              parsed.userId.isNotEmpty &&
              parsed.userId != userId) {
            continue;
          }
          result.add(parsed);
        } catch (e) {
          debugPrint('⚠ [OfflineCheckInQueue] Dropping corrupted entry: $e');
        }
      }
      return result;
    } catch (e) {
      debugPrint('⚠ [OfflineCheckInQueue] Failed to read queue: $e');
      return [];
    }
  }

  /// Appends a check-in to the queue. Idempotent: does not duplicate
  /// an entry for the same challenge on the same day.
  Future<bool> enqueue(PendingCheckIn checkIn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getPending();

      // Check if already in queue for this day
      final exists = current.any((item) =>
          item.challengeId == checkIn.challengeId &&
          item.date.year == checkIn.date.year &&
          item.date.month == checkIn.date.month &&
          item.date.day == checkIn.date.day);

      if (exists) {
        debugPrint(
            'ℹ [OfflineCheckInQueue] Check-in already queued: ${checkIn.questTitle}');
        return false;
      }

      final itemToStore = (checkIn.userId.isEmpty &&
              userId != null &&
              userId!.isNotEmpty)
          ? PendingCheckIn(
              challengeId: checkIn.challengeId,
              questTitle: checkIn.questTitle,
              timestamp: checkIn.timestamp,
              date: checkIn.date,
              userId: userId!,
            )
          : checkIn;

      current.add(itemToStore);
      final rawList = current.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(storageKey, rawList);
      debugPrint(
          '💾 [OfflineCheckInQueue] Enqueued offline check-in for "${checkIn.questTitle}" '
          'in $storageKey (${current.length} total pending)');
      return true;
    } catch (e) {
      debugPrint('⚠ [OfflineCheckInQueue] Failed to enqueue: $e');
      return false;
    }
  }

  /// Removes a specific check-in (after successful sync or cancellation).
  Future<void> remove(String challengeId, {DateTime? date}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getPending();
      final before = current.length;

      current.removeWhere((item) {
        if (item.challengeId != challengeId) return false;
        if (date != null) {
          return item.date.year == date.year &&
              item.date.month == date.month &&
              item.date.day == date.day;
        }
        return true;
      });

      if (current.length != before) {
        final rawList =
            current.map((item) => jsonEncode(item.toJson())).toList();
        await prefs.setStringList(storageKey, rawList);
        debugPrint(
            '🗑 [OfflineCheckInQueue] Removed check-in for $challengeId '
            'from $storageKey (${current.length} remaining)');
      }
    } catch (e) {
      debugPrint('⚠ [OfflineCheckInQueue] Failed to remove entry: $e');
    }
  }

  /// Clears all pending check-ins for this user scope.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
      debugPrint('🧹 [OfflineCheckInQueue] Queue cleared ($storageKey)');
    } catch (e) {
      debugPrint('⚠ [OfflineCheckInQueue] Failed to clear queue: $e');
    }
  }
}
