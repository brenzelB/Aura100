-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST - the settlement engine ("Aura = your stake,
--  strikes = your lives")
--
--  A cron job settles every COMPLETED period once:
--   * missed period  -> aura penalty (Half Damage halves it, once)
--                       + strike (Streak Shield absorbs it, once)
--   * budget blown   -> participant fails, keeps 25% of the aura
--   * quest finished -> completed + bonus (remaining strikes x penalty)
--  Every outcome is logged in settlement_events - the future FCM
--  trigger attaches THERE, so switching to push needs no rule change.
-- ═════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- 1. STATE on the participant: what has been settled already.
-- ─────────────────────────────────────────────────────────────────
alter table public.challenge_participants
  add column strikes_used   integer not null default 0,
  add column periods_missed integer not null default 0,
  -- Exclusive end of the last settled period; null = nothing yet.
  add column settled_until  date,
  add column finished_at    timestamptz;

-- Consumables: a purchase gets used up by the settlement.
alter table public.benefit_purchases
  add column consumed_at timestamptz;

-- ─────────────────────────────────────────────────────────────────
-- 2. SETTLEMENT EVENTS - the audit trail the app (and later FCM)
--    feeds on. Written only by the engine.
-- ─────────────────────────────────────────────────────────────────
create table public.settlement_events (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  challenge_id  uuid not null references public.challenges (id) on delete cascade,
  kind          text not null check (kind in
                  ('penalty', 'strike', 'shield_saved', 'half_damage',
                   'failed', 'completed', 'bonus')),
  amount        integer,        -- aura delta where applicable
  period_start  date,           -- which period this was about
  created_at    timestamptz not null default now()
);
create index settlement_events_user_idx
  on public.settlement_events (user_id, created_at desc);

alter table public.settlement_events enable row level security;
grant select on public.settlement_events to authenticated;
create policy "events: users read their own"
  on public.settlement_events for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- ─────────────────────────────────────────────────────────────────
-- 3. THE ENGINE. Runs as postgres via cron; also callable manually.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.settle_periods()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  rec           record;
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
begin
  for rec in
    select cp.id as participant_id, cp.user_id, cp.challenge_id,
           cp.created_at as joined_at, cp.challenge_aura, cp.strikes_used,
           cp.periods_missed, cp.settled_until,
           c.starts_on, c.duration_days, c.checkin_period,
           c.checkins_per_period, c.aura_gain, c.aura_penalty, c.max_strikes
    from public.challenge_participants cp
    join public.challenges c on c.id = cp.challenge_id
    where cp.status = 'active'
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

    -- Walk every period that is fully over and not yet settled.
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

          -- Aura penalty; Half Damage (oldest unused) halves it once.
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

          -- Strike; Streak Shield (oldest unused) absorbs it once.
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

          -- Budget blown -> failed, but 25% of the aura survives
          -- into the lifetime record ("scars still count").
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
        -- Survived to the end: completed + bonus for unused strikes.
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
end;
$$;

revoke execute on function public.settle_periods() from public, anon, authenticated;

-- ─────────────────────────────────────────────────────────────────
-- 4. CRON: hourly at :05. Idempotent (settled_until advances), so a
--    machine that slept simply catches up on the next tick. Once FCM
--    exists, a trigger on settlement_events sends the pushes - the
--    engine itself never changes.
-- ─────────────────────────────────────────────────────────────────
create extension if not exists pg_cron;

do $$
begin
  perform cron.unschedule('aura-settlement');
exception when others then
  null; -- job did not exist yet
end $$;

select cron.schedule(
  'aura-settlement',
  '5 * * * *',
  $$select public.settle_periods()$$
);

-- ─────────────────────────────────────────────────────────────────
-- 5. LOG_CHECK_IN v4: the engine now owns strike evaluation, so the
--    lazy strike loop goes away. Failing is the cron's job; check-in
--    only validates window, membership and the period goal.
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
                    when 'daily' then 1 when 'weekly' then 7 else 30 end;
  v_target := case when v_challenge.checkin_period = 'daily'
                   then 1 else v_challenge.checkins_per_period end;

  v_period_start := v_challenge.starts_on
    + ((v_today - v_challenge.starts_on) / v_period_len) * v_period_len;
  v_period_end := least(
    v_period_start + v_period_len,
    v_challenge.starts_on + v_challenge.duration_days
  );

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

  update public.challenge_participants
  set challenge_aura = challenge_aura + v_challenge.aura_gain
  where id = v_participant.id;

  return v_challenge.aura_gain;
end;
$$;

revoke execute on function public.log_check_in(uuid) from public, anon;
grant  execute on function public.log_check_in(uuid) to authenticated;
