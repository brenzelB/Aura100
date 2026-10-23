import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One local unfinished quest per account. No backend storage. Serialized writes
/// prevent an in-flight save from resurrecting a cleared or completed draft.
class QuestDraftStore {
  static Future<void>? _writes;
  String _key(String owner) => 'quest_draft_v1:$owner';

  Future<Map<String, dynamic>?> load(String owner) async {
    try {
      final pending = _writes;
      if (pending != null) await pending;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(owner));
      if (raw == null) return null;
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> || value['version'] != 1) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String owner, Map<String, dynamic> draft) =>
      _enqueue(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            _key(owner), jsonEncode({'version': 1, ...draft}));
      });

  Future<void> clear(String owner) => _enqueue(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_key(owner));
      });

  Future<void> _enqueue(Future<void> Function() action) {
    final queued = (_writes ?? Future<void>.value())
        .then((_) => action())
        .catchError((Object _) {
      // Storage must never fail a confirmed server action.
    });
    _writes = queued;
    queued.then((_) {
      if (identical(_writes, queued)) _writes = null;
    });
    return queued;
  }
}
