import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bundled_sound_output.dart';
import 'feedback_settings.dart';

enum FeedbackCue { checkIn, progress, milestone }

abstract interface class FeedbackSoundOutput {
  Future<void> prepare();
  Future<void> play(FeedbackCue cue);
  Future<void> stop();
  Future<void> dispose();
}

final interactionFeedbackProvider = Provider<InteractionFeedback>((ref) {
  // Keep preferences loading independently of screens. Never play a delayed
  // sound after waiting for storage or an audio decoder.
  final feedback = InteractionFeedback(
    settings: () => ref.read(feedbackSettingsProvider).valueOrNull,
    output: BundledSoundOutput(),
  );
  ref.listen(feedbackSettingsProvider, (_, next) {
    if (next.valueOrNull?.sounds != true) feedback.stop();
  });
  feedback.initialize();
  ref.onDispose(feedback.dispose);
  return feedback;
});

/// Optional, best-effort feedback. It never delays or fails a user action.
/// Only explicit, confirmed foreground actions call [play]; sync/realtime do not.
class InteractionFeedback with WidgetsBindingObserver {
  InteractionFeedback({
    required FeedbackSettings? Function() settings,
    required FeedbackSoundOutput output,
    Future<void> Function()? haptic,
    DateTime Function()? now,
  })  : _settings = settings,
        _output = output,
        _haptic = haptic ?? HapticFeedback.heavyImpact,
        _now = now ?? DateTime.now;

  final FeedbackSettings? Function() _settings;
  final FeedbackSoundOutput _output;
  final Future<void> Function() _haptic;
  final DateTime Function() _now;
  bool _disposed = false;
  bool _ready = false;
  bool _initialized = false;
  bool _foreground = true;
  DateTime? _lastFeedback;

  void initialize() {
    if (_initialized || _disposed) return;
    _initialized = true;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      await _output.prepare();
      if (!_disposed) _ready = true;
    } catch (_) {
      // Missing audio hardware/unsupported browser must never break check-ins.
    }
  }

  void play(FeedbackCue cue) => _emit(cue);

  /// A short tactile acknowledgement for corrections/slips; no success sound.
  void selection() => _emit(null);

  void _emit(FeedbackCue? cue) {
    if (_disposed || !_foreground) return;
    final settings = _settings();
    if (settings == null || (!settings.sounds && !settings.haptics)) return;
    final now = _now();
    // Prevent overlapping chimes and repeated buzzes during quick actions.
    if (_lastFeedback != null &&
        now.difference(_lastFeedback!) < const Duration(milliseconds: 900)) {
      return;
    }
    _lastFeedback = now;
    if (settings.haptics) unawaited(_ignoreFailure(_haptic));
    if (cue != null && settings.sounds && _ready) {
      unawaited(_ignoreFailure(() => _output.play(cue)));
    }
  }

  void stop() => unawaited(_ignoreFailure(_output.stop));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) stop();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_initialized) WidgetsBinding.instance.removeObserver(this);
    unawaited(_ignoreFailure(_output.dispose));
  }

  Future<void> _ignoreFailure(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Audio and haptics are decoration, never part of the transaction.
    }
  }
}
