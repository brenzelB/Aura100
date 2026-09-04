-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST - flexible check-in frequency + leaving quests
--
--  1. Quests can now require N check-ins per week/month instead of
--     daily. Periods are 7/30-day blocks anchored to starts_on
--     (not calendar weeks/months - simpler and fair for any start).
--     Strikes count COMPLETED periods that missed their target.
--  2. Users can leave a quest: delete their own participant row.
-- ═════════════════════════════════════════════════════════════════

alter table public.challenges
  add column checkin_period text not null default 'daily'
    check (checkin_period in ('daily', 'weekly', 'monthly')),
  add column checkins_per_period integer not null default 1
    check (checkins_per_period between 1 and 30);

-- Leaving a quest = deleting your own participation. Check-ins and
-- purchases stay as history (they don't cascade from participants).
grant delete on public.challenge_participants to authenticated;
create policy "participants: user can leave"
  on public.challenge_participants for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- ─────────────────────────────────────────────────────────────────
-- CREATE_CHALLENGE v4: + checkin frequency
-- ─────────────────────────────────────────────────────────────────
drop function public.create_challenge(text, integer, integer, integer, integer, date, text);

create or replace function public.create_challenge(
  p_title text,
  p_duration_days integer,
  p_aura_gain integer,
  p_aura_penalty integer,
  p_max_strikes integer default 1,
  p_starts_on date default null,
  p_description text default '',
  p_checkin_period text default 'daily',
  p_checkins_per_period integer default 1
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
  -- Daily means exactly one per day; cap weekly at 7, monthly at 30.
  if p_checkin_period = 'daily' then
    v_per := 1;
  elsif p_checkin_period = 'weekly' and v_per not between 1 and 7 then
    raise exception 'Weekly quests need 1-7 check-ins per week.';
  elsif p_checkin_period = 'monthly' and v_per not between 1 and 30 then
    raise exception 'Monthly quests need 1-30 check-ins per month.';
  end if;

  insert into public.challenges
    (creator_id, title, description, duration_days, aura_gain, aura_penalty,
     max_strikes, starts_on, checkin_period, checkins_per_period)
  values
    (v_user_id, trim(p_title), coalesce(trim(p_description), ''),
     p_duration_days, p_aura_gain, p_aura_penalty, p_max_strikes,
     coalesce(p_starts_on, (now() at time zone 'utc')::date),
     p_checkin_period, v_per)
  returning id into v_challenge_id;

  insert into public.challenge_participants (challenge_id, user_id)
  values (v_challenge_id, v_user_id);

  insert into public.benefits (challenge_id, title, description, cost) values
    (v_challenge_id, 'Title Badge',
     'A golden badge on this quest - pure flex.', 50),
    (v_challenge_id, 'Half Damage',
     'Your next missed day costs only half the penalty.', 150),
    (v_challenge_id, 'Streak Shield',
     'One missed day is forgiven - no strike.', 300);

  return v_challenge_id;
end;
$$;

revoke execute on function
  public.create_challenge(text, integer, integer, integer, integer, date, text, text, integer)
  from public, anon;
grant execute on function
  public.create_challenge(text, integer, integer, integer, integer, date, text, text, integer)
  to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- LOG_CHECK_IN v3: unified period logic.
-- Daily is just the special case period_len=1, target=1, so ONE code
-- path handles all three frequencies (identical daily behavior).
-- ─────────────────────────────────────────────────────────────────
create or replace function public.log_check_in(p_challenge_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id      uuid := (select auth.uid());
  v_challenge    public.challenges%rowtype;
  v_participant  public.challenge_participants%rowtype;
  v_today        date := (now() at time zone 'utc')::date;
  v_active_from  date;
  v_period_len   integer;
  v_target       integer;
  v_period_start date;
  v_period_end   date;  -- exclusive
  v_in_period    integer;
  v_missed       integer := 0;
  v_pstart       date;
  v_done         integer;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_challenge
  from public.challenges where id = p_challenge_id;
  if not found then
    raise exception 'Quest not found.';
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

  v_period_len := case v_challenge.checkin_period
                    when 'daily' then 1
                    when 'weekly' then 7
                    else 30
                  end;
  v_target := case when v_challenge.checkin_period = 'daily'
                   then 1 else v_challenge.checkins_per_period end;
  v_active_from := greatest(
    v_challenge.starts_on,
    (v_participant.created_at at time zone 'utc')::date
  );

  -- Current period (anchored to starts_on), clipped to the quest end.
  v_period_start := v_challenge.starts_on
    + ((v_today - v_challenge.starts_on) / v_period_len) * v_period_len;
  v_period_end := least(
    v_period_start + v_period_len,
    v_challenge.starts_on + v_challenge.duration_days
  );

  -- Period goal already reached?
  select count(*)::int into v_in_period
  from public.check_ins
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and checked_on >= v_period_start
    and checked_on < v_period_end;
  if v_in_period >= v_target then
    if v_challenge.checkin_period = 'daily' then
      raise exception 'Already checked in today - come back tomorrow!';
    else
      raise exception 'Goal for this period already reached - see you next period!';
    end if;
  end if;

  -- STRIKES: every fully COMPLETED period since joining that missed
  -- its target counts once. (Periods containing the join date are
  -- skipped - fair for mid-quest joiners.)
  v_pstart := v_challenge.starts_on;
  while v_pstart + v_period_len <= v_today loop
    if v_pstart >= v_active_from then
      select count(*)::int into v_done
      from public.check_ins
      where challenge_id = p_challenge_id
        and user_id = v_user_id
        and checked_on >= v_pstart
        and checked_on < v_pstart + v_period_len;
      if v_done < v_target then
        v_missed := v_missed + 1;
      end if;
    end if;
    v_pstart := v_pstart + v_period_len;
  end loop;

  if v_missed > v_challenge.max_strikes then
    update public.challenge_participants
    set status = 'failed'
    where id = v_participant.id;
    raise exception
      'Quest failed - % period(s) under target, only % strike(s) allowed.',
      v_missed, v_challenge.max_strikes;
  end if;

  begin
    insert into public.check_ins (challenge_id, user_id)
    values (p_challenge_id, v_user_id);
  exception when unique_violation then
    raise exception 'Already checked in today - come back tomorrow!';
  end;

  update public.challenge_participants
  set challenge_aura = challenge_aura + v_challenge.aura_gain
  where id = v_participant.id;

  return v_challenge.aura_gain;
end;
$$;

revoke execute on function public.log_check_in(uuid) from public, anon;
grant  execute on function public.log_check_in(uuid) to authenticated;
