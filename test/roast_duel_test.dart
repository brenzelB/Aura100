import 'dart:async';
import 'package:aura_quest/core/text/game_roasts.dart';
import 'package:aura_quest/core/theme/app_colors.dart';
import 'package:aura_quest/core/theme/app_theme.dart';
import 'package:aura_quest/features/auth/application/auth_providers.dart';
import 'package:aura_quest/features/auth/data/auth_repository.dart';
import 'package:aura_quest/features/challenges/application/challenge_providers.dart';
import 'package:aura_quest/features/challenges/data/challenge_repository.dart';
import 'package:aura_quest/features/challenges/domain/duel.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/roast_duel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _user = User(
    id: 'alice',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-10-17');
const _active = DuelResult(
    id: 'game',
    status: 'active',
    challengerId: 'alice',
    opponentId: 'bob',
    round: 1,
    challengerScore: 0,
    opponentScore: 0,
    roastKey: 0);
const _lost = DuelResult(
    id: 'game',
    status: 'resolved',
    challengerId: 'alice',
    opponentId: 'bob',
    round: 4,
    challengerScore: 0,
    opponentScore: 3,
    roastKey: 0,
    winnerId: 'bob',
    lastChallengerMove: DuelMove.scissors,
    lastOpponentMove: DuelMove.rock);

class _Auth implements AuthRepository {
  @override
  User? get currentUser => _user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements ChallengeRepository {
  DuelResult game = _active;
  int plays = 0;
  final saving = Completer<void>();
  @override
  Future<DuelResult> fetchDuel(String id) async => game;
  @override
  Future<DuelResult> playDuel(
      {required String duelId,
      required int round,
      required DuelMove move}) async {
    plays++;
    await saving.future;
    game = DuelResult(
        id: 'game',
        status: 'active',
        challengerId: 'alice',
        opponentId: 'bob',
        round: round,
        challengerScore: 0,
        opponentScore: 0,
        roastKey: 0,
        myMove: move);
    return game;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(_Repo repo,
    {AppThemeType type = AppThemeType.neoBrutalist,
    AppThemeMode mode = AppThemeMode.light,
    double textScale = 1}) {
  AppColors.apply(type, mode);
  return ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_user),
        authRepositoryProvider.overrideWithValue(_Auth()),
        authStateChangesProvider
            .overrideWith((ref) => const Stream<AuthState>.empty()),
        challengeRepositoryProvider.overrideWithValue(repo)
      ],
      child: MaterialApp(
          theme: AppTheme.build(type, mode),
          home: MediaQuery(
              data: MediaQueryData(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: true),
              child: Scaffold(
                  body: DuelSheet(
                      duel: IncomingDuel(
                          id: 'game',
                          questTitle: 'Read ten pages',
                          challengerName: 'bob',
                          challengerAvatar: null,
                          createdAt: DateTime(2026)))))));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('all nine pairs have one winner or a draw', () {
    for (final a in DuelMove.values) {
      for (final b in DuelMove.values) {
        expect(a.beats(b) && b.beats(a), isFalse);
        expect(a.beats(b) || b.beats(a), a != b);
      }
    }
    expect(DuelMove.rock.beats(DuelMove.scissors), isTrue);
    expect(DuelMove.paper.beats(DuelMove.rock), isTrue);
    expect(DuelMove.scissors.beats(DuelMove.paper), isTrue);
  });
  test('all stored roast keys keep the original English line', () {
    expect(GameRoasts.english.length, 40);
    expect(GameRoasts.english.toSet().length, 40);
    expect(
        GameRoasts.english.every((s) => s.isNotEmpty && s == s.trim()), isTrue);
    for (var key = 0; key < 40; key++) {
      expect(GameRoasts.line(key), GameRoasts.english[key]);
    }
  });
  testWidgets('a pending save disables all moves; saved choice stays locked',
      (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-rock')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('move-paper')));
    await tester.pump();
    expect(repo.plays, 1);
    repo.saving.complete();
    await tester.pumpAndSettle();
    expect(find.text('Rock locked. Waiting for their move.'), findsOneWidget);
    for (final move in DuelMove.values) {
      expect(
          tester
              .widget<OutlinedButton>(find.byKey(ValueKey('move-${move.name}')))
              .onPressed,
          isNull);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('German device still shows the saved English loss roast',
      (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('de');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final repo = _Repo()..game = _lost;
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('EGO: LIGHTLY TOASTED.'), findsOneWidget);
    expect(find.text('Big ego. Tiny scissors.'), findsOneWidget);
    expect(find.text('No Aura lost. No XP changed. Just bragging rights.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('move-rock')), findsNothing);
    expect(repo.plays, 0);
    expect(tester.takeException(), isNull);
  });
  for (final type in AppThemeType.values) {
    for (final mode in [AppThemeMode.light, AppThemeMode.dark]) {
      for (final resolved in [false, true]) {
        testWidgets(
            'game layout at 320px and large text: $type $mode resolved=$resolved',
            (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = _Repo()..game = resolved ? _lost : _active;
          await tester
              .pumpWidget(_app(repo, type: type, mode: mode, textScale: 2));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
