import 'package:aura_quest/features/auth/application/auth_providers.dart';
import 'package:aura_quest/features/challenges/application/challenge_providers.dart';
import 'package:aura_quest/features/challenges/domain/challenge.dart';
import 'package:aura_quest/features/challenges/domain/quest_member.dart';
import 'package:aura_quest/features/challenges/presentation/screens/challenge_detail_screen.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/challenge_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Finishing a quest used to be the one outcome the app refused to show.
///
/// The list asked the server for participations with status `active`,
/// `failed` or `eliminated`. Winning sets `completed`, which was not in
/// that list — so the quest you LOST stayed in front of you and the
/// quest you WON disappeared, silently, within the hour of your last
/// check-in. The only record was a folded-shut trophy room in another
/// tab. These tests pin the three halves of the fix: a won seat is over
/// for the player, it keeps its place in the list, and opening it says
/// what happened.
Challenge _quest({
  String myStatus = 'active',
  int durationDays = 7,
  int daysAgo = 3,
  int myAura = 0,
  int strikesUsed = 0,
  int maxStrikes = 2,
  int memberCount = 1,
}) {
  final now = DateTime.now().toUtc();
  final start = DateTime.utc(now.year, now.month, now.day)
      .subtract(Duration(days: daysAgo));
  return Challenge(
    id: 'q',
    creatorId: 'a',
    title: 'Morning movement',
    description: '',
    startsOn: start,
    createdAt: start,
    durationDays: durationDays,
    auraGain: 100,
    auraPenalty: 25,
    maxStrikes: maxStrikes,
    myStatus: myStatus,
    myAura: myAura,
    strikesUsed: strikesUsed,
    memberCount: memberCount,
  );
}

QuestMember _member(String name, {int aura = 0, bool isMe = false}) =>
    QuestMember(
      userId: name,
      username: name,
      questAura: aura,
      isOwner: false,
      isMe: isMe,
      checkedToday: false,
      doneThisPeriod: false,
      checkinsThisPeriod: 0,
      gear: const [],
    );

void main() {
  group('a won seat is over, and the app knows it', () {
    test('winning is not the same as the quest being finished', () {
      // A solo quest's own lifecycle stays `active` after its last
      // participant settles — there is nobody left for it to wait on,
      // so the engine never closes it. Going by lifecycle alone would
      // make a won quest look like a running one that refuses every
      // action, which is exactly how this bug felt.
      final won = _quest(myStatus: 'completed');
      expect(won.isWon, isTrue);
      expect(won.isFinished, isFalse, reason: 'lifecycle is still active');
      expect(won.isOver, isTrue);
    });

    test('every way out counts as over', () {
      expect(_quest(myStatus: 'completed').isOver, isTrue);
      expect(_quest(myStatus: 'failed').isOver, isTrue);
      expect(_quest(myStatus: 'eliminated').isOver, isTrue);
      expect(_quest().isOver, isFalse);
    });

    test('a won quest has no comeback date — there is nothing to come back to',
        () {
      // Comebacks are for players who are behind. Offering one on a
      // quest you already won would read as "you still owe something".
      expect(_quest(myStatus: 'completed').nextComebackDate(DateTime.now()),
          isNull);
    });

    test('over for me and past its end date are different questions', () {
      // The win lands BEFORE the last day is up: on a daily quest the
      // engine settles as soon as the final check-in makes the outcome
      // certain. That is why the quest seemed to die mid-afternoon.
      final wonEarly = _quest(myStatus: 'completed', durationDays: 7);
      expect(wonEarly.isOver, isTrue);
      expect(wonEarly.isPastEnd, isFalse,
          reason: 'three days in, the calendar has not run out');

      final elapsed = _quest(durationDays: 2, daysAgo: 5);
      expect(elapsed.isPastEnd, isTrue);
    });

    test('an endless quest is never past its end', () {
      final endless = Challenge(
        id: 'q',
        creatorId: 'a',
        title: 'Forever',
        description: '',
        startsOn: DateTime.utc(2020),
        createdAt: DateTime.utc(2020),
        durationDays: 1,
        auraGain: 10,
        auraPenalty: 10,
        maxStrikes: 1,
        isEndless: true,
      );
      expect(endless.isPastEnd, isFalse);
    });
  });

  group('the card keeps a won quest in the list', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    Future<void> pump(WidgetTester tester, Challenge challenge) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          myBlackoutProvider.overrideWith((ref, id) => null),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChallengeCard(challenge: challenge),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a won quest shows DONE instead of a dead check-in button',
        (tester) async {
      await pump(tester, _quest(myStatus: 'completed', myAura: 340));

      expect(find.text('DONE'), findsOneWidget);
      expect(find.text('OUT'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a running quest is untouched', (tester) async {
      await pump(tester, _quest());

      expect(find.text('DONE'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a settled seat cannot go shopping', (tester) async {
      // The aura is frozen at its final figure; spending it afterwards
      // would rewrite a result that has already been paid out.
      await pump(tester, _quest(myStatus: 'completed', myAura: 340));

      final perks = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('PERKS'),
          matching: find.byType(TextButton),
        ),
      );
      expect(perks.onPressed, isNull);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('opening a won quest shows the scoreboard', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    Future<void> pump(
      WidgetTester tester, {
      required Challenge challenge,
      List<QuestMember> members = const [],
      double width = 400,
    }) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          myChallengesProvider.overrideWith((ref) => [challenge]),
          myCheckInsProvider.overrideWith((ref) => const {}),
          checkInsProvider.overrideWith((ref, id) => const {}),
          questMembersProvider.overrideWith((ref, id) => members),
          questDuelsProvider.overrideWith((ref, id) => []),
          questActivityProvider.overrideWith((ref, id) => []),
          questReminderProvider.overrideWith((ref, id) => null),
          myBlackoutProvider.overrideWith((ref, id) => null),
          duelStateProvider
              .overrideWith((ref, id) => throw Exception('offline fixture')),
        ],
        child: const MaterialApp(
          home: ChallengeDetailScreen(challengeId: 'q'),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the verdict leads with the result and the aura it paid',
        (tester) async {
      await pump(
        tester,
        challenge: _quest(myStatus: 'completed', myAura: 340, strikesUsed: 1),
      );

      expect(find.text('QUEST COMPLETE'), findsOneWidget);
      expect(find.text('+340'), findsOneWidget);
      expect(find.text('STRIKES'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a solo quest gets no standing — there is nobody to rank',
        (tester) async {
      await pump(
        tester,
        challenge: _quest(myStatus: 'completed', myAura: 340),
        members: [_member('me', aura: 340, isMe: true)],
      );

      expect(find.text('QUEST COMPLETE'), findsOneWidget);
      expect(find.text('FINAL STANDING'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with a party, the standing says who was better',
        (tester) async {
      // The roster already arrives ordered by final aura, so the list
      // IS the standing. If that ever stops being true, this fails.
      await pump(
        tester,
        challenge: _quest(myStatus: 'completed', myAura: 340, memberCount: 3),
        members: [
          _member('max', aura: 520),
          _member('me', aura: 340, isMe: true),
          _member('anna', aura: 90),
        ],
      );

      expect(find.text('FINAL STANDING'), findsOneWidget);
      expect(find.text('@max'), findsWidgets);
      expect(find.text('@anna'), findsWidgets);
      // The podium marks the top three. Nothing else on this screen
      // draws medals, so finding all three proves the standing itself
      // rendered rather than just its heading.
      expect(find.text('🥇'), findsOneWidget);
      expect(find.text('🥈'), findsOneWidget);
      expect(find.text('🥉'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the only button is the one that removes it', (tester) async {
      // Keeping it is the default, so there is deliberately no "keep"
      // button: doing nothing already keeps it.
      await pump(
        tester,
        challenge: _quest(myStatus: 'completed', myAura: 340),
      );

      expect(find.text('REMOVE FROM MY LIST'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a running quest shows no verdict at all', (tester) async {
      await pump(tester, challenge: _quest());

      expect(find.text('QUEST COMPLETE'), findsNothing);
      expect(find.text('REMOVE FROM MY LIST'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the scoreboard fits a 320px phone', (tester) async {
      // Three figures, a podium and a button in one panel. An overflow
      // here is a yellow-and-black bar across the moment the player
      // actually wanted to enjoy.
      await pump(
        tester,
        challenge: _quest(myStatus: 'completed', myAura: 1340, strikesUsed: 2),
        members: [
          _member('maximilian', aura: 5200),
          _member('me', aura: 1340, isMe: true),
        ],
        width: 320,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('QUEST COMPLETE'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
