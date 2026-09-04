-- =================================================================
--  AURA QUEST - poke (nudge) rework
--
--  Pokes had no "seen" state, so the Home inbox kept showing them for
--  24h even after you'd looked. Now:
--    * seen_at  — a poke leaves the inbox the moment you dismiss it,
--                 react to it, or simply check in on that quest.
--    * reaction — the recipient can fire ONE emoji back. It surfaces in
--                 the sender's PASSIVE poke-back feed (never the inbox),
--                 and the sender only ever sees it once. Terminal on both
--                 ends → no ping-pong loop by construction.
-- =================================================================

alter table public.nudges
  add column if not exists seen_at          timestamptz,
  add column if not exists reaction         text,
  add column if not exists reaction_seen_at timestamptz;

-- Keep reactions to a known, safe little set.
alter table public.nudges drop constraint if exists nudges_reaction_check;
alter table public.nudges add constraint nudges_reaction_check
  check (reaction is null or reaction in ('💪','🔥','👍','😤','🙏'));

create index if not exists nudges_inbox_idx
  on public.nudges (to_user) where seen_at is null;
create index if not exists nudges_pokeback_idx
  on public.nudges (from_user) where reaction is not null and reaction_seen_at is null;

-- ── Checking in clears that quest's pokes (they did their job) ────
create or replace function public.mark_pokes_seen_on_checkin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.nudges
  set seen_at = now()
  where challenge_id = new.challenge_id
    and to_user = new.user_id
    and seen_at is null;
  return new;
end;
$$;

drop trigger if exists trg_pokes_seen_on_checkin on public.check_ins;
create trigger trg_pokes_seen_on_checkin
  after insert on public.check_ins
  for each row execute function public.mark_pokes_seen_on_checkin();

-- ── Recipient: dismiss a quest's pokes (no reaction) ─────────────
create or replace function public.dismiss_quest_pokes(p_challenge_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_count   integer;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  update public.nudges
  set seen_at = now()
  where challenge_id = p_challenge_id
    and to_user = v_user_id
    and seen_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.dismiss_quest_pokes(uuid) from public, anon;
grant  execute on function public.dismiss_quest_pokes(uuid) to authenticated;

-- ── Recipient: react to a quest's pokes (one emoji to every poker) ─
--    Marks them seen too. Terminal: never notifies via the inbox.
create or replace function public.react_to_quest_pokes(
  p_challenge_id uuid,
  p_reaction text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_count   integer;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if p_reaction not in ('💪','🔥','👍','😤','🙏') then
    raise exception 'Unknown reaction.';
  end if;
  update public.nudges
  set seen_at = coalesce(seen_at, now()),
      reaction = p_reaction
  where challenge_id = p_challenge_id
    and to_user = v_user_id
    and seen_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.react_to_quest_pokes(uuid, text) from public, anon;
grant  execute on function public.react_to_quest_pokes(uuid, text) to authenticated;

-- ── Sender: acknowledge the poke-backs they've now seen ──────────
create or replace function public.ack_poke_backs()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_count   integer;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  update public.nudges
  set reaction_seen_at = now()
  where from_user = v_user_id
    and reaction is not null
    and reaction_seen_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.ack_poke_backs() from public, anon;
grant  execute on function public.ack_poke_backs() to authenticated;
