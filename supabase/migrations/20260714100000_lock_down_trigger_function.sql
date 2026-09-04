-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST - security hardening (from Supabase advisor):
--  handle_new_user is a TRIGGER function and must never be callable
--  through the Data API. Functions get EXECUTE for PUBLIC by default,
--  so revoke it explicitly. The auth trigger itself is unaffected
--  (triggers fire as the table owner, not via EXECUTE grants).
-- ═════════════════════════════════════════════════════════════════

revoke execute on function public.handle_new_user() from public, anon, authenticated;
