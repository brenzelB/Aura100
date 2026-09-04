-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST — Phase 4c: daily check-ins + secure aura updates
--  Runs identically as a local CLI migration and in the hosted
--  project's SQL Editor.
-- ═════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- 1. CHECK_INS — one row per user, challenge and day
--    A real log table (not a counter) so streaks and feeds can be
--    built on it later without another migration.
-- ─────────────────────────────────────────────────────────────────
create table public.check_ins (
  id            uuid primary key default gen_random_uuid(),
  challenge_id  uuid not null references public.challenges (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  -- Day boundary is UTC for now; per-user timezones are a later phase.
  checked_on    date not null default (now() at time zone 'utc')::date,
  created_at    timestamptz not null default now(),
  -- THE core rule: one check-in per challenge per day. Enforced by the
  -- database itself, so it holds even under concurrent requests.
  unique (challenge_id, user_id, checked_on)
);

create index check_ins_user_id_idx on public.check_ins (user_id);

alter table public.check_ins enable row level security;

-- Clients may READ their own check-ins (the UI needs "done today?")...
grant select on public.check_ins to authenticated;

create policy "check_ins: users read their own"
  on public.check_ins for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- ...but clients may NOT write check-ins at all: no insert/update/delete
-- grants. The ONLY write path is the log_check_in function below —
-- check-ins can't be fabricated, edited or deleted from the app.


-- ─────────────────────────────────────────────────────────────────
-- 2. LOG_CHECK_IN — validate, log, reward. Atomically.
--
--    SECURITY DEFINER (deliberate, and the exception that proves the
--    rule): `total_aura` is intentionally NOT client-writable (column
--    grants only expose `username`), so an INVOKER function could
--    never add aura. DEFINER runs as the function owner and is safe
--    here because it:
--      * pins search_path to '' (no object spoofing),
--      * derives the acting user from auth.uid() — never from a
--        parameter, so you can only ever reward YOURSELF,
--      * validates participation + challenge window before writing,
--      * is executable by `authenticated` only (revoked otherwise).
--    Single function call = single transaction: the check-in row and
--    the aura update land together or not at all.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.log_check_in(p_challenge_id uuid)
returns integer  -- the aura gained, for immediate UI feedback
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id   uuid := (select auth.uid());
  v_challenge public.challenges%rowtype;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_challenge
  from public.challenges
  where id = p_challenge_id;

  if not found then
    raise exception 'Quest not found.';
  end if;

  if v_challenge.created_at
       + make_interval(days => v_challenge.duration_days) < now() then
    raise exception 'This quest has already ended.';
  end if;

  if not exists (
    select 1
    from public.challenge_participants
    where challenge_id = p_challenge_id
      and user_id = v_user_id
      and status = 'active'
  ) then
    raise exception 'You are not an active participant of this quest.';
  end if;

  -- The unique constraint is the once-per-day gatekeeper.
  begin
    insert into public.check_ins (challenge_id, user_id)
    values (p_challenge_id, v_user_id);
  exception when unique_violation then
    raise exception 'Already checked in today — come back tomorrow!';
  end;

  update public.profiles
  set total_aura = total_aura + v_challenge.aura_gain
  where id = v_user_id;

  return v_challenge.aura_gain;
end;
$$;

-- Lock execution down to signed-in users.
revoke execute on function public.log_check_in(uuid) from public, anon;
grant execute on function public.log_check_in(uuid) to authenticated;
