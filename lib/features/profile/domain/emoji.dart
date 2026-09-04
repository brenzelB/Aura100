import 'package:characters/characters.dart';

/// Emoji handling for avatars. Pure logic — unit-testable.
///
/// The picker feeds this whatever the system keyboard produced, which
/// may be letters, several emojis, or a single emoji built from many
/// codepoints (flags, skin tones, ZWJ families).
abstract class EmojiUtils {
  /// True when [grapheme] — ONE grapheme cluster — is an emoji.
  ///
  /// Checks whether any codepoint falls in an emoji block, or carries
  /// the emoji variation selector. Plain letters, digits and currency
  /// signs are rejected.
  static bool isEmoji(String grapheme) {
    if (grapheme.isEmpty) return false;
    return grapheme.runes.any((r) =>
            // Emoticons, pictographs, transport, supplemental...
            (r >= 0x1F000 && r <= 0x1FAFF) ||
            // Regional indicators (flags are two of these).
            (r >= 0x1F1E6 && r <= 0x1F1FF) ||
            // Misc symbols + dingbats (☀ ✂ ❤ ...).
            (r >= 0x2600 && r <= 0x27BF) ||
            // Misc technical (⌚ ⏳ ...).
            (r >= 0x2300 && r <= 0x23FF) ||
            // Arrows / stars / misc symbols-and-arrows (⭐ ⬛ ...).
            (r >= 0x2B00 && r <= 0x2BFF) ||
            r == 0x203C || // ‼
            r == 0x2049 || // ⁉
            // VS-16: forces emoji presentation (❤️, ™️).
            r == 0xFE0F);
  }

  /// Picks the emoji a user meant from raw keyboard input: the LAST
  /// emoji typed. Returns null when there is none — so letters simply
  /// don't change the avatar.
  ///
  /// Uses grapheme clusters, so 🇩🇪 or 👨‍👩‍👧 survive as one piece.
  static String? extractLast(String input) {
    if (input.isEmpty) return null;
    for (final grapheme in input.characters.toList().reversed) {
      if (isEmoji(grapheme)) return grapheme;
    }
    return null;
  }
}
