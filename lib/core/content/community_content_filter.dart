/// Small local pre-check for profile names and quest text.
///
/// The database applies the same word list as the authoritative filter, so a
/// modified client cannot bypass it. This client check exists to explain a
/// rejected phrase before making a network request.
abstract final class CommunityContentFilter {
  static const Set<String> _blockedWords = {
    'arschloch',
    'bastard',
    'bitch',
    'cunt',
    'dick',
    'fag',
    'faggot',
    'fuck',
    'fucker',
    'fucking',
    'hure',
    'huerensohn',
    'hurensohn',
    'motherfucker',
    'nigger',
    'nutte',
    'piss',
    'porn',
    'pussy',
    'scheisse',
    'schlampe',
    'schwanz',
    'schwuchtel',
    'shit',
    'slut',
    'whore',
    'wichser',
  };

  static bool containsBlockedWord(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return false;
    return _blockedWords.any((word) {
      // Match whole words while allowing punctuation or whitespace between
      // letters (for example `f.u.c.k`). Keep boundaries around the word so
      // ordinary text such as "classic" is not rejected as a substring.
      final separatedLetters = word.split('').join(r'[^a-z0-9]*');
      return RegExp('(^|[^a-z0-9])$separatedLetters([^a-z0-9]|\$)')
          .hasMatch(normalized);
    });
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}
