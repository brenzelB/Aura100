import 'package:aura_quest/core/text/hype.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hype', () {
    test('both pools are non-trivial and free of duplicates', () {
      for (final pool in [
        List.generate(200, (_) => Hype.forStreak()).toSet(),
        List.generate(200, (_) => Hype.forCompletion()).toSet(),
      ]) {
        expect(pool.length, greaterThanOrEqualTo(10));
        for (final line in pool) {
          expect(line.trim(), line);
          expect(line, isNotEmpty);
        }
      }
    });

    test('streak and completion lines never overlap', () {
      final streak = List.generate(300, (_) => Hype.forStreak()).toSet();
      final done = List.generate(300, (_) => Hype.forCompletion()).toSet();
      expect(streak.intersection(done), isEmpty);
    });
  });
}
