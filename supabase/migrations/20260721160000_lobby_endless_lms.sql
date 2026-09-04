-- =================================================================
--  AURA QUEST - lobby lifecycle, endless quests, Last Man Standing
--
--  Shared foundation for three features:
--   * A quest can wait in a LOBBY before it starts (needed so the
--     Last-Man-Standing roster is fixed at kick-off).
--   * A quest can be ENDLESS (no end date). Penalties/strikes still
--     bite each period; it only ends when everyone is gone, the
--     creator abandons it, or - for LMS - one player remains.
--   * LAST MAN STANDING: an elimination mode. Bust your strike budget
--     and you are OUT. Last one standing wins a bonus scaled to how
--     many rivals they outlasted; the rest keep the aura they earned.
-- =================================================================

-- ─────────────────────────────────────────────────────────────────
-- 1. NEW COLUMNS + widened enums
-- ─────────────────────────────────────────────────────────────────
alter table public.challenges
  add column lifecycle text not null default 'active'
    check (lifecycle in ('lobby', 'active', 'finished')),
  add column is_endless boolean not null default false,
  add column started_at timestamptz;

-- Existing quests already started the moment they were created.
update public.challenges set started_at = created_at;

alter table public.challenges drop constraint challenges_mode_check;
alter table public.challenges add constraint challenges_mode_check
  check (mode in ('solo', 'coop', 'versus', 'last_man_standing'));

alter table public.challenge_participants
  drop constraint challenge_participants_status_check;
alter table public.challenge_participants
  add constraint challenge_participants_status_check
  check (status in ('active', 'failed', 'completed', 'eliminated'));

alter table public.settlement_events
  drop constraint settlement_events_kind_check;
alter table public.settlement_events
  add constraint settlement_events_kind_check check (kind in
    ('penalty', 'strike', 'shield_saved', 'half_damage',
     'failed', 'completed', 'bonus', 'duel_won', 'duel_lost',
     'versus_won', 'versus_lost', 'milestone', 'strike_repaired',
     'eliminated', 'lms_finished'));

-- ─────────────────────────────────────────────────────────────────
-- 2. CREATE_CHALLENGE v9: + endless flag, + Last Man Standing mode.
--    LMS is inherently endless and opens in a lobby.
-- ─────────────────────────────────────────────────────────────────
drop function public.create_challenge(
  text, integer, integer, integer, integer, date, text, text, integer, text,
  text, numeric, text);

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
  p_unit text default null,
  p_is_endless boolean default false
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
  v_endless boolean := p_is_endless or p_mode = 'last_man_standing';
  v_lifecycle text := case when p_mode = 'last_man_standing'
                           then 'lobby' else 'active' end;
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
  if p_mode not in ('solo', 'coop', 'versus', 'last_man_standing') then
    raise exception 'Invalid quest mode.';
  end if;
  if p_goal_type not in ('check', 'progress') then
    raise exception 'Invalid goal type.';
  end if;
  -- Versus needs a finish line to score against.
  if v_endless and p_mode = 'versus' then
    raise exception 'Versus quests need a fixed end date.';
  end if;

  if p_goal_type = 'progress' then
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
     goal_type, target_value, unit, is_endless, lifecycle, started_at)
  values
    (v_user_id, trim(p_title), coalesce(trim(p_description), ''),
     p_duration_days, p_aura_gain, p_aura_penalty, p_max_strikes,
     coalesce(p_starts_on, (now() at time zone 'utc')::date),
     p_checkin_period, v_per, p_mode,
     p_goal_type,
     case when p_goal_type = 'progress' then p_target_value end,
     case when p_goal_type = 'progress' then v_unit end,
     v_endless, v_lifecycle,
     case when v_lifecycle = 'active' then now() end)
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
  text, numeric, text, boolean) from public, anon;
grant execute on function public.create_challenge(
  text, integer, integer, integer, integer, date, text, text, integer, text,
  text, numeric, text, boolean) to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- 3. START_QUEST: the creator kicks a lobby quest off. The roster is
--    frozen at this moment and the clock starts today.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.start_quest(p_challenge_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id   uuid := (select auth.uid());
  v_challenge public.challenges%rowtype;
  v_players   integer;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_challenge
  from public.challenges where id = p_challenge_id for update;
  if not found then
    raise exception 'Quest not found.';
  end if;
  if v_challenge.creator_id <> v_user_id then
    raise exception 'Only the creator can start this quest.';
  end if;
  if v_challenge.lifecycle <> 'lobby' then
    raise exception 'This quest is not waiting in a lobby.';
  end if;

  select count(*) into v_players
  from public.challenge_participants
  where challenge_id = p_challenge_id and status = 'active';

  if v_challenge.mode = 'last_man_standing' and v_players < 2 then
    raise exception 'Last Man Standing needs at least 2 players to start.';
  end if;

  update public.challenges
  set lifecycle = 'active',
      starts_on = (now() at time zone 'utc')::date,
      started_at = now()
  where id = p_challenge_id;
end;
$$;

revoke execute on function public.start_quest(uuid) from public, anon;
grant  execute on function public.start_quest(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- 4. LOG_CHECK_IN v7: refuse before the lobby has started and never
--    "end" an endless quest. Instant-win only applies to fixed quests.
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
  v_period_len   integer;
  v_target       integer;
  v_period_start date;
  v_period_end   date;
  v_in_period    integer;
  v_gain         integer;
  v_consumable   uuid;
  v_streak       integer;
  v_cursor       date;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_challenge
  from public.challenges where id = p_challenge_id;
  if not found then
    raise exception 'Quest not found.';
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
                    when 'daily' then 1 when 'weekly' then 7 else 30 end;
  v_target := case when v_challenge.checkin_period = 'daily'
                   then 1 else v_challenge.checkins_per_period end;

  v_period_start := v_challenge.starts_on
    + ((v_today - v_challenge.starts_on) / v_period_len) * v_period_len;
  v_period_end := v_period_start + v_period_len;
  if not v_challenge.is_endless then
    v_period_end := least(v_period_end,
      v_challenge.starts_on + v_challenge.duration_days);
  end if;

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

  begin
    insert into public.check_ins (challenge_id, user_id)
    values (p_challenge_id, v_user_id);
  exception when unique_violation then
    raise exception 'Already checked in today - come back tomorrow!';
  end;

  v_gain := v_challenge.aura_gain;
  select bp.id into v_consumable
  from public.benefit_purchases bp
  join public.benefits b on b.id = bp.benefit_id
  where bp.challenge_id = p_challenge_id
    and bp.user_id = v_user_id
    and bp.consumed_at is null
    and b.title = 'Double Down'
  order by bp.created_at limit 1;
  if found then
    v_gain := v_gain * 2;
    update public.benefit_purchases
      set consumed_at = now() where id = v_consumable;
  end if;

  update public.challenge_participants
  set challenge_aura = challenge_aura + v_gain
  where id = v_participant.id;

  v_streak := 0;
  v_cursor := v_today;
  loop
    exit when not exists (
      select 1 from public.check_ins
      where challenge_id = p_challenge_id
        and user_id = v_user_id
        and checked_on = v_cursor);
    v_streak := v_streak + 1;
    v_cursor := v_cursor - 1;
  end loop;
  if v_streak in (7, 30, 100) then
    insert into public.settlement_events
      (user_id, challenge_id, kind, amount, period_start)
    values (v_user_id, p_challenge_id, 'milestone', v_streak, v_today);
  end if;

  -- Instant win only for fixed-length, non-coop quests.
  if not v_challenge.is_endless
     and v_challenge.mode <> 'coop'
     and v_period_end >= v_challenge.starts_on + v_challenge.duration_days
     and v_in_period + 1 >= v_target then
    perform public.settle_periods();
  end if;

  return v_gain;
end;
$$;

revoke execute on function public.log_check_in(uuid) from public, anon;
grant  execute on function public.log_check_in(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- 5. SETTLE_PERIODS v5: endless-aware, LMS elimination + winner pass.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.settle_periods()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  rec           record;
  chal          record;
  mem           record;
  v_today       date := (now() at time zone 'utc')::date;
  v_len         integer;
  v_target      integer;
  v_active_from date;
  v_end_excl    date;
  v_walk_end    date;
  v_pstart      date;
  v_pend        date;
  v_done        integer;
  v_penalty     integer;
  v_aura        integer;
  v_strikes     integer;
  v_missed      integer;
  v_failed      boolean;
  v_consumable  uuid;
  v_bonus       integer;
  v_last_start  date;
  v_final_done  integer;
  v_win         boolean;
  v_team_missed boolean;
  v_shielded    boolean;
  v_shield_owner uuid;
  v_red_members integer;
  v_blue_members integer;
  v_red_score   numeric;
  v_blue_score  numeric;
  v_winner      text;
  v_pot         integer;
  v_tribute     integer;
  v_winner_cnt  integer;
  v_share       integer;
  v_rest        integer;
  v_active_cnt  integer;
  v_total_cnt   integer;
begin
  -- ===============================================================
  -- A) SOLO + VERSUS + LMS: every participant answers for themselves.
  --    Only started, non-coop quests. Endless quests never complete
  --    here; LMS busts eliminate instead of failing.
  -- ===============================================================
  for rec in
    select cp.id as participant_id, cp.user_id, cp.challenge_id,
           cp.created_at as joined_at, cp.challenge_aura, cp.strikes_used,
           cp.periods_missed, cp.settled_until,
           c.starts_on, c.duration_days, c.checkin_period,
           c.checkins_per_period, c.aura_gain, c.aura_penalty, c.max_strikes,
           c.mode, c.is_endless
    from public.challenge_participants cp
    join public.challenges c on c.id = cp.challenge_id
    where cp.status = 'active' and c.mode <> 'coop'
      and c.lifecycle = 'active'
    order by cp.id
  loop
    v_len := case rec.checkin_period
               when 'daily' then 1 when 'weekly' then 7 else 30 end;
    v_target := case when rec.checkin_period = 'daily'
                     then 1 else rec.checkins_per_period end;
    v_active_from := greatest(
      rec.starts_on, (rec.joined_at at time zone 'utc')::date);
    v_end_excl := case when rec.is_endless
                       then null else rec.starts_on + rec.duration_days end;
    v_walk_end := coalesce(v_end_excl, v_today + 1);

    v_aura := rec.challenge_aura;
    v_strikes := rec.strikes_used;
    v_missed := rec.periods_missed;
    v_failed := false;

    v_pstart := rec.starts_on;
    while v_pstart < v_walk_end loop
      v_pend := least(v_pstart + v_len, v_walk_end);
      exit when v_pend > v_today;  -- period still running

      if v_pstart >= v_active_from
         and (rec.settled_until is null or v_pend > rec.settled_until) then

        select count(*)::int into v_done
        from public.check_ins
        where challenge_id = rec.challenge_id
          and user_id = rec.user_id
          and checked_on >= v_pstart and checked_on < v_pend;

        if v_done < v_target then
          v_missed := v_missed + 1;

          v_penalty := rec.aura_penalty;
          select bp.id into v_consumable
          from public.benefit_purchases bp
          join public.benefits b on b.id = bp.benefit_id
          where bp.challenge_id = rec.challenge_id
            and bp.user_id = rec.user_id
            and bp.consumed_at is null
            and b.title = 'Half Damage'
          order by bp.created_at limit 1;
          if found then
            v_penalty := ceil(v_penalty / 2.0)::int;
            update public.benefit_purchases
              set consumed_at = now() where id = v_consumable;
            insert into public.settlement_events
              (user_id, challenge_id, kind, amount, period_start)
            values (rec.user_id, rec.challenge_id, 'half_damage',
                    null, v_pstart);
          end if;

          v_aura := greatest(0, v_aura - v_penalty);
          insert into public.settlement_events
            (user_id, challenge_id, kind, amount, period_start)
          values (rec.user_id, rec.challenge_id, 'penalty',
                  -v_penalty, v_pstart);

          select bp.id into v_consumable
          from public.benefit_purchases bp
          join public.benefits b on b.id = bp.benefit_id
          where bp.challenge_id = rec.challenge_id
            and bp.user_id = rec.user_id
            and bp.consumed_at is null
            and b.title = 'Streak Shield'
          order by bp.created_at limit 1;
          if found then
            update public.benefit_purchases
              set consumed_at = now() where id = v_consumable;
            insert into public.settlement_events
              (user_id, challenge_id, kind, amount, period_start)
            values (rec.user_id, rec.challenge_id, 'shield_saved',
                    null, v_pstart);
          else
            v_strikes := v_strikes + 1;
            insert into public.settlement_events
              (user_id, challenge_id, kind, amount, period_start)
            values (rec.user_id, rec.challenge_id, 'strike',
                    v_strikes, v_pstart);
          end if;

          if v_strikes > rec.max_strikes then
            v_failed := true;
            if rec.mode = 'last_man_standing' then
              -- Eliminated: OUT of the running, but keeps the aura
              -- earned so far (winner-bonus model, no haircut).
              update public.challenge_participants
              set status = 'eliminated', challenge_aura = v_aura,
                  strikes_used = v_strikes, periods_missed = v_missed,
                  settled_until = v_pend, finished_at = now()
              where id = rec.participant_id;
              insert into public.settlement_events
                (user_id, challenge_id, kind, amount, period_start)
              values (rec.user_id, rec.challenge_id, 'eliminated',
                      v_missed, v_pstart);
            else
              v_aura := v_aura / 4;
              update public.challenge_participants
              set status = 'failed', challenge_aura = v_aura,
                  strikes_used = v_strikes, periods_missed = v_missed,
                  settled_until = v_pend, finished_at = now()
              where id = rec.participant_id;
              insert into public.settlement_events
                (user_id, challenge_id, kind, amount, period_start)
              values (rec.user_id, rec.challenge_id, 'failed',
                      v_aura, v_pstart);
            end if;
            exit;
          end if;
        end if;
      end if;

      v_pstart := v_pend;
    end loop;

    if not v_failed then
      if rec.is_endless then
        -- Endless: never completes here, just bank the progress.
        update public.challenge_participants
        set challenge_aura = v_aura, strikes_used = v_strikes,
            periods_missed = v_missed,
            settled_until = greatest(coalesce(rec.settled_until,
                                              v_active_from), v_pstart)
        where id = rec.participant_id;
      else
        v_last_start := rec.starts_on
          + ((rec.duration_days - 1) / v_len) * v_len;
        v_win := v_today >= v_end_excl;
        if not v_win and v_today >= v_last_start then
          select count(*)::int into v_final_done
          from public.check_ins
          where challenge_id = rec.challenge_id
            and user_id = rec.user_id
            and checked_on >= v_last_start and checked_on < v_end_excl;
          v_win := v_final_done >= v_target;
        end if;

        if v_win then
          v_bonus := greatest(0, rec.max_strikes - v_strikes)
                       * rec.aura_penalty;
          v_aura := v_aura + v_bonus;
          update public.challenge_participants
          set status = 'completed', challenge_aura = v_aura,
              strikes_used = v_strikes, periods_missed = v_missed,
              settled_until = v_end_excl, finished_at = now()
          where id = rec.participant_id;
          if v_bonus > 0 then
            insert into public.settlement_events
              (user_id, challenge_id, kind, amount, period_start)
            values (rec.user_id, rec.challenge_id, 'bonus', v_bonus, null);
          end if;
          insert into public.settlement_events
            (user_id, challenge_id, kind, amount, period_start)
          values (rec.user_id, rec.challenge_id, 'completed', v_aura, null);
        else
          update public.challenge_participants
          set challenge_aura = v_aura, strikes_used = v_strikes,
              periods_missed = v_missed,
              settled_until = greatest(coalesce(rec.settled_until,
                                                v_active_from), v_pstart)
          where id = rec.participant_id;
        end if;
      end if;
    end if;
  end loop;

  -- ===============================================================
  -- B) COOP: the party lives and dies together. Endless-aware.
  -- ===============================================================
  for chal in
    select c.*
    from public.challenges c
    where c.mode = 'coop' and c.lifecycle = 'active'
      and exists (select 1 from public.challenge_participants cp
                  where cp.challenge_id = c.id and cp.status = 'active')
    order by c.id
  loop
    v_len := case chal.checkin_period
               when 'daily' then 1 when 'weekly' then 7 else 30 end;
    v_target := case when chal.checkin_period = 'daily'
                     then 1 else chal.checkins_per_period end;
    v_end_excl := case when chal.is_endless
                       then null else chal.starts_on + chal.duration_days end;
    v_walk_end := coalesce(v_end_excl, v_today + 1);
    v_failed := false;

    v_pstart := chal.starts_on;
    while v_pstart < v_walk_end loop
      v_pend := least(v_pstart + v_len, v_walk_end);
      exit when v_pend > v_today;  -- period still running

      select bool_or(sub.cnt < v_target) into v_team_missed
      from (
        select (select count(*) from public.check_ins ci
                where ci.challenge_id = chal.id
                  and ci.user_id = cp.user_id
                  and ci.checked_on >= v_pstart
                  and ci.checked_on < v_pend) as cnt
        from public.challenge_participants cp
        where cp.challenge_id = chal.id and cp.status = 'active'
          and greatest(chal.starts_on,
                (cp.created_at at time zone 'utc')::date) <= v_pstart
          and (cp.settled_until is null or cp.settled_until < v_pend)
      ) sub;

      if v_team_missed then
        v_shielded := false;
        select bp.id, bp.user_id into v_consumable, v_shield_owner
        from public.benefit_purchases bp
        join public.benefits b on b.id = bp.benefit_id
        where bp.challenge_id = chal.id
          and bp.consumed_at is null
          and b.title = 'Streak Shield'
          and bp.user_id in (select user_id
                             from public.challenge_participants
                             where challenge_id = chal.id
                               and status = 'active')
        order by bp.created_at limit 1;
        if found then
          v_shielded := true;
          update public.benefit_purchases
            set consumed_at = now() where id = v_consumable;
          insert into public.settlement_events
            (user_id, challenge_id, kind, amount, period_start)
          values (v_shield_owner, chal.id, 'shield_saved', null, v_pstart);
        end if;

        for mem in
          select cp.id as participant_id, cp.user_id, cp.challenge_aura,
                 cp.strikes_used
          from public.challenge_participants cp
          where cp.challenge_id = chal.id and cp.status = 'active'
            and greatest(chal.starts_on,
                  (cp.created_at at time zone 'utc')::date) <= v_pstart
            and (cp.settled_until is null or cp.settled_until < v_pend)
          order by cp.id
          for update
        loop
          v_penalty := chal.aura_penalty;
          select bp.id into v_consumable
          from public.benefit_purchases bp
          join public.benefits b on b.id = bp.benefit_id
          where bp.challenge_id = chal.id
            and bp.user_id = mem.user_id
            and bp.consumed_at is null
            and b.title = 'Half Damage'
          order by bp.created_at limit 1;
          if found then
            v_penalty := ceil(v_penalty / 2.0)::int;
            update public.benefit_purchases
              set consumed_at = now() where id = v_consumable;
            insert into public.settlement_events
              (user_id, challenge_id, kind, amount, period_start)
            values (mem.user_id, chal.id, 'half_damage', null, v_pstart);
          end if;

          insert into public.settlement_events
            (user_id, challenge_id, kind, amount, period_start)
          values (mem.user_id, chal.id, 'penalty', -v_penalty, v_pstart);

          if v_shielded then
            update public.challenge_participants
            set challenge_aura = greatest(0, challenge_aura - v_penalty),
                periods_missed = periods_missed + 1,
                settled_until = v_pend
            where id = mem.participant_id;
          else
            insert into public.settlement_events
              (user_id, challenge_id, kind, amount, period_start)
            values (mem.user_id, chal.id, 'strike',
                    mem.strikes_used + 1, v_pstart);
            update public.challenge_participants
            set challenge_aura = greatest(0, challenge_aura - v_penalty),
                periods_missed = periods_missed + 1,
                strikes_used = strikes_used + 1,
                settled_until = v_pend
            where id = mem.participant_id;
          end if;
        end loop;
      else
        update public.challenge_participants cp
        set settled_until = v_pend
        where cp.challenge_id = chal.id and cp.status = 'active'
          and greatest(chal.starts_on,
                (cp.created_at at time zone 'utc')::date) <= v_pstart
          and (cp.settled_until is null or cp.settled_until < v_pend);
      end if;

      if exists (select 1 from public.challenge_participants cp
                 where cp.challenge_id = chal.id and cp.status = 'active'
                   and cp.strikes_used > chal.max_strikes) then
        v_failed := true;
        for mem in
          select cp.id as participant_id, cp.user_id, cp.challenge_aura
          from public.challenge_participants cp
          where cp.challenge_id = chal.id and cp.status = 'active'
          order by cp.id
          for update
        loop
          update public.challenge_participants
          set status = 'failed', challenge_aura = mem.challenge_aura / 4,
              settled_until = v_pend, finished_at = now()
          where id = mem.participant_id;
          insert into public.settlement_events
            (user_id, challenge_id, kind, amount, period_start)
          values (mem.user_id, chal.id, 'failed',
                  mem.challenge_aura / 4, v_pstart);
        end loop;
        exit;
      end if;

      v_pstart := v_pend;
    end loop;

    if not v_failed and not chal.is_endless and v_today >= v_end_excl then
      for mem in
        select cp.id as participant_id, cp.user_id, cp.challenge_aura,
               cp.strikes_used
        from public.challenge_participants cp
        where cp.challenge_id = chal.id and cp.status = 'active'
        order by cp.id
        for update
      loop
        v_bonus := greatest(0, chal.max_strikes - mem.strikes_used)
                     * chal.aura_penalty;
        update public.challenge_participants
        set status = 'completed',
            challenge_aura = mem.challenge_aura + v_bonus,
            settled_until = v_end_excl, finished_at = now()
        where id = mem.participant_id;
        if v_bonus > 0 then
          insert into public.settlement_events
            (user_id, challenge_id, kind, amount, period_start)
          values (mem.user_id, chal.id, 'bonus', v_bonus, null);
        end if;
        insert into public.settlement_events
          (user_id, challenge_id, kind, amount, period_start)
        values (mem.user_id, chal.id, 'completed',
                mem.challenge_aura + v_bonus, null);
      end loop;
    end if;
  end loop;

  -- ===============================================================
  -- C) VERSUS PAYOUT: once per finished quest (unchanged).
  -- ===============================================================
  for chal in
    select c.*
    from public.challenges c
    where c.mode = 'versus'
      and c.versus_settled_at is null
      and v_today >= c.starts_on + c.duration_days
    order by c.id
  loop
    select count(*) filter (where cp.team = 'red'),
           count(*) filter (where cp.team = 'blue')
    into v_red_members, v_blue_members
    from public.challenge_participants cp
    where cp.challenge_id = chal.id;

    select
      coalesce(count(*) filter (where cp.team = 'red'), 0)::numeric
        / nullif(v_red_members, 0),
      coalesce(count(*) filter (where cp.team = 'blue'), 0)::numeric
        / nullif(v_blue_members, 0)
    into v_red_score, v_blue_score
    from public.check_ins ci
    join public.challenge_participants cp
      on cp.challenge_id = ci.challenge_id and cp.user_id = ci.user_id
    where ci.challenge_id = chal.id;

    if v_red_members = 0 or v_blue_members = 0
       or coalesce(v_red_score, 0) = coalesce(v_blue_score, 0) then
      update public.challenges
        set versus_settled_at = now() where id = chal.id;
      continue;
    end if;

    v_winner := case when coalesce(v_red_score, 0)
                          > coalesce(v_blue_score, 0)
                     then 'red' else 'blue' end;

    select count(*) into v_winner_cnt
    from public.challenge_participants cp
    where cp.challenge_id = chal.id and cp.status = 'completed'
      and cp.team = v_winner;

    v_pot := 0;
    if v_winner_cnt > 0 then
      for mem in
        select cp.id as participant_id, cp.user_id, cp.challenge_aura
        from public.challenge_participants cp
        where cp.challenge_id = chal.id and cp.status = 'completed'
          and cp.team <> v_winner
        order by cp.id
        for update
      loop
        v_tribute := mem.challenge_aura / 4;
        if v_tribute > 0 then
          v_pot := v_pot + v_tribute;
          update public.challenge_participants
          set challenge_aura = challenge_aura - v_tribute
          where id = mem.participant_id;
          insert into public.settlement_events
            (user_id, challenge_id, kind, amount, period_start)
          values (mem.user_id, chal.id, 'versus_lost', -v_tribute, null);
        end if;
      end loop;

      if v_pot > 0 then
        v_share := v_pot / v_winner_cnt;
        v_rest := v_pot - v_share * v_winner_cnt;
        for mem in
          select cp.id as participant_id, cp.user_id
          from public.challenge_participants cp
          where cp.challenge_id = chal.id and cp.status = 'completed'
            and cp.team = v_winner
          order by cp.created_at, cp.id
          for update
        loop
          v_bonus := v_share + v_rest;
          v_rest := 0;
          update public.challenge_participants
          set challenge_aura = challenge_aura + v_bonus
          where id = mem.participant_id;
          insert into public.settlement_events
            (user_id, challenge_id, kind, amount, period_start)
          values (mem.user_id, chal.id, 'versus_won', v_bonus, null);
        end loop;
      end if;
    end if;

    update public.challenges
      set versus_settled_at = now() where id = chal.id;
  end loop;

  -- ===============================================================
  -- D) LAST MAN STANDING: crown the survivor once one (or none)
  --    remains. Bonus scales with how many rivals were outlasted.
  -- ===============================================================
  for chal in
    select c.*
    from public.challenges c
    where c.mode = 'last_man_standing' and c.lifecycle = 'active'
    order by c.id
  loop
    select count(*) filter (where status = 'active'), count(*)
    into v_active_cnt, v_total_cnt
    from public.challenge_participants
    where challenge_id = chal.id;

    -- A real contest (>=2 joined) that has run down to one survivor.
    if v_total_cnt >= 2 and v_active_cnt <= 1 then
      v_bonus := (v_total_cnt - 1) * chal.aura_gain;

      for mem in
        select cp.id as participant_id, cp.user_id, cp.challenge_aura
        from public.challenge_participants cp
        where cp.challenge_id = chal.id
          -- The survivor, or (if the last two fell together) whoever
          -- was eliminated last.
          and (cp.status = 'active'
               or (v_active_cnt = 0 and cp.status = 'eliminated'
                   and cp.finished_at = (
                     select max(finished_at)
                     from public.challenge_participants
                     where challenge_id = chal.id)))
        for update
      loop
        update public.challenge_participants
        set status = 'completed',
            challenge_aura = mem.challenge_aura + v_bonus,
            finished_at = now()
        where id = mem.participant_id;
        insert into public.settlement_events
          (user_id, challenge_id, kind, amount, period_start)
        values (mem.user_id, chal.id, 'bonus', v_bonus, null);
        insert into public.settlement_events
          (user_id, challenge_id, kind, amount, period_start)
        values (mem.user_id, chal.id, 'completed',
                mem.challenge_aura + v_bonus, null);
      end loop;

      -- Everyone who was knocked out gets the closing notice.
      insert into public.settlement_events
        (user_id, challenge_id, kind, amount, period_start)
      select user_id, chal.id, 'lms_finished', null, null
      from public.challenge_participants
      where challenge_id = chal.id and status = 'eliminated';

      update public.challenges
        set lifecycle = 'finished' where id = chal.id;
    end if;
  end loop;
end;
$$;

revoke execute on function public.settle_periods() from public, anon, authenticated;
