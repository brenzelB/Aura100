-- =================================================================
--  AURA QUEST - CLOCK quests
--
--  A quest can now be filled by a STOPWATCH instead of a keypad:
--  start the clock when you begin fasting (or reading, or training),
--  stop it when you stop. The elapsed time is the amount.
--
--  CLOCK IS NOT A FOURTH GOAL TYPE. A clock quest *is* a progress
--  quest - you collect towards a target per period. What differs is
--  only how the amount is captured. So this is an input mode on the
--  existing goal type, not a new one, and the whole game engine
--  (add_progress, log_check_in, settle_periods, strikes, aura,
--  co-op/versus, the timeline) needs no changes at all.
--
--  The clock itself never lives in the app. Only `started_at` is
--  stored; the app renders now - started_at. That survives an app
--  restart, flight mode and a new phone.
--
--  WHICH DAY DOES A FAST COUNT ON? The day it ENDED. A fast from
--  20:00 to 14:00 is one 18-hour entry on the second day, not two
--  split halves. One row, nothing synthetic, and "longest single
--  hold" stays computable from the interval.
-- =================================================================

-- ─────────────────────────────────────────────────────────────────
-- 1. The input mode.
-- ─────────────────────────────────────────────────────────────────
alter table public.challenges
  add column if not exists tracking text not null default 'manual';

alter table public.challenges drop constraint if exists challenges_tracking_check;
alter table public.challenges add constraint challenges_tracking_check
  check (tracking in ('manual', 'clock'));

-- A stopwatch only makes sense where amounts are collected. Ticking a
-- box or avoiding something has nothing for it to measure.
alter table public.challenges drop constraint if exists challenges_clock_is_progress;
alter table public.challenges add constraint challenges_clock_is_progress
  check (tracking = 'manual' or goal_type = 'progress');

-- ─────────────────────────────────────────────────────────────────
-- 2. SESSIONS - one row per stretch of time, open while it runs.
-- ─────────────────────────────────────────────────────────────────
create table if not exists public.clock_sessions (
  id           uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  started_at   timestamptz not null,
  -- Null while the clock is running.
  ended_at     timestamptz,
  -- The progress entry this became on stopping. Kept so a finished
  -- session can be traced back to its interval; the entry may be
  -- edited or deleted through the existing history, hence ON DELETE
  -- SET NULL rather than CASCADE - losing the entry must not erase
  -- the record that the session happened.
  entry_id     uuid references public.progress_entries(id) on delete set null,
  created_at   timestamptz not null default now(),
  constraint clock_sessions_ends_after_start
    check (ended_at is null or ended_at > started_at)
);

create index if not exists clock_sessions_lookup
  on public.clock_sessions (challenge_id, user_id, started_at desc);

-- You cannot be fasting twice in the same quest at the same time.
create unique index if not exists clock_sessions_one_open
  on public.clock_sessions (challenge_id, user_id)
  where ended_at is null;

alter table public.clock_sessions enable row level security;
grant select on public.clock_sessions to authenticated;

-- Same visibility as check-ins and progress: quest-mates see each
-- other, which is what makes "Max has been fasting for 14h" possible.
drop policy if exists "clock: quest members read each other" on public.clock_sessions;
create policy "clock: quest members read each other"
  on public.clock_sessions for select
  to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.challenge_participants me
      where me.challenge_id = clock_sessions.challenge_id
        and me.user_id = (select auth.uid())
    )
  );

-- Sessions only enter through the RPCs below, so there is deliberately
-- no insert/update/delete policy.

-- ─────────────────────────────────────────────────────────────────
-- 3. START - the clock begins. Nothing is scored yet.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.clock_start(p_challenge_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id   uuid := (select auth.uid());
  v_challenge public.challenges%rowtype;
  v_today     date := (now() at time zone 'utc')::date;
  v_started   timestamptz := now();
  v_id        uuid;
begin
  perform public.lock_game_state();
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_challenge
  from public.challenges where id = p_challenge_id;
  if not found then
    raise exception 'Quest not found.';
  end if;
  if v_challenge.tracking <> 'clock' then
    raise exception 'This quest is not tracked by a clock.';
  end if;
  if v_challenge.lifecycle = 'lobby' then
    raise exception 'This quest has not started yet.';
  end if;
  if v_challenge.lifecycle = 'finished' then
    raise exception 'This quest is over.';
  end if;
  if v_today < v_challenge.starts_on then
    raise exception 'This quest has not started yet.';
  end if;
  if not v_challenge.is_endless
     and v_today >= v_challenge.starts_on + v_challenge.duration_days then
    raise exception 'This quest has already ended.';
  end if;

  perform public.assert_active_participant(p_challenge_id);

  -- The unique partial index would reject this anyway; saying it in
  -- words beats showing the player a constraint violation.
  if exists (
    select 1 from public.clock_sessions
    where challenge_id = p_challenge_id
      and user_id = v_user_id
      and ended_at is null
  ) then
    raise exception 'The clock is already running.';
  end if;

  insert into public.clock_sessions (challenge_id, user_id, started_at)
  values (p_challenge_id, v_user_id, v_started)
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'started_at', v_started);
end;
$$;

revoke execute on function public.clock_start(uuid) from public, anon;
grant  execute on function public.clock_start(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- 4. STOP - the elapsed time becomes a normal progress entry.
--
--  The end time is adjustable, because forgetting to stop is the
--  single most common way this kind of tracking goes wrong: you eat
--  at 13:00 and remember at 22:00. Without a correctable end time the
--  data is worthless inside a week.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.clock_stop(
  p_challenge_id uuid,
  p_ended_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_session public.clock_sessions%rowtype;
  v_end     timestamptz := coalesce(p_ended_at, now());
  v_minutes numeric;
  v_result  jsonb;
  v_entry   uuid;
begin
  perform public.lock_game_state();
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_session
  from public.clock_sessions
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and ended_at is null
  for update;
  if not found then
    raise exception 'The clock is not running.';
  end if;

  if v_end > now() then
    raise exception 'The clock cannot stop in the future.';
  end if;
  if v_end <= v_session.started_at then
    raise exception 'The end has to come after the start.';
  end if;

  -- The entry is filed on the day it ENDED, and add_progress always
  -- files on today. Backdating across the UTC date line would put the
  -- time in the wrong period, so it is refused here rather than
  -- silently misfiled; the history can still be corrected afterwards.
  if (v_end at time zone 'utc')::date <> (now() at time zone 'utc')::date then
    raise exception
      'That end time is on an earlier day. Stop the clock, then correct the entry in the history.';
  end if;

  v_minutes := round(extract(epoch from (v_end - v_session.started_at)) / 60.0, 2);
  if v_minutes > 43200 then
    raise exception 'A single session cannot be longer than 30 days.';
  end if;

  update public.clock_sessions
  set ended_at = v_end
  where id = v_session.id;

  -- Everything downstream - the period total, the check-in, the aura
  -- payout, Double Down, streaks, co-op and versus - happens in here.
  v_result := public.add_progress(p_challenge_id, v_minutes);

  -- add_progress does not hand back the row it wrote. We hold the game
  -- lock for the whole transaction, so no other entry can have landed
  -- in between: the newest one is ours.
  select id into v_entry
  from public.progress_entries
  where challenge_id = p_challenge_id
    and user_id = v_user_id
  order by created_at desc, id desc
  limit 1;

  update public.clock_sessions
  set entry_id = v_entry
  where id = v_session.id;

  return v_result
    || jsonb_build_object(
         'minutes', v_minutes,
         'session_id', v_session.id,
         'started_at', v_session.started_at,
         'ended_at', v_end
       );
end;
$$;

revoke execute on function public.clock_stop(uuid, timestamptz) from public, anon;
grant  execute on function public.clock_stop(uuid, timestamptz) to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- 5. DISCARD - started by accident. Nothing is scored, nothing kept.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.clock_discard(p_challenge_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_count   integer;
begin
  perform public.lock_game_state();
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  delete from public.clock_sessions
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and ended_at is null;

  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

revoke execute on function public.clock_discard(uuid) from public, anon;
grant  execute on function public.clock_discard(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- 6. CREATE_CHALLENGE + the input mode.
--
--  A clock quest is always a progress quest measured in minutes, so
--  both are forced here rather than demanded of the caller. Minutes
--  (not hours) is the stored unit: it keeps the target a whole number
--  for every sane goal, and the interface formats it as "16h 00m".
-- ─────────────────────────────────────────────────────────────────
drop function if exists public.create_challenge(
  text,integer,integer,integer,integer,date,text,text,integer,text,text,
  numeric,text,boolean,integer,smallint[],text,boolean);

create or replace function public.create_challenge(
  p_title text,
  p_duration_days integer,
  p_aura_gain integer,
  p_aura_penalty integer,
  p_max_strikes integer default 1,
  p_starts_on date default null::date,
  p_description text default ''::text,
  p_checkin_period text default 'daily'::text,
  p_checkins_per_period integer default 1,
  p_mode text default 'solo'::text,
  p_goal_type text default 'check'::text,
  p_target_value numeric default null::numeric,
  p_unit text default null::text,
  p_is_endless boolean default false,
  p_daily_allowance integer default 0,
  p_active_weekdays smallint[] default '{1,2,3,4,5,6,7}'::smallint[],
  p_balance_preset text default 'custom',
  p_attacks_enabled boolean default true,
  p_tracking text default 'manual'
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_challenge_id uuid;
  v_per integer := p_checkins_per_period;
  v_unit text := nullif(trim(coalesce(p_unit, '')), '');
  v_endless boolean := p_is_endless or p_mode = 'last_man_standing';
  v_lifecycle text := case when p_mode = 'last_man_standing' then 'lobby' else 'active' end;
  v_allowance integer := coalesce(p_daily_allowance, 0);
  v_tracking text := coalesce(p_tracking, 'manual');
begin
  perform public.lock_game_state();
  if v_tracking not in ('manual', 'clock') then raise exception 'Invalid tracking mode.'; end if;
  -- A stopwatch has nothing to measure on a tick-box or an avoid quest.
  if v_tracking = 'clock' then
    p_goal_type := 'progress';
    v_unit := 'min';
  end if;
  if p_balance_preset is null or p_balance_preset not in ('chill','classic','chaos','custom') or p_attacks_enabled is null then raise exception 'Invalid balance preset.'; end if;
  if p_balance_preset<>'custom' then
    p_aura_gain:=100;
    p_aura_penalty:=case p_balance_preset when 'chill' then 10 when 'classic' then 25 else 50 end;
    p_max_strikes:=case p_balance_preset when 'chill' then 5 when 'classic' then 3 else 1 end;
    p_attacks_enabled:=p_balance_preset<>'chill';
  end if;
  if p_starts_on<(now() at time zone 'utc')::date then raise exception 'New quests cannot start in the past.'; end if;
  if v_user_id is null then raise exception 'Not signed in.'; end if;
  if p_title is null or length(trim(p_title)) between 1 and 80 is not true then raise exception 'Title must be 1-80 characters.'; end if;
  if char_length(coalesce(p_description, '')) > 500 then raise exception 'Description must be at most 500 characters.'; end if;
  if p_duration_days not between 1 and 365 then raise exception 'Duration must be 1-365 days.'; end if;
  if p_aura_gain not between 0 and 10000 or p_aura_penalty not between 0 and 10000 then raise exception 'Aura values must be 0-10000.'; end if;
  if p_max_strikes not between 0 and 10 then raise exception 'Strikes must be 0-10.'; end if;
  if p_checkin_period not in ('daily', 'weekly', 'monthly') then raise exception 'Invalid check-in period.'; end if;
  if p_mode not in ('solo', 'coop', 'versus', 'last_man_standing') then raise exception 'Invalid quest mode.'; end if;
  if p_goal_type not in ('check', 'progress', 'avoid') then raise exception 'Invalid goal type.'; end if;
  if v_endless and p_mode = 'versus' then raise exception 'Versus quests need a fixed end date.'; end if;

  if p_goal_type = 'progress' then
    v_per := 1;
    v_allowance := 0;
    if p_target_value is null or p_target_value <= 0 then raise exception 'Set a target greater than 0.'; end if;
    if p_target_value > 1000000 then raise exception 'Target must be at most 1000000.'; end if;
    if v_unit is null or length(v_unit) > 24 then raise exception 'Give the target a unit (max 24 characters).'; end if;
    -- 24h a day is the ceiling for a daily clock; weekly/monthly scale.
    if v_tracking = 'clock'
       and p_target_value > 1440 * (case p_checkin_period
             when 'daily' then 1 when 'weekly' then 7 else 30 end) then
      raise exception 'A time goal cannot exceed the period it runs in.';
    end if;
  elsif p_goal_type = 'avoid' then
    -- One clean period = one success, so the per-period count is fixed.
    v_per := 1;
    if v_allowance not between 0 and 100 then
      raise exception 'Allowance must be 0-100 per period.';
    end if;
    -- Co-op settles on shared check-ins, which an avoid quest awards
    -- itself; keeping them apart avoids two engines writing the same row.
    if p_mode = 'coop' then
      raise exception 'Avoid quests cannot run in co-op mode.';
    end if;
  elsif p_checkin_period = 'daily' then v_per := 1;
  elsif p_checkin_period = 'weekly' and v_per not between 1 and 7 then raise exception 'Weekly quests need 1-7 check-ins per week.';
  elsif p_checkin_period = 'monthly' and v_per not between 1 and 30 then raise exception 'Monthly quests need 1-30 check-ins per month.';
  end if;

  insert into public.challenges
    (creator_id, title, description, duration_days, aura_gain, aura_penalty, max_strikes, starts_on, checkin_period, checkins_per_period, mode, goal_type, target_value, unit, is_endless, lifecycle, started_at, daily_allowance, active_weekdays, balance_preset, attacks_enabled, tracking)
  values
    (v_user_id, trim(p_title), coalesce(trim(p_description), ''), p_duration_days, p_aura_gain, p_aura_penalty, p_max_strikes,
     coalesce(p_starts_on, (now() at time zone 'utc')::date), p_checkin_period, v_per, p_mode, p_goal_type,
     case when p_goal_type = 'progress' then p_target_value end, case when p_goal_type = 'progress' then v_unit end,
     v_endless, v_lifecycle, case when v_lifecycle = 'active' then now() end,
     case when p_goal_type = 'avoid' then v_allowance else 0 end,
     -- Leere Auswahl waere eine Quest ohne einen einzigen Pflichttag.
     case when p_active_weekdays is null or cardinality(p_active_weekdays) = 0
          then '{1,2,3,4,5,6,7}'::smallint[] else p_active_weekdays end, p_balance_preset, p_attacks_enabled, v_tracking)
  returning id into v_challenge_id;

  insert into public.challenge_participants (challenge_id, user_id, team)
  values (v_challenge_id, v_user_id, case when p_mode = 'versus' then 'red' else null end);

  insert into public.benefits (challenge_id, title, description, cost) values
    (v_challenge_id, 'Title Badge', 'A golden emblem by your name — and +20% aura on every check-in.', 50),
    (v_challenge_id, 'Double Down', 'Your next check-in earns DOUBLE aura.', 100),
    (v_challenge_id, 'Streak Shield', 'One missed day is forgiven - no strike.', 300),
    (v_challenge_id, 'Strike Repair', 'Instantly buy back one used strike. Pricey.', 500),
    (v_challenge_id, 'Aura Lord', 'A crown by your name — and DOUBLE aura on every check-in.', 1000);

  return v_challenge_id;
end;
$function$;

revoke all on function public.create_challenge(text,integer,integer,integer,integer,date,text,text,integer,text,text,numeric,text,boolean,integer,smallint[],text,boolean,text) from public,anon;
grant execute on function public.create_challenge(text,integer,integer,integer,integer,date,text,text,integer,text,text,numeric,text,boolean,integer,smallint[],text,boolean,text) to authenticated;
