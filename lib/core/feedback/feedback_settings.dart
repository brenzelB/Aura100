import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackSettings {
  const FeedbackSettings({this.sounds = true, this.haptics = true});

  final bool sounds;
  final bool haptics;
}

/// Device preferences: no account data or server round trip is needed.
final feedbackSettingsProvider =
    AsyncNotifierProvider<FeedbackSettingsController, FeedbackSettings>(
        FeedbackSettingsController.new);

class FeedbackSettingsController extends AsyncNotifier<FeedbackSettings> {
  static const soundsKey = 'feedback_sounds_enabled';
  static const hapticsKey = 'feedback_haptics_enabled';

  @override
  Future<FeedbackSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return FeedbackSettings(
      sounds: prefs.getBool(soundsKey) ?? true,
      haptics: prefs.getBool(hapticsKey) ?? true,
    );
  }

  Future<void> setSounds(bool enabled) => _save(sounds: enabled);
  Future<void> setHaptics(bool enabled) => _save(haptics: enabled);

  Future<void> _save({bool? sounds, bool? haptics}) async {
    final previous = await future;
    final next = FeedbackSettings(
      sounds: sounds ?? previous.sounds,
      haptics: haptics ?? previous.haptics,
    );
    state = AsyncData(next);
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = sounds != null
          ? await prefs.setBool(soundsKey, sounds)
          : await prefs.setBool(hapticsKey, haptics!);
      if (!saved) throw StateError('Feedback preference was not saved.');
    } catch (_) {
      if (identical(state.valueOrNull, next)) state = AsyncData(previous);
      rethrow;
    }
  }
}
