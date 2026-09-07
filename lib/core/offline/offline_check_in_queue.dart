import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';
import 'pending_check_in.dart';

/// Durable queue owned by one account on one backend. Legacy queues remain
/// quarantined: their missing backend/owner cannot be inferred from a login.
class OfflineCheckInQueue {
  const OfflineCheckInQueue(
      {this.userId, this.backendUrl = SupabaseConfig.url});
  final String? userId;
  final String backendUrl;
  static const defaultStorageKey = 'pending_offline_checkins';
  static final _writes = <String, Future<void>>{};
  bool get hasOwner => userId != null && userId!.isNotEmpty;
  String get storageKey =>
      'pending_checkins_v2_${base64Url.encode(utf8.encode(jsonEncode([
            backendUrl,
            userId
          ])))}';

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final previous = _writes[storageKey] ?? Future<void>.value();
    final done = Completer<void>();
    _writes[storageKey] = done.future;
    await previous;
    try {
      return await action();
    } finally {
      done.complete();
      if (identical(_writes[storageKey], done.future)) {
        _writes.remove(storageKey);
      }
    }
  }

  Future<List<PendingCheckIn>> _read() async {
    if (!hasOwner) return [];
    final prefs = await SharedPreferences.getInstance();
    final items = <PendingCheckIn>[];
    for (final raw in prefs.getStringList(storageKey) ?? <String>[]) {
      try {
        final item =
            PendingCheckIn.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (item.userId == userId) items.add(item);
      } on FormatException catch (_) {
        debugPrint('Ignoring malformed offline check-in');
      } on TypeError catch (_) {
        debugPrint('Ignoring malformed offline check-in');
      }
    }
    return items;
  }

  Future<List<PendingCheckIn>> getPending() => _exclusive(_read);

  /// True means the check-in is durably present (including a duplicate tap).
  Future<bool> enqueue(PendingCheckIn item) async {
    if (!hasOwner || (item.userId.isNotEmpty && item.userId != userId)) {
      return false;
    }
    try {
      return await _exclusive(() async {
        final items = await _read();
        if (items.any(
            (p) => p.challengeId == item.challengeId && p.date == item.date)) {
          return true;
        }
        items.add(PendingCheckIn(
            challengeId: item.challengeId,
            questTitle: item.questTitle,
            timestamp: item.timestamp,
            date: item.date,
            userId: userId!));
        return _save(items);
      });
    } catch (_) {
      return false;
    }
  }

  Future<bool> _save(List<PendingCheckIn> items) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setStringList(
        storageKey, items.map((p) => jsonEncode(p.toJson())).toList());
  }

  Future<void> remove(String challengeId, {DateTime? date}) =>
      _exclusive(() async {
        final items = await _read();
        items.removeWhere((p) =>
            p.challengeId == challengeId && (date == null || p.date == date));
        if (!await _save(items)) {
          throw StateError('Could not persist offline queue');
        }
      });

  Future<void> clear() => _exclusive(() async {
        if (!await _save([])) throw StateError('Could not clear offline queue');
      });
}
