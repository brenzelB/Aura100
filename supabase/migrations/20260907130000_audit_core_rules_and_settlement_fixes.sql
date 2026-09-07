-- =================================================================
-- Migration: 20260907130000_audit_core_rules_and_settlement_fixes.sql
--
-- Behebt die priorisierten Audit-Befunde aus der Sicherheitsprüfung:
--  * Befund 01: reject_if_day_inactive Trigger-Prüfung & Settlement-Fehlerisolierung
--  * Befund 02: Strike-Limit & Ausscheiden bei Avoid-Quests & LMS-Crowning
--  * Befund 03: Typenschutz für log_check_in (nur goal_type = 'check')
--  * Befund 04: Kontolöschung schützt Quests mit verbleibenden Teilnehmern & Duell-Refunds
--  * Befund 13: respond_to_invite prüft LMS-Lobby, Blockierung & Endlos-Quests
--  * Befund 14: handle_new_user Kollisions-Suffix hält 24-Zeichen-Limit strikt ein
--  * Befund 17: send_due_reminders Zeitvergleich mit Timestamp-Arithmetik (22:00+ Fix)
-- =================================================================

-- ── 1. Befund 01: reject_if_day_inactive & Settlement-Bypass ─────

create or replace function public.reject_if_day_inactive()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_days       smallint[];
  v_check_date date;
begin
  -- Interne Settlement-Buchungen (z. B. erfolgreiche Avoid-Perioden)
  -- dürfen niemals durch Wochentags-Ruhetage blockiert werden.
  if current_setting('aura.internal_settlement', true) = 'true' then
    return new;
  end if;

  select active_weekdays into v_days
  from public.challenges where id = new.challenge_id;

  if v_days is not null then
    if tg_table_name = 'check_ins' then
      v_check_date := coalesce(new.checked_on, (now() at time zone 'utc')::date);
    else
      v_check_date := (now() at time zone 'utc')::date;
    end if;

    if not (extract(isodow from v_check_date)::int = any(v_days)) then
      raise exception
        'This quest is paused today - it only runs on the days it was set for.';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.reject_if_day_inactive() from public, anon, authenticated;


-- ── 2. Befund 03: log_check_in nur für goal_type = 'check' ────────

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

  -- Befund 03: Typenprüfung gegen Missbrauch
  if v_challenge.goal_type <> 'check' then
    raise exception 'Direct check-ins are only supported for check quests.';
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
    and executed_at is null
  order by created_at asc
  limit 1
  for update;

  if found then
    update public.aura_heists
    set executed_at = now(), stolen_aura = v_gain
    where id = v_heist.id;

    update public.challenge_participants
    set challenge_aura = challenge_aura + v_gain
    where challenge_id = p_challenge_id and user_id = v_heist.attacker_id;

    insert into public.settlement_events
      (user_id, challenge_id, kind, amount, period_start)
    values (v_heist.attacker_id, p_challenge_id, 'heist_won', v_gain, v_period_start);

    insert into public.settlement_events
      (user_id, challenge_id, kind, amount, period_start)
    values (v_user_id, p_challenge_id, 'heist_lost', -v_gain, v_period_start);

    v_gain := 0;
  else
    update public.challenge_participants
    set challenge_aura = challenge_aura + v_gain
    where id = v_participant.id;
  end if;

  -- Consecutive-days streak walking backward from today.
  v_streak := 0;
  v_cursor := v_today;
  while exists (
    select 1 from public.check_ins
    where challenge_id = p_challenge_id
      and user_id = v_user_id
      and checked_on = v_cursor
  ) loop
    v_streak := v_streak + 1;
    v_cursor := v_cursor - 1;
  end loop;

  update public.challenge_participants
  set current_streak = v_streak,
      longest_streak = greatest(longest_streak, v_streak)
  where id = v_participant.id;

  return v_gain;
end;
$$;

revoke all on function public.log_check_in(uuid) from public, anon;
grant execute on function public.log_check_in(uuid) to authenticated;


-- ── 3. Befund 02: log_slip sauber mit Eliminierung & LMS-Crowning ──

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

    -- Befund 02: Bei überschrittenem Limit sofort eliminieren bzw. scheitern
    if v_struck and v_participant.strikes_used + 1 > v_challenge.max_strikes then
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

revoke all on function public.log_slip(uuid) from public, anon;
grant execute on function public.log_slip(uuid) to authenticated;


-- ── 4. Befunde 01 & 02: settle_periods mit Fehlerisolierung & Strike-Prüfung ──

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
  -- Signalisiert Triggern (reject_if_day_inactive), dass es sich um
  -- die interne System-Abrechnung handelt.
  perform set_config('aura.internal_settlement', 'true', true);

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

      v_pstart := rec.starts_on;
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
          else
            for mem in
              select cp.id as participant_id, cp.user_id, cp.challenge_aura,
                     cp.strikes_used, cp.periods_missed
              from public.challenge_participants cp
              where cp.challenge_id = chal.id and cp.status = 'active'
              order by cp.id
              for update
            loop
              v_strikes := mem.strikes_used + 1;
              v_missed := mem.periods_missed + 1;
              v_aura := greatest(0, mem.challenge_aura - chal.aura_penalty);
              update public.challenge_participants
              set challenge_aura = v_aura, strikes_used = v_strikes,
                  periods_missed = v_missed
              where id = mem.participant_id;
              insert into public.settlement_events
                (user_id, challenge_id, kind, amount, period_start)
              values (mem.user_id, chal.id, 'penalty',
                      -chal.aura_penalty, v_pstart);
              insert into public.settlement_events
                (user_id, challenge_id, kind, amount, period_start)
              values (mem.user_id, chal.id, 'strike', v_strikes, v_pstart);
              if v_strikes > chal.max_strikes then
                v_failed := true;
              end if;
            end loop;
          end if;
        end if;

        if v_failed then
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

revoke all on function public.settle_periods() from public, anon;
grant execute on function public.settle_periods() to authenticated;


-- ── 5. Befund 04: delete_my_account schützt Quests anderer Nutzer ──

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
  loop
    update public.challenge_participants
    set challenge_aura = challenge_aura + v_duel.stake
    where challenge_id = v_duel.challenge_id and user_id = v_duel.challenger_id;

    update public.duels
    set status = 'declined'
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

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;


-- ── 6. Befund 13: respond_to_invite prüft LMS, Endless & Blockierung ─

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
  v_user_id   uuid := (select auth.uid());
  v_invite    public.invites%rowtype;
  v_challenge public.challenges%rowtype;
  v_team      text;
  v_red       integer;
  v_blue      integer;
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
  if not found then
    raise exception 'Quest not found.';
  end if;

  if v_challenge.lifecycle = 'finished' then
    raise exception 'This quest has already ended.';
  end if;

  -- LMS darf nach dem Start keinen späten Beitritt mehr erlauben
  if v_challenge.mode = 'last_man_standing' and v_challenge.lifecycle <> 'lobby' then
    raise exception 'This Last Man Standing quest has already started.';
  end if;

  -- Enddatum nur bei nicht-endlosen Quests prüfen
  if not v_challenge.is_endless
     and (now() at time zone 'utc')::date >= v_challenge.starts_on + v_challenge.duration_days then
    raise exception 'This quest has already ended.';
  end if;

  -- Blockierungsprüfung
  if public.is_blocked_pair(v_user_id, v_invite.inviter_id) then
    raise exception 'You cannot interact with this player.';
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

revoke all on function public.respond_to_invite(uuid, boolean) from public, anon;
grant execute on function public.respond_to_invite(uuid, boolean) to authenticated;


-- ── 7. Befund 14: handle_new_user hält 24-Zeichen Check-Constraint ein ──

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  base_name text;
begin
  base_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'username'), ''),
    split_part(new.email, '@', 1)
  );
  -- profiles.username erzwingt char_length zwischen 3 und 24
  base_name := left(base_name, 24);
  if char_length(base_name) < 3 then
    base_name := base_name || left(replace(new.id::text, '-', ''), 4);
  end if;

  begin
    insert into public.profiles (id, username) values (new.id, left(base_name, 24));
  exception when unique_violation then
    -- Username vergeben: Suffix anhängen.
    -- Maximal 19 Zeichen + '_' + 4 Zeichen UUID = 24 Zeichen
    begin
      insert into public.profiles (id, username)
      values (new.id, left(base_name, 19) || '_' || left(replace(new.id::text, '-', ''), 4));
    exception when unique_violation then
      -- Äußerst seltene Kollision: 14 Zeichen + '_' + 9 Zeichen = 24 Zeichen
      insert into public.profiles (id, username)
      values (new.id, left(base_name, 14) || '_' || substr(replace(new.id::text, '-', ''), 1, 9));
    end;
  end;
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;


-- ── 8. Befund 17: send_due_reminders mit Timestamp-Arithmetik ──────────

create or replace function public.send_due_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  rec       record;
  v_local   timestamp;
  v_today   date;
  v_due     timestamp;
  v_erledigt boolean;
  v_pstart  date;
  v_gesendet integer := 0;
begin
  for rec in
    select r.challenge_id, r.user_id, r.remind_at, r.last_sent_on,
           c.title, c.goal_type, c.checkin_period, c.checkins_per_period,
           c.target_value, c.active_weekdays, c.starts_on, c.duration_days,
           c.is_endless, c.lifecycle,
           coalesce(p.utc_offset_minutes, 0) as offset_min
    from public.quest_reminders r
    join public.challenges c on c.id = r.challenge_id
    join public.profiles   p on p.id = r.user_id
    join public.challenge_participants cp
         on cp.challenge_id = r.challenge_id and cp.user_id = r.user_id
    where r.enabled
      and c.lifecycle = 'active'
      and cp.status = 'active'
  loop
    -- Ortszeit des Spielers
    v_local := (now() at time zone 'utc') + make_interval(mins => rec.offset_min);
    v_today := v_local::date;
    -- Timestamp der Fälligkeit am heutigen Kalendertag
    v_due   := v_today + rec.remind_at;

    -- Noch nicht fällig, oder heute schon erinnert
    if v_local < v_due then continue; end if;
    if rec.last_sent_on is not null and rec.last_sent_on >= v_today then
      continue;
    end if;

    -- Befund 17: Zeitfenster (2 Stunden) auf Timestamp-Ebene prüfen
    -- Verhindert fehlerhaftes Überspringen bei Zeiten ab 22:00 Uhr
    if v_local > v_due + interval '2 hours' then continue; end if;

    -- Läuft die Quest heute überhaupt?
    if not (extract(isodow from v_local)::int = any(rec.active_weekdays)) then
      continue;
    end if;
    if v_today < rec.starts_on then continue; end if;
    if not rec.is_endless
       and v_today >= rec.starts_on + rec.duration_days then continue; end if;

    -- Schon erledigt?
    v_pstart := case rec.checkin_period
      when 'weekly'  then rec.starts_on + (((v_today - rec.starts_on) / 7) * 7)
      when 'monthly' then rec.starts_on + (((v_today - rec.starts_on) / 30) * 30)
      else v_today
    end;

    v_erledigt := case rec.goal_type
      when 'progress' then coalesce((
          select sum(pe.amount) from public.progress_entries pe
          where pe.challenge_id = rec.challenge_id
            and pe.user_id = rec.user_id
            and pe.period_start = v_pstart), 0) >= coalesce(rec.target_value, 0)
      when 'check' then (
          select count(*) from public.check_ins ci
          where ci.challenge_id = rec.challenge_id
            and ci.user_id = rec.user_id
            and ci.checked_on >= v_pstart) >= rec.checkins_per_period
      else false
    end;

    if v_erledigt then
      update public.quest_reminders
        set last_sent_on = v_today
        where challenge_id = rec.challenge_id and user_id = rec.user_id;
      continue;
    end if;

    perform public.enqueue_notification(
      rec.user_id,
      'quest',
      rec.challenge_id,
      'Still open: ' || rec.title,
      case rec.goal_type
        when 'avoid' then 'Still clean today? Log a slip if not.'
        when 'progress' then 'You have not hit today''s target yet.'
        else 'You have not checked in yet today.'
      end
    );

    update public.quest_reminders
      set last_sent_on = v_today
      where challenge_id = rec.challenge_id and user_id = rec.user_id;
    v_gesendet := v_gesendet + 1;
  end loop;

  return v_gesendet;
end;
$$;

revoke all on function public.send_due_reminders() from public, anon, authenticated;
