import 'package:flutter_test/flutter_test.dart';
import 'package:aura_quest/core/content/community_content_filter.dart';

void main() {
  group('CommunityContentFilter', () {
    test('blocks profanity as a complete word', () {
      expect(CommunityContentFilter.containsBlockedWord('fuck'), isTrue);
      expect(CommunityContentFilter.containsBlockedWord('f.u.c.k'), isTrue);
      expect(CommunityContentFilter.containsBlockedWord('Hürensohn'), isTrue);
    });

    test('does not reject clean words containing similar letters', () {
      expect(CommunityContentFilter.containsBlockedWord('classic reading'),
          isFalse);
      expect(CommunityContentFilter.containsBlockedWord('Morning workout'),
          isFalse);
    });

    test('treats punctuation and repeated spaces as separators', () {
      expect(CommunityContentFilter.containsBlockedWord('f.u.c.k'), isTrue);
      expect(CommunityContentFilter.containsBlockedWord('f u c k'), isTrue);
      expect(
          CommunityContentFilter.containsBlockedWord('a clean quest'), isFalse);
      expect(CommunityContentFilter.containsBlockedWord('one  two\nthree'),
          isFalse);
    });
  });
}
