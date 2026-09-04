-- =================================================================
--  AURA QUEST - progress challenges
--
--  A quest now has a GOAL TYPE:
--   * check    - tick it off once per period (everything so far)
--   * progress - collect towards a freely defined target with a free
--                unit ("100 push-ups", "2.5 litres", "7500 steps").
--                Partial entries add up; the period is done the
--                moment the total reaches the target.
--
--  COMPATIBILITY: reaching the target logs a REAL check-in through
--  log_check_in. Everything downstream - aura payout, Double Down,
--  streak milestones, strikes, the settlement engine, co-op/versus,
--  the timeline - therefore keeps working untouched.
-- =================================================================

alter table public.challenges
  add column goal_type text not null default 'check'
    check (goal_type in ('check', 'progress')),
  add column target_value numeric(12, 2),
  add column unit text;

-- Progress quests must carry a positive target and a unit.
alter table public.challenges
  add constraint challenges_progress_fields check (
    goal_type = 'check'
    or (target_value is not null and target_value > 0
        and unit is not null and length(trim(unit)) between 1 and 24)
  );

-- ─────────────────────────────────────────────────────────────────
-- PROGRESS ENTRIES - the audit trail behind every period's total.
-- ─────────────────────────────────────────────────────────────────
create table public.progress_entries (
  id            uuid primary key default gen_random_uuid(),
  challenge_id  uuid not null references public.challenges (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  amount        numeric(12, 2) not null check (amount > 0),
  -- Which period this counts towards (anchored to starts_on).
  period_start  date not null,
  created_at    timestamptz not null default now()
);
create index progress_entries_lookup
  on public.progress_entries (challenge_id, user_id, period_start);

alter table public.progress_entries enable row level security;
grant select on public.progress_entries to authenticated;

-- Same visibility rule as check-ins: quest-mates see each other.
create policy "progress: quest members read each other"
  on public.progress_entries for select
  to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.challenge_participants me
      where me.challenge_id = progress_entries.challenge_id
        and me.user_id = (select auth.uid())
    )
  );

-- ─────────────────────────────────────────────────────────────────
-- CREATE_CHALLENGE v7: + goal type, target value and unit.
-- ─────────────────────────────────────────────────────────────────
drop function public.create_challenge(
  text, integer, integer, integer, integer, date, text, text, integer, text);

create or replace function public.create_challenge(
  p_title text,
  p_duration_days integer,
  p_aura_gain integer,
  p_aura_penalty integer,
  p_max_strikes integer default 1,
  p_starts_on date default null,
  p_description text default '',
  p_checkin_period text default 'daily',
  p_checkins_per_period integer default 1,
  p_mode text default 'solo',
  p_goal_type text default 'check',
  p_target_value numeric default null,
  p_unit text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_challenge_id uuid;
  v_per integer := p_checkins_per_period;
  v_unit text := nullif(trim(coalesce(p_unit, '')), '');
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if p_title is null or length(trim(p_title)) between 1 and 80 is not true then
    raise exception 'Title must be 1-80 characters.';
  end if;
  if char_length(coalesce(p_description, '')) > 500 then
    raise exception 'Description must be at most 500 characters.';
  end if;
  if p_duration_days not between 1 and 365 then
    raise exception 'Duration must be 1-365 days.';
  end if;
  if p_aura_gain not between 0 and 10000 or p_aura_penalty not between 0 and 10000 then
    raise exception 'Aura values must be 0-10000.';
  end if;
  if p_max_strikes not between 0 and 10 then
    raise exception 'Strikes must be 0-10.';
  end if;
  if p_checkin_period not in ('daily', 'weekly', 'monthly') then
    raise exception 'Invalid check-in period.';
  end if;
  if p_mode not in ('solo', 'coop', 'versus') then
    raise exception 'Invalid quest mode.';
  end if;
  if p_goal_type not in ('check', 'progress') then
    raise exception 'Invalid goal type.';
  end if;

  if p_goal_type = 'progress' then
    -- One target per period; partial entries add up towards it.
    v_per := 1;
    if p_target_value is null or p_target_value <= 0 then
      raise exception 'Set a target greater than 0.';
    end if;
    if p_target_value > 1000000 then
      raise exception 'Target must be at most 1000000.';
    end if;
    if v_unit is null or length(v_unit) > 24 then
      raise exception 'Give the target a unit (max 24 characters).';
    end if;
  elsif p_checkin_period = 'daily' then
    v_per := 1;
  elsif p_checkin_period = 'weekly' and v_per not between 1 and 7 then
    raise exception 'Weekly quests need 1-7 check-ins per week.';
  elsif p_checkin_period = 'monthly' and v_per not between 1 and 30 then
    raise exception 'Monthly quests need 1-30 check-ins per month.';
  end if;

  insert into public.challenges
    (creator_id, title, description, duration_days, aura_gain, aura_penalty,
     max_strikes, starts_on, checkin_period, checkins_per_period, mode,
     goal_type, target_value, unit)
  values
    (v_user_id, trim(p_title), coalesce(trim(p_description), ''),
     p_duration_days, p_aura_gain, p_aura_penalty, p_max_strikes,
     coalesce(p_starts_on, (now() at time zone 'utc')::date),
     p_checkin_period, v_per, p_mode,
     p_goal_type,
     case when p_goal_type = 'progress' then p_target_value end,
     case when p_goal_type = 'progress' then v_unit end)
  returning id into v_challenge_id;

  insert into public.challenge_participants (challenge_id, user_id, team)
  values (v_challenge_id, v_user_id,
          case when p_mode = 'versus' then 'red' else null end);

  insert into public.benefits (challenge_id, title, description, cost) values
    (v_challenge_id, 'Title Badge',
     'A golden badge on this quest - pure flex.', 50),
    (v_challenge_id, 'Roast Shield',
     'Skip the next you-failed roast. We will spare you. Once.', 80),
    (v_challenge_id, 'Double Down',
     'Your next check-in earns DOUBLE aura.', 100),
    (v_challenge_id, 'Half Damage',
     'Your next missed day costs only half the penalty.', 150),
    (v_challenge_id, 'Streak Shield',
     'One missed day is forgiven - no strike.', 300),
    (v_challenge_id, 'The Relentless',
     'A title worn next to your name in the party.', 400),
    (v_challenge_id, 'Strike Repair',
     'Instantly buy back one used strike. Pricey.', 500),
    (v_challenge_id, 'Aura Lord',
     'The ultimate flex title for aura hoarders.', 1000);

  return v_challenge_id;
end;
$$;

revoke execute on function public.create_challenge(
  text, integer, integer, integer, integer, date, text, text, integer, text,
  text, numeric, text) from public, anon;
grant execute on function public.create_challenge(
  text, integer, integer, integer, integer, date, text, text, integer, text,
  text, numeric, text) to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- ADD_PROGRESS - log a partial amount towards this period's target.
-- Reaching the target hands over to log_check_in, so the payout and
-- every downstream rule stay in exactly one place.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.add_progress(
  p_challenge_id uuid,
  p_amount numeric
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id      uuid := (select auth.uid());
  v_challenge    public.challenges%rowtype;
  v_participant  public.challenge_participants%rowtype;
  v_today        date := (now() at time zone 'utc')::date;
  v_period_len   integer;
  v_period_start date;
  v_period_end   date;
  v_total        numeric;
  v_done         integer;
  v_gained       integer := null;
  v_completed    boolean := false;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Enter an amount greater than 0.';
  end if;
  if p_amount > 1000000 then
    raise exception 'That is a bit much - keep it under 1000000.';
  end if;

  select * into v_challenge
  from public.challenges where id = p_challenge_id;
  if not found then
    raise exception 'Quest not found.';
  end if;
  if v_challenge.goal_type <> 'progress' then
    raise exception 'This quest is checked off, not tracked by progress.';
  end if;

  if v_today < v_challenge.starts_on then
    raise exception 'This quest has not started yet.';
  end if;
  if v_today >= v_challenge.starts_on + v_challenge.duration_days then
    raise exception 'This quest has already ended.';
  end if;

  select * into v_participant
  from public.challenge_participants
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and status = 'active'
  for update;
  if not found then
    raise exception 'You are not an active participant of this quest.';
  end if;

  -- Period bounds, anchored to starts_on (same rule as everywhere).
  v_period_len := case v_challenge.checkin_period
                    when 'daily' then 1 when 'weekly' then 7 else 30 end;
  v_period_start := v_challenge.starts_on
    + ((v_today - v_challenge.starts_on) / v_period_len) * v_period_len;
  v_period_end := least(
    v_period_start + v_period_len,
    v_challenge.starts_on + v_challenge.duration_days
  );

  -- Already finished this period? Then the books are closed.
  select count(*)::int into v_done
  from public.check_ins
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and checked_on >= v_period_start
    and checked_on < v_period_end;
  if v_done > 0 then
    raise exception 'Target already reached for this period - nice work!';
  end if;

  insert into public.progress_entries
    (challenge_id, user_id, amount, period_start)
  values (p_challenge_id, v_user_id, p_amount, v_period_start);

  select coalesce(sum(amount), 0) into v_total
  from public.progress_entries
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and period_start = v_period_start;

  -- Target reached -> log the real check-in (aura, Double Down,
  -- milestones, instant win all handled there).
  if v_total >= v_challenge.target_value then
    v_completed := true;
    v_gained := public.log_check_in(p_challenge_id);
  end if;

  return jsonb_build_object(
    'total', v_total,
    'target', v_challenge.target_value,
    'completed', v_completed,
    'gained', v_gained
  );
end;
$$;

revoke execute on function public.add_progress(uuid, numeric) from public, anon;
grant  execute on function public.add_progress(uuid, numeric) to authenticated;
