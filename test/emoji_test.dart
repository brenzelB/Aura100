import 'package:flutter_test/flutter_test.dart';

import 'package:aura_quest/features/profile/domain/emoji.dart';

void main() {
  group('EmojiUtils.isEmoji', () {
    test('accepts plain emojis', () {
      for (final emoji in ['😀', '🔥', '⚡', '🏆', '🎮', '💪', '🚀']) {
        expect(EmojiUtils.isEmoji(emoji), isTrue, reason: emoji);
      }
    });

    test('accepts multi-codepoint emojis', () {
      expect(EmojiUtils.isEmoji('❤️'), isTrue); // + variation selector
      expect(EmojiUtils.isEmoji('🇩🇪'), isTrue); // flag (2 regional indicators)
      expect(EmojiUtils.isEmoji('👨‍👩‍👧'), isTrue); // ZWJ family
      expect(EmojiUtils.isEmoji('👍🏽'), isTrue); // skin tone modifier
    });

    test('rejects text, digits and symbols', () {
      for (final text in ['a', 'Z', '5', '', ' ', 'hi', '€', '@']) {
        expect(EmojiUtils.isEmoji(text), isFalse, reason: '"$text"');
      }
    });
  });

  group('EmojiUtils.extractLast', () {
    test('returns the emoji from mixed keyboard input', () {
      expect(EmojiUtils.extractLast('hello 🔥'), '🔥');
      expect(EmojiUtils.extractLast('🔥'), '🔥');
    });

    test('returns the LAST emoji when several were typed', () {
      expect(EmojiUtils.extractLast('😀🔥🚀'), '🚀');
    });

    test('keeps multi-codepoint emojis intact', () {
      expect(EmojiUtils.extractLast('my flag 🇩🇪'), '🇩🇪');
      expect(EmojiUtils.extractLast('👨‍👩‍👧'), '👨‍👩‍👧');
      expect(EmojiUtils.extractLast('nice 👍🏽'), '👍🏽');
    });

    test('returns null without an emoji', () {
      expect(EmojiUtils.extractLast(''), isNull);
      expect(EmojiUtils.extractLast('just text'), isNull);
    });
  });
}
