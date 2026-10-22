import 'dart:async';

import 'package:aura_quest/core/feedback/interaction_feedback.dart';
import 'package:aura_quest/features/auth/application/auth_providers.dart';
import 'package:aura_quest/features/auth/data/auth_repository.dart';
import 'package:aura_quest/features/challenges/application/challenge_providers.dart';
import 'package:aura_quest/features/challenges/data/challenge_repository.dart';
import 'package:aura_quest/features/challenges/domain/progress_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/recording_feedback.dart';

class _Auth implements AuthRepository {
  @override
  User? currentUser = User(
      id: 'alice',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-21T00:00:00Z');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements ChallengeRepository {
  final reply = Completer<ProgressResult>();
  @override
  Future<ProgressResult> addProgress(
          {required String challengeId, required double amount}) =>
      reply.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    'progress',
    'goal',
    'bonus',
    'rejected',
    'account changed'
  ]) {
    test(
        '$scenario: feedback follows the confirmed result, even if the card disappears',
        () async {
      final auth = _Auth();
      final repo = _Repo();
      final feedback = RecordingFeedback();
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        currentUserProvider.overrideWith((ref) => auth.currentUser),
        challengeRepositoryProvider.overrideWithValue(repo),
        interactionFeedbackProvider.overrideWithValue(feedback),
      ]);
      addTearDown(container.dispose);
      final provider = progressControllerProvider('quest');
      final subscription = container.listen(provider, (_, __) {});
      final result = container.read(provider.notifier).add(10);
      subscription.close();
      await container.pump();
      expect(feedback.cues, isEmpty);
      if (scenario == 'rejected') {
        repo.reply
            .completeError(const PostgrestException(message: 'Not allowed'));
      } else {
        if (scenario == 'account changed') auth.currentUser = null;
        repo.reply.complete(ProgressResult(
          total: scenario == 'goal' || scenario == 'bonus' ? 100 : 10,
          target: 100,
          completed: scenario == 'goal' || scenario == 'bonus',
          overshoot: scenario == 'bonus',
          gained: scenario == 'goal' ? 100 : null,
        ));
      }
      await result;
      expect(
          feedback.cues,
          switch (scenario) {
            'rejected' || 'account changed' => <FeedbackCue>[],
            'goal' => [FeedbackCue.milestone],
            _ => [FeedbackCue.progress],
          });
      await container.pump();
      expect(container.exists(provider), isFalse);
    });
  }
}
