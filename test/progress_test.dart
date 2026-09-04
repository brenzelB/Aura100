import 'package:aura_quest/core/text/quantity.dart';
import 'package:aura_quest/features/challenges/domain/challenge.dart';
import 'package:aura_quest/features/challenges/domain/progress_entry.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge _quest({
  required double target,
  double progress = 0,
  CheckinPeriod period = CheckinPeriod.daily,
  DateTime? startsOn,
}) =>
    Challenge(
      id: 'q',
      creatorId: 'u',
      title: 'Push-ups',
      description: '',
      durationDays: 30,
      auraGain: 100,
      auraPenalty: 50,
      maxStrikes: 1,
      startsOn: startsOn ?? DateTime.utc(2026, 7, 1),
      createdAt: DateTime.utc(2026, 7, 1),
      checkinPeriod: period,
      goalType: GoalType.progress,
      targetValue: target,
      unit: 'Reps',
      progressInPeriod: progress,
    );

ProgressEntry _entry(double amount, DateTime periodStart, int hour) =>
    ProgressEntry(
      id: '$amount-$hour',
      amount: amount,
      periodStart: periodStart,
      createdAt: DateTime.utc(
          periodStart.year, periodStart.month, periodStart.day, hour),
    );

void main() {
  group('formatQuantity', () {
    test('whole numbers lose their decimals', () {
      expect(formatQuantity(100), '100');
      expect(formatQuantity(7500.0), '7500');
      expect(formatQuantity(13), '13');
    });

    test('decimals keep only what they need', () {
      expect(formatQuantity(2.5), '2.5');
      expect(formatQuantity(2.50), '2.5');
      expect(formatQuantity(0.25), '0.25');
    });
  });

  group('parseQuantity', () {
    test('accepts both comma and dot', () {
      expect(parseQuantity('2,5'), 2.5);
      expect(parseQuantity('2.5'), 2.5);
      expect(parseQuantity(' 100 '), 100);
    });

    test('rejects junk and empty input', () {
      expect(parseQuantity(''), isNull);
      expect(parseQuantity('abc'), isNull);
      expect(parseQuantity('  '), isNull);
    });
  });

  group('Challenge progress maths', () {
    test('ratio, percent and remaining track the target', () {
      final quest = _quest(target: 100, progress: 72);
      expect(quest.isProgress, isTrue);
      expect(quest.progressPercent, 72);
      expect(quest.progressRemaining, 28);
    });

    test('overshooting clamps at 100% with nothing left to do', () {
      final quest = _quest(target: 100, progress: 130);
      expect(quest.progressRatio, 1.0);
      expect(quest.progressPercent, 100);
      expect(quest.progressRemaining, 0);
    });

    test('decimal targets work as well as whole ones', () {
      final quest = _quest(target: 2.5, progress: 1.25);
      expect(quest.progressPercent, 50);
      expect(formatProgress(1.25, 2.5, 'Liters'), '1.25 / 2.5 Liters');
    });

    test('period start is anchored to the quest start, not the calendar',
        () {
      final weekly = _quest(
        target: 10,
        period: CheckinPeriod.weekly,
        startsOn: DateTime.utc(2026, 7, 1),
      );
      // Day 0-6 -> first block, day 7 -> second block.
      expect(weekly.periodStartFor(DateTime.utc(2026, 7, 6)),
          DateTime.utc(2026, 7, 1));
      expect(weekly.periodStartFor(DateTime.utc(2026, 7, 8)),
          DateTime.utc(2026, 7, 8));
      // Before the start everything belongs to the first block.
      expect(weekly.periodStartFor(DateTime.utc(2026, 6, 20)),
          DateTime.utc(2026, 7, 1));
    });
  });

  group('ProgressPeriod.group', () {
    test('splits entries per period, newest period first', () {
      final monday = DateTime.utc(2026, 7, 6);
      final tuesday = DateTime.utc(2026, 7, 7);
      final periods = ProgressPeriod.group([
        _entry(20, monday, 8),
        _entry(40, monday, 12),
        _entry(40, monday, 19),
        _entry(50, tuesday, 9),
      ], 100);

      expect(periods.length, 2);
      // Tuesday is newer, so it leads.
      expect(periods.first.periodStart, tuesday);
      expect(periods.first.total, 50);
      expect(periods.first.reached, isFalse);
      expect(periods.first.percent, 50);

      expect(periods.last.periodStart, monday);
      expect(periods.last.total, 100);
      expect(periods.last.reached, isTrue);
      expect(periods.last.entries.length, 3);
    });

    test('entries inside a period are newest first', () {
      final day = DateTime.utc(2026, 7, 6);
      final periods = ProgressPeriod.group([
        _entry(10, day, 8),
        _entry(30, day, 20),
        _entry(20, day, 14),
      ], 100);

      final amounts = periods.single.entries.map((e) => e.amount).toList();
      expect(amounts, [30, 20, 10]);
    });

    test('no entries means no periods', () {
      expect(ProgressPeriod.group(const [], 100), isEmpty);
    });
  });
}
