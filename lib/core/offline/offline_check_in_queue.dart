import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pending_check_in.dart';

/// Manages the local persistent FIFO queue of offline check-ins via [SharedPreferences].
class OfflineCheckInQueue {
  const OfflineCheckInQueue();

  static const String storageKey = 'pending_offline_checkins';

  /// Reads all pending check-ins currently stored on device.
  Future<List<PendingCheckIn>> getPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(storageKey) ?? [];
      final result = <PendingCheckIn>[];
      for (final item in rawList) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          result.add(PendingCheckIn.fromJson(map));
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

      current.add(checkIn);
      final rawList = current.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(storageKey, rawList);
      debugPrint(
          '💾 [OfflineCheckInQueue] Enqueued offline check-in for "${checkIn.questTitle}" '
          '(${current.length} total pending)');
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
            '(${current.length} remaining)');
      }
    } catch (e) {
      debugPrint('⚠ [OfflineCheckInQueue] Failed to remove entry: $e');
    }
  }

  /// Clears all pending check-ins.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
      debugPrint('🧹 [OfflineCheckInQueue] Queue cleared');
    } catch (e) {
      debugPrint('⚠ [OfflineCheckInQueue] Failed to clear queue: $e');
    }
  }
}
