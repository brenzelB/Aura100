-- Follow-up to 00566cc: schema-compatible check-ins, progress goal validation,
-- idempotent coop settlement, no client-settable trigger bypass.
-- Existing migrations remain immutable. Tested with real PostgreSQL + pgTAP.

create or replace function public.reject_if_day_inactive()
returns trigger language plpgsql security definer set search_path = '' as $$
declare c public.challenges%rowtype; d date := (now() at time zone 'utc')::date; plen integer; pend date;
begin
 select * into c from public.challenges where id = new.challenge_id;
 if tg_table_name = 'check_ins' then
   d := new.checked_on;
   if c.goal_type = 'avoid' then
     plen := case c.checkin_period when 'daily' then 1 when 'weekly' then 7 else 30 end;
     pend := d + plen;
     if not c.is_endless then pend := least(pend, c.starts_on+c.duration_days); end if;
     if d < c.starts_on or (d-c.starts_on) % plen <> 0
        or pend > (now() at time zone 'utc')::date or pend <= d
        or not exists(select 1 from generate_series(d::timestamp,(pend-1)::timestamp,interval '1 day') day
          where extract(isodow from day)::int = any(c.active_weekdays)) then
       raise exception 'Avoid bookings require a completed active period.';
     end if;
     return new;
   end if;
 end if;
 if not (extract(isodow from d)::int = any(c.active_weekdays)) then
   raise exception 'This quest is paused today - it only runs on the days it was set for.';
 end if;
 return new;
end $$;
revoke all on function public.reject_if_day_inactive() from public,anon,authenticated;

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
  v_mult         numeric := 1.0;
  v_consumable   uuid;
  v_heist        public.aura_heists%rowtype;
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

  -- The participant lock also serializes add/edit/delete progress.
  -- Validate before payout; an exception rolls back the inserted check-in.
  if v_challenge.goal_type = 'avoid' then
    raise exception 'Avoid successes are recorded by settlement only.';
  end if;
  if v_challenge.goal_type = 'progress' and coalesce((
    select sum(amount) from public.progress_entries
    where challenge_id = p_challenge_id and user_id = v_user_id
      and period_start = v_period_start), 0) < v_challenge.target_value then
    raise exception 'Progress target has not been reached.';
  end if;

  -- Strongest single multiplier wins - titles don't stack.
  if exists (
    select 1 from public.benefit_purchases bp
    join public.benefits b on b.id = bp.benefit_id
    where bp.challenge_id = p_challenge_id and bp.user_id = v_user_id
      and b.title = 'Aura Lord'
  ) then
    v_mult := 2.0;
  elsif exists (
    select 1 from public.benefit_purchases bp
    join public.benefits b on b.id = bp.benefit_id
    where bp.challenge_id = p_challenge_id and bp.user_id = v_user_id
      and b.title = 'Title Badge'
  ) then
    v_mult := 1.2;
  end if;

  -- Double Down is a one-shot x2 - only burn it when it actually beats
  -- the standing title multiplier (highest-only rule, no wasted item).
  if 2.0 > v_mult then
    select bp.id into v_consumable
    from public.benefit_purchases bp
    join public.benefits b on b.id = bp.benefit_id
    where bp.challenge_id = p_challenge_id and bp.user_id = v_user_id
      and bp.consumed_at is null and b.title = 'Double Down'
    order by bp.created_at limit 1;
    if found then
      v_mult := 2.0;
      update public.benefit_purchases
        set consumed_at = now() where id = v_consumable;
    end if;
  end if;

  v_gain := round(v_challenge.aura_gain * v_mult);

  -- A heist waiting on this player? The oldest hit lands: the attacker
  -- pockets this payout, the victim earns nothing (streak still holds).
  select * into v_heist
  from public.aura_heists
  where challenge_id = p_challenge_id
    and target_id = v_user_id
    and succeeded and resolved_at is null
  order by created_at
  limit 1
  for update;

  if found then
    update public.aura_heists
    set resolved_at = now(), stolen_amount = v_gain
    where id = v_heist.id;

    update public.challenge_participants
    set challenge_aura = challenge_aura + v_gain
    where challenge_id = p_challenge_id and user_id = v_heist.attacker_id;

    insert into public.settlement_events
      (user_id, challenge_id, kind, amount, period_start)
    values
      (v_user_id, p_challenge_id, 'heist_robbed', -v_gain, v_today),
      (v_heist.attacker_id, p_challenge_id, 'heist_hit', v_gain, v_today);

    v_gain := 0;
  else
    update public.challenge_participants
    set challenge_aura = challenge_aura + v_gain
    where id = v_participant.id;
  end if;

  -- Streak & milestones (unaffected by a heist - the check-in counts).
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

create or replace function public.log_slip(p_challenge_id uuid)
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
  v_count        integer;
  v_already_over boolean;
  v_now_over     boolean := false;
  v_struck       boolean := false;
  v_shielded     boolean := false;
  v_penalty      integer;
  v_consumable   uuid;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_challenge
  from public.challenges where id = p_challenge_id;
  if not found then
    raise exception 'Quest not found.';
  end if;
  if v_challenge.goal_type <> 'avoid' then
    raise exception 'This quest does not track slips.';
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
  v_period_start := v_challenge.starts_on
    + ((v_today - v_challenge.starts_on) / v_period_len) * v_period_len;

  -- Marker prüfen
  select exists (
    select 1 from public.settlement_events
    where user_id = v_user_id and challenge_id = p_challenge_id
      and kind = 'slip_over' and period_start = v_period_start
  ) into v_already_over;

  insert into public.slips (challenge_id, user_id, period_start)
  values (p_challenge_id, v_user_id, v_period_start);

  select count(*)::int into v_count
  from public.slips
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and period_start = v_period_start;

  if not v_already_over and v_count > v_challenge.daily_allowance then
    v_now_over := true;

    v_penalty := v_challenge.aura_penalty;
    update public.challenge_participants
    set challenge_aura = greatest(0, challenge_aura - v_penalty),
        periods_missed = periods_missed + 1
    where id = v_participant.id;
    insert into public.settlement_events
      (user_id, challenge_id, kind, amount, period_start)
    values (v_user_id, p_challenge_id, 'penalty', -v_penalty, v_period_start);

    select bp.id into v_consumable
    from public.benefit_purchases bp
    join public.benefits b on b.id = bp.benefit_id
    where bp.challenge_id = p_challenge_id and bp.user_id = v_user_id
      and bp.consumed_at is null and b.title = 'Streak Shield'
    order by bp.created_at limit 1;
    if found then
      v_shielded := true;
      update public.benefit_purchases
        set consumed_at = now() where id = v_consumable;
      insert into public.settlement_events
        (user_id, challenge_id, kind, amount, period_start)
      values (v_user_id, p_challenge_id, 'shield_saved', null, v_period_start);
    else
      v_struck := true;
      update public.challenge_participants
      set strikes_used = strikes_used + 1
      where id = v_participant.id;
      insert into public.settlement_events
        (user_id, challenge_id, kind, amount, period_start)
      values (v_user_id, p_challenge_id, 'strike',
              v_participant.strikes_used + 1, v_period_start);
    end if;

    -- Marker: settlement must not charge for this period again.
    insert into public.settlement_events
      (user_id, challenge_id, kind, amount, period_start)
    values (v_user_id, p_challenge_id, 'slip_over', v_count, v_period_start);

    select * into v_participant from public.challenge_participants where id = v_participant.id;
    -- Use the balance AFTER the penalty in the completion event.
    -- Befund 02: Bei überschrittenem Limit sofort eliminieren bzw. scheitern
    if v_struck and v_participant.strikes_used > v_challenge.max_strikes then
      if v_challenge.mode = 'last_man_standing' then
        update public.challenge_participants
        set status = 'eliminated', finished_at = now()
        where id = v_participant.id;
        insert into public.settlement_events
          (user_id, challenge_id, kind, amount, period_start)
        values (v_user_id, p_challenge_id, 'eliminated',
                v_participant.periods_missed, v_period_start);
      else
        update public.challenge_participants
        set status = 'failed', challenge_aura = challenge_aura / 4, finished_at = now()
        where id = v_participant.id;
        insert into public.settlement_events
          (user_id, challenge_id, kind, amount, period_start)
        values (v_user_id, p_challenge_id, 'failed',
                v_participant.challenge_aura / 4, v_period_start);
      end if;

      perform public.settle_periods();
    end if;
  end if;

  select challenge_aura into v_penalty
  from public.challenge_participants where id = v_participant.id;

  return jsonb_build_object(
    'count', v_count,
    'allowance', v_challenge.daily_allowance,
    'over', v_already_over or v_now_over,
    'just_failed', v_now_over,
    'struck', v_struck,
    'shielded', v_shielded,
    'aura', v_penalty
  );
end;
$$;

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
  v_ptarget     integer;
  v_active_days integer;
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
  v_slips       integer;
  v_avoid_gain  integer;
begin
  -- Internal bookings are validated against their completed period by the trigger.

  -- Pass 1: Solo, Versus und Last Man Standing Teilnehmer
  for rec in
    select cp.id as participant_id, cp.user_id, cp.challenge_id,
           cp.created_at as joined_at, cp.challenge_aura, cp.strikes_used,
           cp.periods_missed, cp.settled_until,
           c.starts_on, c.duration_days, c.checkin_period,
           c.checkins_per_period, c.aura_gain, c.aura_penalty, c.max_strikes,
           c.mode, c.is_endless, c.goal_type, c.daily_allowance,
           c.active_weekdays
    from public.challenge_participants cp
    join public.challenges c on c.id = cp.challenge_id
    where cp.status = 'active' and c.mode <> 'coop'
      and c.lifecycle = 'active'
    order by cp.id
    for update of cp
  loop
    -- Fehlerisolierung pro Teilnehmer / Quest
    begin
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

      -- Vorprüfung: Hat der Teilnehmer bereits sein Strike-Limit überschritten?
      if v_strikes > rec.max_strikes then
        v_failed := true;
        if rec.mode = 'last_man_standing' then
          update public.challenge_participants
          set status = 'eliminated', challenge_aura = v_aura,
              strikes_used = v_strikes, periods_missed = v_missed,
              settled_until = coalesce(rec.settled_until, v_today), finished_at = now()
          where id = rec.participant_id;
          insert into public.settlement_events
            (user_id, challenge_id, kind, amount, period_start)
          values (rec.user_id, rec.challenge_id, 'eliminated',
                  v_missed, v_today);
        else
          v_aura := v_aura / 4;
          update public.challenge_participants
          set status = 'failed', challenge_aura = v_aura,
              strikes_used = v_strikes, periods_missed = v_missed,
              settled_until = coalesce(rec.settled_until, v_today), finished_at = now()
          where id = rec.participant_id;
          insert into public.settlement_events
            (user_id, challenge_id, kind, amount, period_start)
          values (rec.user_id, rec.challenge_id, 'failed',
                  v_aura, v_today);
        end if;
        continue;
      end if;

      v_pstart := rec.starts_on +
        (greatest(0, coalesce(rec.settled_until, rec.starts_on) - rec.starts_on) / v_len) * v_len;
      while v_pstart < v_walk_end loop
        v_pend := least(v_pstart + v_len, v_walk_end);
        exit when v_pend > v_today;

        select count(*)::int into v_active_days
        from generate_series(v_pstart::timestamp,
                             (v_pend - 1)::timestamp,
                             interval '1 day') d
        where extract(isodow from d)::int = any(rec.active_weekdays);

        if v_active_days = 0 then
          v_pstart := v_pend;
          continue;
        end if;

        v_ptarget := least(v_target, v_active_days);

        if v_pstart >= v_active_from
           and (rec.settled_until is null or v_pend > rec.settled_until) then

          select count(*)::int into v_done
          from public.check_ins
          where challenge_id = rec.challenge_id
            and user_id = rec.user_id
            and checked_on >= v_pstart and checked_on < v_pend;

          if rec.goal_type = 'avoid' then
            if exists (
              select 1 from public.settlement_events
              where user_id = rec.user_id
                and challenge_id = rec.challenge_id
                and kind = 'slip_over'
                and period_start = v_pstart
            ) then
              v_done := v_ptarget;
            else
              select count(*)::int into v_slips
              from public.slips
              where challenge_id = rec.challenge_id
                and user_id = rec.user_id
                and period_start = v_pstart;

              if rec.daily_allowance > 0 and v_slips > 0 then
                v_avoid_gain := round(rec.aura_gain
                  * (1 - 0.5 * v_slips::numeric / rec.daily_allowance))::int;
              else
                v_avoid_gain := rec.aura_gain;
              end if;
              v_avoid_gain := greatest(0, round(v_avoid_gain
                * public.aura_multiplier(rec.challenge_id, rec.user_id))::int);

              insert into public.check_ins (challenge_id, user_id, checked_on)
              values (rec.challenge_id, rec.user_id, v_pstart)
              on conflict do nothing;

              v_aura := v_aura + v_avoid_gain;
              insert into public.settlement_events
                (user_id, challenge_id, kind, amount, period_start)
              values (rec.user_id, rec.challenge_id, 'avoided',
                      v_avoid_gain, v_pstart);
              v_done := v_ptarget;
            end if;
          end if;

          if v_done < v_ptarget then
            v_missed := v_missed + 1;

            v_penalty := rec.aura_penalty;
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

      -- Nachträgliche Strike-Prüfung (auch bei Avoid / slip_over)
      if not v_failed and v_strikes > rec.max_strikes then
        v_failed := true;
        if rec.mode = 'last_man_standing' then
          update public.challenge_participants
          set status = 'eliminated', challenge_aura = v_aura,
              strikes_used = v_strikes, periods_missed = v_missed,
              settled_until = coalesce(v_pend, rec.settled_until, v_today), finished_at = now()
          where id = rec.participant_id;
          insert into public.settlement_events
            (user_id, challenge_id, kind, amount, period_start)
          values (rec.user_id, rec.challenge_id, 'eliminated',
                  v_missed, coalesce(v_pstart, v_today));
        else
          v_aura := v_aura / 4;
          update public.challenge_participants
          set status = 'failed', challenge_aura = v_aura,
              strikes_used = v_strikes, periods_missed = v_missed,
              settled_until = coalesce(v_pend, rec.settled_until, v_today), finished_at = now()
          where id = rec.participant_id;
          insert into public.settlement_events
            (user_id, challenge_id, kind, amount, period_start)
          values (rec.user_id, rec.challenge_id, 'failed',
                  v_aura, coalesce(v_pstart, v_today));
        end if;
      end if;

      if not v_failed then
        if rec.is_endless then
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
            select count(*)::int into v_active_days
            from generate_series(v_last_start::timestamp,
                                 (v_end_excl - 1)::timestamp,
                                 interval '1 day') d
            where extract(isodow from d)::int = any(rec.active_weekdays);
            v_win := v_active_days = 0
                     or v_final_done >= least(v_target, v_active_days);
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
    exception when others then
      -- Ein Fehler bei einem Teilnehmer darf andere Abrechnungen nicht abbrechen
      raise warning 'settle_periods error for participant %: %', rec.participant_id, sqlerrm;
    end;
  end loop;

  -- Pass 2: Coop Challenges
  for chal in
    select c.*
    from public.challenges c
    where c.mode = 'coop' and c.lifecycle = 'active'
      and exists (select 1 from public.challenge_participants cp
                  where cp.challenge_id = c.id and cp.status = 'active')
    order by c.id
  loop
    begin
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
        exit when v_pend > v_today;

        select count(*)::int into v_active_days
        from generate_series(v_pstart::timestamp,
                             (v_pend - 1)::timestamp,
                             interval '1 day') d
        where extract(isodow from d)::int = any(chal.active_weekdays);
        if v_active_days = 0 then
          v_pstart := v_pend;
          continue;
        end if;
        v_ptarget := least(v_target, v_active_days);

        select bool_or(sub.cnt < v_ptarget) into v_team_missed
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
    exception when others then
      raise warning 'settle_periods error for coop challenge %: %', chal.id, sqlerrm;
    end;
  end loop;

  -- Pass 3: Versus Payout
  for chal in
    select c.*
    from public.challenges c
    where c.mode = 'versus'
      and c.versus_settled_at is null
      and v_today >= c.starts_on + c.duration_days
    order by c.id
  loop
    begin
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
    exception when others then
      raise warning 'settle_periods error for versus challenge %: %', chal.id, sqlerrm;
    end;
  end loop;

  -- Pass 4: LAST MAN STANDING Crowning
  for chal in
    select c.*
    from public.challenges c
    where c.mode = 'last_man_standing' and c.lifecycle = 'active'
    order by c.id
  loop
    begin
      select count(*) filter (where status = 'active'), count(*)
      into v_active_cnt, v_total_cnt
      from public.challenge_participants
      where challenge_id = chal.id;

      if v_active_cnt <= 1 then
        v_bonus := greatest(0, v_total_cnt - 1) * chal.aura_gain;

        for mem in
          select cp.id as participant_id, cp.user_id, cp.challenge_aura
          from public.challenge_participants cp
          where cp.challenge_id = chal.id
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

        -- Crownings mark the LMS quest itself finished.
        update public.challenges
        set lifecycle = 'finished'
        where id = chal.id;
      end if;
    exception when others then
      raise warning 'settle_periods error for LMS challenge %: %', chal.id, sqlerrm;
    end;
  end loop;
end;
$$;

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id   uuid := (select auth.uid());
  v_quest     record;
  v_successor uuid;
  v_duel      record;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  -- Offene Duelle stornieren und Herausforderern ihren Einsatz erstatten
  for v_duel in
    select * from public.duels
    where opponent_id = v_user_id and status = 'pending'
    order by id for update
  loop
    update public.challenge_participants
    set challenge_aura = challenge_aura + v_duel.stake
    where challenge_id = v_duel.challenge_id and user_id = v_duel.challenger_id;

    update public.duels
    set status = 'declined', resolved_at = now()
    where id = v_duel.id;
  end loop;

  -- Quests mit verbleibenden Mitgliedern erhalten (unabhängig vom Status)
  for v_quest in
    select id from public.challenges where creator_id = v_user_id
  loop
    select cp.user_id into v_successor
    from public.challenge_participants cp
    where cp.challenge_id = v_quest.id
      and cp.user_id <> v_user_id
    order by
      case when cp.status = 'active' then 0 else 1 end,
      cp.created_at asc
    limit 1;

    if found then
      update public.challenges
      set creator_id = v_successor
      where id = v_quest.id;
    else
      -- Wirklich niemand sonst war je Teilnehmer dieser Quest
      delete from public.challenges where id = v_quest.id;
    end if;
  end loop;

  delete from auth.users where id = v_user_id;
end;
$$;

revoke all on function public.settle_periods() from public,anon,authenticated;
