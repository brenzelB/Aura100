import 'package:aura_quest/core/text/roasts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Roasts', () {
    test('pool holds 100-200 distinct lines, as designed', () {
      expect(Roasts.lines.length, inInclusiveRange(100, 200));
      expect(Roasts.lines.toSet().length, Roasts.lines.length,
          reason: 'duplicate roasts waste slots in the pool');
    });

    test('random() always returns a line from the pool', () {
      for (var i = 0; i < 500; i++) {
        expect(Roasts.lines, contains(Roasts.random()));
      }
    });

    test('no line is empty or whitespace-padded', () {
      for (final line in Roasts.lines) {
        expect(line.trim(), line);
        expect(line, isNotEmpty);
      }
    });
  });
}
