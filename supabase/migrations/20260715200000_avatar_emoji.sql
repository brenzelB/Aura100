-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST - emoji avatars
--
--  Players pick any emoji from their phone keyboard as a profile
--  picture. Stored as text (one grapheme cluster — a flag or a ZWJ
--  family emoji is several codepoints, hence the generous limit).
--
--  Two cheap guards; the real "is this an emoji?" check lives in the
--  client, where grapheme clusters are actually parsable:
--   * length cap
--   * must contain a non-ASCII character (blocks 'hi' as an avatar)
-- ═════════════════════════════════════════════════════════════════

alter table public.profiles
  add column avatar_emoji text
  check (
    avatar_emoji is null
    or (char_length(avatar_emoji) between 1 and 16
        and avatar_emoji ~ '[^[:ascii:]]')
  );

-- Column-level grants stay tight: clients may write their own
-- username and now their avatar — nothing else on the profile.
grant update (avatar_emoji) on public.profiles to authenticated;
