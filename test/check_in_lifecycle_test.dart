import 'dart:async';
import 'package:aura_quest/features/auth/application/auth_providers.dart';
import 'package:aura_quest/features/auth/data/auth_repository.dart';
import 'package:aura_quest/features/challenges/application/challenge_providers.dart';
import 'package:aura_quest/features/challenges/data/challenge_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Auth implements AuthRepository {
  @override
  User? currentUser = User(
      id: 'alice',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-09-09T00:00:00Z');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements ChallengeRepository {
  final reply = Completer<int>();
  @override
  Future<int> logCheckIn(String id) => reply.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'a confirmed check-in survives its card being removed before the response',
      () async {
    final auth = _Auth();
    final repo = _Repo();
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      currentUserProvider.overrideWith((ref) => auth.currentUser),
      challengeRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    final provider = checkInControllerProvider('quest');
    final subscription = container.listen(provider, (_, __) {});
    final result =
        container.read(provider.notifier).checkIn(questTitle: 'Quest');
    // Realtime has moved the card to Done while the HTTP response is in flight.
    subscription.close();
    await container.pump();
    repo.reply.complete(100);
    expect((await result).auraGained, 100);
    await container.pump();
    expect(container.exists(provider), isFalse);
  });
  test('server rejection remains an error when the card disappears', () async {
    final auth = _Auth();
    final repo = _Repo();
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      currentUserProvider.overrideWith((ref) => auth.currentUser),
      challengeRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    final provider = checkInControllerProvider('quest');
    final subscription = container.listen(provider, (_, __) {});
    final response = container.read(provider.notifier).checkIn();
    subscription.close();
    await container.pump();
    repo.reply.completeError(
        const PostgrestException(message: 'Already checked in today.'));
    final result = await response;
    expect(result.isSuccess, isFalse);
    expect(result.auraGained, isNull);
    expect(result.errorMessage, 'Already checked in today.');
    await container.pump();
    expect(container.exists(provider), isFalse);
  });
  test('late success from the old account is not applied to the new account',
      () async {
    final auth = _Auth();
    final repo = _Repo();
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      currentUserProvider.overrideWith((ref) => auth.currentUser),
      challengeRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    final provider = checkInControllerProvider('quest');
    final subscription = container.listen(provider, (_, __) {});
    final response = container.read(provider.notifier).checkIn();
    subscription.close();
    await container.pump();
    auth.currentUser = null;
    repo.reply.complete(100);
    final result = await response;
    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, 'Account changed. Please try again.');
  });
}
