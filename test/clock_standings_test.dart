import 'package:aura_quest/core/text/dates.dart';
import 'package:aura_quest/features/challenges/application/challenge_providers.dart';
import 'package:aura_quest/features/challenges/domain/challenge.dart';
import 'package:aura_quest/features/challenges/domain/quest_activity.dart';
import 'package:aura_quest/features/challenges/domain/quest_member.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/quest_activity_section.dart';
import 'package:aura_quest/features/challenges/presentation/widgets/quest_party_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reading a CLOCK quest's record: what happened, when, and who is ahead.
///
/// The bug this covers is a quiet one. The activity feed stamped every
/// row with the age of the ROW — "1d" for anything banked between 24
/// and 48 hours ago — which is unreadable for something measured in
/// hours. And the party was ranked by the current period, so on a daily
/// quest the standings emptied every midnight and first place went to
/// whoever logged first.
Challenge _quest({bool clock = true, double target = 960}) => Challenge(
      id: 'q',
      creatorId: 'u',
      title: 'Fasting',
      description: '',
      durationDays: 30,
      auraGain: 100,
      auraPenalty: 50,
      maxStrikes: 1,
      startsOn: DateTime.utc(2026, 11, 1),
      createdAt: DateTime.utc(2026, 11, 1),
      checkinPeriod: CheckinPeriod.daily,
      goalType: GoalType.progress,
      tracking: clock ? QuestTracking.clock : QuestTracking.manual,
      targetValue: target,
      unit: clock ? 'min' : 'Reps',
    );

QuestMember _member(
  String name, {
  double period = 0,
  double today = 0,
  double week = 0,
  double month = 0,
}) =>
    QuestMember(
      userId: name,
      username: name,
      questAura: 0,
      isOwner: false,
      isMe: false,
      checkedToday: false,
      doneThisPeriod: false,
      checkinsThisPeriod: 0,
      gear: const [],
      progressInPeriod: period,
      progressToday: today,
      progressThisWeek: week,
      progressThisMonth: month,
    );

QuestActivity _run({
  required DateTime createdAt,
  DateTime? startedAt,
  DateTime? endedAt,
  num amount = 600,
  String kind = 'progress',
}) =>
    QuestActivity(
      kind: kind,
      username: 'max',
      isMe: false,
      createdAt: createdAt,
      amount: amount,
      startedAt: startedAt,
      endedAt: endedAt,
    );

/// Midnight at the start of today, in LOCAL time — the anchor every
/// date in these tests hangs off, so none of them depend on the hour
/// the suite happens to run at.
DateTime _todayAt(int hours) =>
    DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
        .add(Duration(hours: hours));

void main() {
  group('formatRunDay', () {
    // A fixed "now" so the names are not at the mercy of the calendar.
    // 2026-11-04 is a Wednesday.
    final now = DateTime(2026, 11, 4, 12);

    test('the near past gets a name, not a number', () {
      expect(formatRunDay(DateTime(2026, 11, 4, 6), now: now), 'today');
      expect(formatRunDay(DateTime(2026, 11, 3, 23), now: now), 'yesterday');
    });

    test('inside the last week, the weekday is the readable handle', () {
      expect(formatRunDay(DateTime(2026, 11, 2, 20), now: now), 'Mon');
      expect(formatRunDay(DateTime(2026, 10, 30, 8), now: now), 'Fri');
    });

    test('older than a week, a weekday would be a riddle', () {
      // "Tue" three weeks back tells you nothing, so it becomes a date.
      expect(formatRunDay(DateTime(2026, 10, 13, 8), now: now), 'Oct 13');
    });

    test('a stamp from the future degrades to a date rather than lying', () {
      expect(formatRunDay(DateTime(2026, 11, 9, 8), now: now), 'Nov 9');
    });
  });

  group('formatSpan', () {
    test('a run inside one day needs no day markers', () {
      expect(
        formatSpan(DateTime(2026, 11, 3, 8, 15), DateTime(2026, 11, 3, 12, 30)),
        '08:15 → 12:30',
      );
    });

    test('crossing midnight, the days have to be named', () {
      // Without this, "20:00 → 06:00" reads as a ten-hour run that went
      // backwards.
      expect(
        formatSpan(DateTime(2026, 11, 2, 20, 0), DateTime(2026, 11, 3, 6, 0)),
        'Mon 20:00 → Tue 06:00',
      );
    });
  });

  group('QuestActivity dating', () {
    test('a measured run is dated by when it ended, not when it was banked',
        () {
      // Stop the clock at 06:00, bank it at 09:00 — the fast happened at
      // six, and that is the day it belongs to.
      final item = _run(
        createdAt: DateTime.utc(2026, 11, 3, 9),
        startedAt: DateTime.utc(2026, 11, 2, 20),
        endedAt: DateTime.utc(2026, 11, 3, 6),
      );
      expect(item.happenedAt, DateTime.utc(2026, 11, 3, 6));
      expect(item.hasSpan, isTrue);
    });

    test('without a session, the banking moment is the best answer there is',
        () {
      final item = _run(createdAt: DateTime.utc(2026, 11, 3, 9));
      expect(item.happenedAt, DateTime.utc(2026, 11, 3, 9));
      expect(item.hasSpan, isFalse);
    });

    test('half a span is no span', () {
      // A session still running has no end, and half of one would print
      // as a broken arrow.
      final item = _run(
        createdAt: DateTime.utc(2026, 11, 3, 9),
        startedAt: DateTime.utc(2026, 11, 2, 20),
      );
      expect(item.hasSpan, isFalse);
    });
  });

  group('the feed dates a run by its day', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    Future<void> pump(
      WidgetTester tester, {
      required Challenge challenge,
      required List<QuestActivity> feed,
    }) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          questActivityProvider('q').overrideWith((ref) async => feed),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuestActivitySection(challenge: challenge),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a clock run reads as a day and a span, not as a row age',
        (tester) async {
      await pump(tester, challenge: _quest(), feed: [
        _run(
          createdAt: _todayAt(-1), // banked yesterday at 23:00
          startedAt: _todayAt(-4), // yesterday 20:00
          endedAt: _todayAt(-1), // yesterday 23:00
        ),
      ]);

      expect(find.text('yesterday'), findsOneWidget);
      expect(find.text('20:00 → 23:00'), findsOneWidget);
      // The amount is still a time, not a minute count. The sentence is
      // a RichText (the name is bold, the verb is coloured), so the
      // finder has to be told to look inside the spans.
      expect(
          find.textContaining('+10h 00m', findRichText: true), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a typed quest keeps the row age — nothing was measured',
        (tester) async {
      await pump(tester, challenge: _quest(clock: false), feed: [
        _run(createdAt: _todayAt(-1), amount: 20),
      ]);

      expect(find.text('yesterday'), findsNothing);
      expect(find.textContaining('→'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('news on a clock quest stays news: a strike keeps its age',
        (tester) async {
      // Only measured runs are dated by day. A strike is something that
      // just happened to you, and "2h ago" is the useful framing.
      await pump(tester, challenge: _quest(), feed: [
        _run(createdAt: _todayAt(-1), kind: 'strike', amount: 1),
      ]);

      expect(find.text('yesterday'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the party is a standing, not a snapshot', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    Future<void> pump(
      WidgetTester tester, {
      required Challenge challenge,
      required List<QuestMember> members,
    }) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          questMembersProvider('q').overrideWith((ref) async => members),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuestPartySection(challenge: challenge),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('each member carries their day, week and month',
        (tester) async {
      await pump(tester, challenge: _quest(), members: [
        _member('max', period: 602, today: 602, week: 3492, month: 12750),
      ]);

      // Minutes never reach a player raw: 3492 is "58h 12m".
      expect(find.textContaining('10h 02m'), findsWidgets);
      expect(find.textContaining('58h 12m'), findsWidgets);
      expect(find.textContaining('212h 30m'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the week decides the order, not today', (tester) async {
      // Anna is ahead today but behind on the week. Ranked by the period
      // she would be first, and the standings would reshuffle every
      // midnight.
      await pump(tester, challenge: _quest(), members: [
        _member('anna', period: 900, today: 900, week: 1800, month: 1800),
        _member('max', period: 300, today: 300, week: 5400, month: 5400),
      ]);

      expect(find.text('Ranked by this week'), findsOneWidget);

      final names = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((t) => t == '@max' || t == '@anna')
          .toList();
      expect(names, ['@max', '@anna'],
          reason: 'the bigger week comes first, however today went');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('three totals still fit on a 320px phone', (tester) async {
      // "today 10h 02m · week 58h 12m · month 212h 30m" is a long line
      // in a tile that is already indented 52px. An overflow here is a
      // yellow-and-black bar across a player's screen, so it gets its
      // own test rather than being noticed in a screenshot later.
      await tester.pumpWidget(ProviderScope(
        overrides: [
          questMembersProvider('q').overrideWith((ref) async => [
                _member('maximilian',
                    period: 602, today: 602, week: 3492, month: 12750),
              ]),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 320,
                child: QuestPartySection(challenge: _quest()),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('212h 30m'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a typed quest is left alone — no times, no ranking',
        (tester) async {
      await pump(tester, challenge: _quest(clock: false), members: [
        _member('max', period: 40, today: 40, week: 200, month: 800),
      ]);

      expect(find.text('Ranked by this week'), findsNothing);
      expect(find.textContaining('month'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
