import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'interaction_feedback.dart';

/// One preloaded player per tiny local asset. No network, loops or audio focus.
class BundledSoundOutput implements FeedbackSoundOutput {
  static final audioContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      // The ring stream respects silent/vibrate mode on Android.
      usageType: AndroidUsageType.notificationRingtone,
      audioFocus: AndroidAudioFocus.none,
    ),
    // Ambient implicitly mixes with music and respects the iPhone silent switch.
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  static const assets = {
    FeedbackCue.checkIn: 'audio/check_in.wav',
    FeedbackCue.progress: 'audio/progress.wav',
    FeedbackCue.milestone: 'audio/milestone.wav',
  };
  static const volume = 0.65;
  final _players = <FeedbackCue, AudioPlayer>{};
  bool _disposed = false;
  int _playbackEpoch = 0;

  @override
  Future<void> prepare() async {
    for (final entry in assets.entries) {
      if (_disposed) return;
      final player = AudioPlayer();
      _players[entry.key] = player;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await player.setPlayerMode(PlayerMode.lowLatency);
      }
      if (_disposed) return;
      await player.setAudioContext(audioContext);
      if (_disposed) return;
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(volume);
      if (_disposed) return;
      await player.setSource(AssetSource(entry.value));
    }
  }

  @override
  Future<void> play(FeedbackCue cue) async {
    if (_disposed) return;
    final player = _players[cue];
    if (player == null) return;
    final epoch = ++_playbackEpoch;
    await player.stop();
    if (!_disposed && epoch == _playbackEpoch) await player.resume();
  }

  @override
  Future<void> stop() async {
    _playbackEpoch++;
    if (_disposed) return;
    await Future.wait(_players.values.map((player) => player.stop()));
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _playbackEpoch++;
    await Future.wait(_players.values.map((player) => player.dispose()));
    _players.clear();
  }
}
