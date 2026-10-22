import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:aura_quest/core/feedback/bundled_sound_output.dart';
import 'package:aura_quest/core/feedback/feedback_settings.dart';
import 'package:aura_quest/core/feedback/interaction_feedback.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/recording_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sound and haptics preferences persist independently across restarts',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
        (await container.read(feedbackSettingsProvider.future)).sounds, isTrue);
    await container.read(feedbackSettingsProvider.notifier).setSounds(false);
    expect(
        container.read(feedbackSettingsProvider).requireValue.haptics, isTrue);
    await container.read(feedbackSettingsProvider.notifier).setHaptics(false);
    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    final settings = await restarted.read(feedbackSettingsProvider.future);
    expect(settings.sounds, isFalse);
    expect(settings.haptics, isFalse);
    await restarted.read(feedbackSettingsProvider.notifier).setSounds(true);
    expect(
        restarted.read(feedbackSettingsProvider).requireValue.haptics, isFalse);
  });

  test('feedback coalesces quick actions and honours both switches immediately',
      () async {
    var settings = const FeedbackSettings();
    var now = DateTime.utc(2026, 10, 21);
    final output = SilentSoundOutput();
    var taps = 0;
    final feedback = InteractionFeedback(
      settings: () => settings,
      output: output,
      now: () => now,
      haptic: () async {
        taps++;
      },
    );
    feedback.initialize();
    feedback.didChangeAppLifecycleState(AppLifecycleState.resumed);
    addTearDown(feedback.dispose);
    await Future<void>.delayed(Duration.zero);
    feedback.play(FeedbackCue.checkIn);
    feedback.play(FeedbackCue.milestone);
    expect(output.played, [FeedbackCue.checkIn]);
    expect(taps, 1);
    now = now.add(const Duration(seconds: 1));
    settings = const FeedbackSettings(sounds: false);
    feedback.play(FeedbackCue.progress);
    expect(output.played, [FeedbackCue.checkIn]);
    expect(taps, 2);
    now = now.add(const Duration(seconds: 1));
    settings = const FeedbackSettings(haptics: false);
    feedback.play(FeedbackCue.milestone);
    expect(output.played.last, FeedbackCue.milestone);
    expect(taps, 2);
    now = now.add(const Duration(seconds: 1));
    settings = const FeedbackSettings(sounds: false, haptics: false);
    feedback.play(FeedbackCue.checkIn);
    expect(output.played.length, 2);
    expect(taps, 2);
  });

  test('background, disposal and unavailable settings suppress all feedback',
      () async {
    FeedbackSettings? settings;
    final output = SilentSoundOutput();
    var taps = 0;
    final feedback = InteractionFeedback(
      settings: () => settings,
      output: output,
      haptic: () async {
        taps++;
      },
    );
    feedback.initialize();
    await Future<void>.delayed(Duration.zero);
    feedback.play(FeedbackCue.checkIn);
    settings = const FeedbackSettings();
    feedback.didChangeAppLifecycleState(AppLifecycleState.paused);
    feedback.play(FeedbackCue.checkIn);
    expect(output.stops, 1);
    feedback.didChangeAppLifecycleState(AppLifecycleState.resumed);
    feedback.dispose();
    feedback.play(FeedbackCue.checkIn);
    expect(output.played, isEmpty);
    expect(taps, 0);
    expect(output.disposals, 1);
  });

  test('an action during warmup never produces a late success sound', () async {
    final output = _DelayedOutput();
    var taps = 0;
    final feedback = InteractionFeedback(
      settings: () => const FeedbackSettings(),
      output: output,
      haptic: () async {
        taps++;
      },
    );
    feedback.initialize();
    feedback.didChangeAppLifecycleState(AppLifecycleState.resumed);
    addTearDown(feedback.dispose);
    feedback.play(FeedbackCue.checkIn);
    output.ready.complete();
    await Future<void>.delayed(Duration.zero);
    expect(output.played, isEmpty);
    expect(taps, 1);
  });

  test('unsupported audio and haptics never fail the confirmed action',
      () async {
    final output = SilentSoundOutput()..fail = true;
    final feedback = InteractionFeedback(
      settings: () => const FeedbackSettings(),
      output: output,
      haptic: () async => throw StateError('No haptic hardware'),
    );
    feedback.initialize();
    feedback.didChangeAppLifecycleState(AppLifecycleState.resumed);
    addTearDown(feedback.dispose);
    await Future<void>.delayed(Duration.zero);
    feedback.play(FeedbackCue.checkIn);
    await Future<void>.delayed(Duration.zero);
  });

  test(
      'audio respects silence, leaves music focus alone and stays foreground-only',
      () {
    final context = BundledSoundOutput.audioContext;
    expect(context.android.audioFocus, AndroidAudioFocus.none);
    expect(context.android.usageType, AndroidUsageType.notificationRingtone);
    expect(context.android.stayAwake, isFalse);
    expect(context.iOS.category, AVAudioSessionCategory.ambient);
  });

  test('bundled cues are short quiet PCM, without clipping or remote assets',
      () async {
    var totalBytes = 0;
    for (final path in BundledSoundOutput.assets.values) {
      final bytes = await rootBundle.load('assets/$path');
      totalBytes += bytes.lengthInBytes;
      expect(String.fromCharCodes(bytes.buffer.asUint8List(0, 4)), 'RIFF');
      expect(bytes.getUint16(22, Endian.little), 1);
      expect(bytes.getUint32(24, Endian.little), 44100);
      expect(bytes.getUint16(34, Endian.little), 16);
      final sampleCount = (bytes.lengthInBytes - 44) ~/ 2;
      expect(sampleCount / 44100, lessThanOrEqualTo(0.8));
      var peak = 0;
      for (var i = 44; i < bytes.lengthInBytes; i += 2) {
        peak = max(peak, bytes.getInt16(i, Endian.little).abs());
      }
      expect(peak, inInclusiveRange(100, 8300)); // At most -12 dBFS.
    }
    expect(totalBytes, lessThan(160000));
  });
}

class _DelayedOutput extends SilentSoundOutput {
  final ready = Completer<void>();
  @override
  Future<void> prepare() => ready.future;
}
