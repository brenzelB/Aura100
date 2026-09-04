-- =================================================================
--  AURA QUEST - team quests
--
--  A quest now has a MODE, fixed at creation:
--   * solo   - everyone plays for themselves (unchanged default)
--   * coop   - ONE FOR ALL: if any member misses a period, EVERYONE
--              pays the penalty and everyone takes the strike. One
--              Streak Shield (oldest unused, any member) absorbs the
--              team strike for the WHOLE party. Half Damage stays
--              personal. If any member busts the strike budget the
--              quest fails for the entire team (25% salvage each).
--   * versus - RED vs BLUE: members are auto-assigned to the smaller
--              team on join (creator starts red). Individually the
--              solo rules apply; at quest end the team with the most
--              check-ins PER MEMBER wins, and every completed loser
--              pays 25% of their final aura into a pot that is split
--              among the completed winners (zero-sum, like duels).
-- =================================================================

alter table public.challenges
  add column mode text not null default 'solo'
    check (mode in ('solo', 'coop', 'versus')),
  -- Set once the end-of-quest versus payout has run (idempotency).
  add column versus_settled_at timestamptz;

alter table public.challenge_participants
  add column team text check (team in ('red', 'blue'));

-- The event feed learns the versus payout kinds.
alter table public.settlement_events
  drop constraint settlement_events_kind_check;
alter table public.settlement_events
  add constraint settlement_events_kind_check check (kind in
    ('penalty', 'strike', 'shield_saved', 'half_damage',
     'failed', 'completed', 'bonus', 'duel_won', 'duel_lost',
     'versus_won', 'versus_lost'));

-- -----------------------------------------------------------------
-- CREATE_CHALLENGE v5: + mode. Creator lands on team red in versus.
-- -----------------------------------------------------------------
drop function public.create_challenge(
  text, integer, integer, integer, integer, date, text, text, integer);

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
  p_mode text default 'solo'
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
  if p_mode not in ('solo', 'coop', 'versus') then
    raise exception 'Invalid quest mode.';
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
     max_strikes, starts_on, checkin_period, checkins_per_period, mode)
  values
    (v_user_id, trim(p_title), coalesce(trim(p_description), ''),
     p_duration_days, p_aura_gain, p_aura_penalty, p_max_strikes,
     coalesce(p_starts_on, (now() at time zone 'utc')::date),
     p_checkin_period, v_per, p_mode)
  returning id into v_challenge_id;

  insert into public.challenge_participants (challenge_id, user_id, team)
  values (v_challenge_id, v_user_id,
          case when p_mode = 'versus' then 'red' else null end);

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

revoke execute on function public.create_challenge(
  text, integer, integer, integer, integer, date, text, text, integer, text)
  from public, anon;
grant execute on function public.create_challenge(
  text, integer, integer, integer, integer, date, text, text, integer, text)
  to authenticated;

-- -----------------------------------------------------------------
-- RESPOND_TO_INVITE v2: joining a versus quest auto-assigns the
-- smaller team (tie goes to red, so teams alternate).
-- -----------------------------------------------------------------
create or replace function public.respond_to_invite(
  p_invite_id uuid,
  p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_invite public.invites%rowtype;
  v_challenge public.challenges%rowtype;
  v_team text;
  v_red integer;
  v_blue integer;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_invite
  from public.invites
  where id = p_invite_id and invitee_id = v_user_id and status = 'pending'
  for update;
  if not found then
    raise exception 'Invite not found or already handled.';
  end if;

  if not p_accept then
    update public.invites set status = 'declined' where id = v_invite.id;
    return;
  end if;

  select * into v_challenge
  from public.challenges where id = v_invite.challenge_id for update;
  if (now() at time zone 'utc')::date
       >= v_challenge.starts_on + v_challenge.duration_days then
    raise exception 'This quest has already ended.';
  end if;

  if v_challenge.mode = 'versus' then
    select count(*) filter (where team = 'red'),
           count(*) filter (where team = 'blue')
    into v_red, v_blue
    from public.challenge_participants
    where challenge_id = v_challenge.id and status = 'active';
    v_team := case when v_blue < v_red then 'blue' else 'red' end;
  end if;

  insert into public.challenge_participants (challenge_id, user_id, team)
  values (v_invite.challenge_id, v_user_id, v_team)
  on conflict (challenge_id, user_id) do nothing;

  update public.invites set status = 'accepted' where id = v_invite.id;
end;
$$;

-- -----------------------------------------------------------------
-- SETTLE_PERIODS v3: three passes.
--  A) solo + versus participants: unchanged per-participant walk.
--  B) coop challenges: per-CHALLENGE walk - a miss by anyone hits
--     everyone; one team shield absorbs the shared strike; any bust
--     fails the whole team; survival to the end completes everyone.
--  C) versus payout: once per finished versus quest, losers' tribute
--     (25% of final aura) is pooled and split among the winners.
-- -----------------------------------------------------------------
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
begin
  -- ===============================================================
  -- A) SOLO + VERSUS: every participant answers for themselves.
  -- ===============================================================
  for rec in
    select cp.id as participant_id, cp.user_id, cp.challenge_id,
           cp.created_at as joined_at, cp.challenge_aura, cp.strikes_used,
           cp.periods_missed, cp.settled_until,
           c.starts_on, c.duration_days, c.checkin_period,
           c.checkins_per_period, c.aura_gain, c.aura_penalty, c.max_strikes
    from public.challenge_participants cp
    join public.challenges c on c.id = cp.challenge_id
    where cp.status = 'active' and c.mode <> 'coop'
    order by cp.id
  loop
    v_len := case rec.checkin_period
               when 'daily' then 1 when 'weekly' then 7 else 30 end;
    v_target := case when rec.checkin_period = 'daily'
                     then 1 else rec.checkins_per_period end;
    v_active_from := greatest(
      rec.starts_on, (rec.joined_at at time zone 'utc')::date);
    v_end_excl := rec.starts_on + rec.duration_days;

    v_aura := rec.challenge_aura;
    v_strikes := rec.strikes_used;
    v_missed := rec.periods_missed;
    v_failed := false;

    v_pstart := rec.starts_on;
    while v_pstart < v_end_excl loop
      v_pend := least(v_pstart + v_len, v_end_excl);
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
            exit;
          end if;
        end if;
      end if;

      v_pstart := v_pend;
    end loop;

    if not v_failed then
      if v_today >= v_end_excl then
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
  end loop;

  -- ===============================================================
  -- B) COOP: the party lives and dies together.
  -- ===============================================================
  for chal in
    select c.*
    from public.challenges c
    where c.mode = 'coop'
      and exists (select 1 from public.challenge_participants cp
                  where cp.challenge_id = c.id and cp.status = 'active')
    order by c.id
  loop
    v_len := case chal.checkin_period
               when 'daily' then 1 when 'weekly' then 7 else 30 end;
    v_target := case when chal.checkin_period = 'daily'
                     then 1 else chal.checkins_per_period end;
    v_end_excl := chal.starts_on + chal.duration_days;
    v_failed := false;

    v_pstart := chal.starts_on;
    while v_pstart < v_end_excl loop
      v_pend := least(v_pstart + v_len, v_end_excl);
      exit when v_pend > v_today;  -- period still running

      -- Judged this period: active members on board before it began
      -- and not yet settled past its end (idempotent catch-up).
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
        -- ONE team shield (oldest unused, any member) saves everyone
        -- from the strike. The penalty still bites - shields guard
        -- lives, not aura, same as solo.
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
        -- Clean period (or nobody judgeable yet): just advance.
        update public.challenge_participants cp
        set settled_until = v_pend
        where cp.challenge_id = chal.id and cp.status = 'active'
          and greatest(chal.starts_on,
                (cp.created_at at time zone 'utc')::date) <= v_pstart
          and (cp.settled_until is null or cp.settled_until < v_pend);
      end if;

      -- One busts the budget -> the whole team goes down (25% each).
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

    -- Survived together -> everyone completes with their own bonus.
    if not v_failed and v_today >= v_end_excl then
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
  -- C) VERSUS PAYOUT: once per finished quest. Winner = most
  -- check-ins per member (fair for uneven teams). Every completed
  -- loser pays 25% tribute into the pot; completed winners split it.
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

    -- A lonely or tied match pays nothing - mark settled either way.
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
          -- The longest-standing winner pockets the rounding rest.
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
end;
$$;

revoke execute on function public.settle_periods() from public, anon, authenticated;
