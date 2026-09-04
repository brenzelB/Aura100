-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST — Phase 4a: challenge duration + atomic create RPC
--  Runs identically as a local CLI migration and in the hosted
--  project's SQL Editor.
-- ═════════════════════════════════════════════════════════════════

-- ── 1. How long a challenge runs ─────────────────────────────────
alter table public.challenges
  add column duration_days integer not null default 7
  check (duration_days between 1 and 365);

-- ── 2. Atomic "create challenge + join it" ───────────────────────
-- Creating a challenge and adding the creator as its first participant
-- must happen together: two separate client inserts could leave an
-- orphaned challenge if the second one fails. A function runs both in
-- ONE transaction.
--
-- SECURITY INVOKER (the default, stated for clarity): the caller's own
-- RLS policies still apply, so this cannot be used to create rows for
-- other users — creator_id/user_id are forced to auth.uid() anyway.
create or replace function public.create_challenge(
  p_title text,
  p_duration_days integer,
  p_aura_gain integer,
  p_aura_penalty integer
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_challenge_id uuid;
begin
  insert into public.challenges (creator_id, title, duration_days, aura_gain, aura_penalty)
  values ((select auth.uid()), p_title, p_duration_days, p_aura_gain, p_aura_penalty)
  returning id into v_challenge_id;

  insert into public.challenge_participants (challenge_id, user_id)
  values (v_challenge_id, (select auth.uid()));

  return v_challenge_id;
end;
$$;

-- Functions are not auto-exposed to the Data API roles (same as tables).
grant execute on function public.create_challenge(text, integer, integer, integer)
  to authenticated;
