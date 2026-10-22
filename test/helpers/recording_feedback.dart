import 'package:aura_quest/core/feedback/interaction_feedback.dart';

class RecordingFeedback extends InteractionFeedback {
  RecordingFeedback()
      : super(settings: () => null, output: SilentSoundOutput());
  final cues = <FeedbackCue>[];

  @override
  void play(FeedbackCue cue) => cues.add(cue);
}

class SilentSoundOutput implements FeedbackSoundOutput {
  final played = <FeedbackCue>[];
  int stops = 0;
  int disposals = 0;
  bool fail = false;

  @override
  Future<void> prepare() async {}
  @override
  Future<void> play(FeedbackCue cue) async {
    if (fail) throw StateError('Audio unavailable');
    played.add(cue);
  }

  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async => disposals++;
}
