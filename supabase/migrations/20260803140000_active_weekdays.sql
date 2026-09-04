-- =================================================================
--  AURA QUEST - aktive Wochentage
--
--  Eine Quest kann jetzt auf bestimmte Wochentage beschraenkt werden.
--  Ein abgewaehlter Tag verlangt nichts: kein Check-in, kein
--  Fortschritt, kein Strike, kein verpasster Tag.
--
--  Rueckwaertskompatibel: die Spalte hat den Vorgabewert "alle sieben
--  Tage", damit bestehende Quests sich exakt wie bisher verhalten.
--
--  Wie sich das je Quest-Typ auswirkt:
--
--    Tagesquests   - ein abgewaehlter Tag ist eine uebersprungene
--                    Periode. Nichts wird faellig, nichts gezaehlt.
--    Wochen-/      - die Periode laeuft weiter, aber das Ziel wird auf
--    Monatsquests    die Zahl der aktiven Tage gedeckelt. "6 Check-ins
--                    pro Woche" bei Mo-Fr wird zu 5 - sonst waere die
--                    Vorgabe unerfuellbar.
--    Avoid-Quests  - an einem abgewaehlten Tag gilt die Regel nicht;
--                    ein Ausrutscher dort wird gar nicht erst erfasst.
--    Co-op         - dieselbe Regel fuer die Team-Wertung.
--
--  Erfasst wird gar nichts an inaktiven Tagen: ein Trigger auf
--  check_ins, progress_entries und slips weist sie ab. Damit kommt
--  auch kein kuenftiger Codepfad daran vorbei - dieselbe Bauweise wie
--  bei reject_if_blocked und reject_if_blacked_out.
-- =================================================================

alter table public.challenges
  add column if not exists active_weekdays smallint[] not null
    default '{1,2,3,4,5,6,7}'::smallint[];

comment on column public.challenges.active_weekdays is
  'ISO-Wochentage, an denen die Quest laeuft: 1=Montag ... 7=Sonntag. '
  'Vorgabe sind alle sieben.';

do $$
begin
  if not exists (select 1 from pg_constraint
                 where conname = 'challenges_active_weekdays_check') then
    alter table public.challenges
      add constraint challenges_active_weekdays_check check (
        cardinality(active_weekdays) between 1 and 7
        and active_weekdays <@ '{1,2,3,4,5,6,7}'::smallint[]
      );
  end if;
end $$;


-- ── Nichts erfassen an inaktiven Tagen ───────────────────────────
create or replace function public.reject_if_day_inactive()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_days  smallint[];
  v_today date := (now() at time zone 'utc')::date;
begin
  select active_weekdays into v_days
  from public.challenges where id = new.challenge_id;

  if v_days is not null
     and not (extract(isodow from v_today)::int = any(v_days)) then
    raise exception
      'This quest is paused today - it only runs on the days it was set for.';
  end if;

  return new;
end;
$$;

revoke all on function public.reject_if_day_inactive()
  from public, anon, authenticated;

drop trigger if exists trg_weekday_checkin on public.check_ins;
create trigger trg_weekday_checkin
  before insert on public.check_ins
  for each row execute function public.reject_if_day_inactive();

drop trigger if exists trg_weekday_progress on public.progress_entries;
create trigger trg_weekday_progress
  before insert on public.progress_entries
  for each row execute function public.reject_if_day_inactive();

drop trigger if exists trg_weekday_slip on public.slips;
create trigger trg_weekday_slip
  before insert on public.slips
  for each row execute function public.reject_if_day_inactive();


-- ── Abrechnung ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.settle_periods()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  rec           record;
  chal          record;
  mem           record;
  v_today       date := (now() at time zone 'utc')::date;
  v_len         integer;
  v_target      integer;
  v_ptarget     integer;   -- Ziel DIESER Periode (auf aktive Tage gedeckelt)
  v_active_days integer;   -- aktive Wochentage in DIESER Periode
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
      exit when v_pend > v_today;

      -- Wie viele Tage dieser Periode sind ueberhaupt aktiv? Ein Tag,
      -- dessen Wochentag abgewaehlt wurde, verlangt nichts: kein Ziel,
      -- kein Strike, kein verpasster Tag.
      select count(*)::int into v_active_days
      from generate_series(v_pstart::timestamp,
                           (v_pend - 1)::timestamp,
                           interval '1 day') d
      where extract(isodow from d)::int = any(rec.active_weekdays);

      if v_active_days = 0 then
        -- Ganze Periode faellt aus (bei Tagesquests: dieser eine Tag).
        v_pstart := v_pend;
        continue;
      end if;

      -- Bei Wochen-/Monatsquests kann das Ziel nicht ueber der Zahl der
      -- aktiven Tage liegen - sonst waere es unerfuellbar.
      v_ptarget := least(v_target, v_active_days);

      if v_pstart >= v_active_from
         and (rec.settled_until is null or v_pend > rec.settled_until) then

        select count(*)::int into v_done
        from public.check_ins
        where challenge_id = rec.challenge_id
          and user_id = rec.user_id
          and checked_on >= v_pstart and checked_on < v_pend;

        -- Negative quests invert the test: inaction is the win. A period
        -- that stayed inside its allowance is completed here (a real
        -- check-in, so streaks and stats need no special case) and paid
        -- on a sliding scale. A period that broke the limit was already
        -- charged the moment it broke, so it is left alone.
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
          -- Schlussperiode ohne aktiven Tag ist automatisch bestanden.
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
  end loop;

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

  -- LAST MAN STANDING: <= 1 still standing means it's over.
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
$function$;


-- ── Quest anlegen ────────────────────────────────────────────────
drop function if exists public.create_challenge(text, integer, integer, integer, integer, date, text, text, integer, text, text, numeric, text, boolean, integer);

CREATE OR REPLACE FUNCTION public.create_challenge(p_title text, p_duration_days integer, p_aura_gain integer, p_aura_penalty integer, p_max_strikes integer DEFAULT 1, p_starts_on date DEFAULT NULL::date, p_description text DEFAULT ''::text, p_checkin_period text DEFAULT 'daily'::text, p_checkins_per_period integer DEFAULT 1, p_mode text DEFAULT 'solo'::text, p_goal_type text DEFAULT 'check'::text, p_target_value numeric DEFAULT NULL::numeric, p_unit text DEFAULT NULL::text, p_is_endless boolean DEFAULT false, p_daily_allowance integer DEFAULT 0,
 p_active_weekdays smallint[] DEFAULT '{1,2,3,4,5,6,7}'::smallint[])
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
  v_challenge_id uuid;
  v_per integer := p_checkins_per_period;
  v_unit text := nullif(trim(coalesce(p_unit, '')), '');
  v_endless boolean := p_is_endless or p_mode = 'last_man_standing';
  v_lifecycle text := case when p_mode = 'last_man_standing' then 'lobby' else 'active' end;
  v_allowance integer := coalesce(p_daily_allowance, 0);
begin
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
    (creator_id, title, description, duration_days, aura_gain, aura_penalty, max_strikes, starts_on, checkin_period, checkins_per_period, mode, goal_type, target_value, unit, is_endless, lifecycle, started_at, daily_allowance, active_weekdays)
  values
    (v_user_id, trim(p_title), coalesce(trim(p_description), ''), p_duration_days, p_aura_gain, p_aura_penalty, p_max_strikes,
     coalesce(p_starts_on, (now() at time zone 'utc')::date), p_checkin_period, v_per, p_mode, p_goal_type,
     case when p_goal_type = 'progress' then p_target_value end, case when p_goal_type = 'progress' then v_unit end,
     v_endless, v_lifecycle, case when v_lifecycle = 'active' then now() end,
     case when p_goal_type = 'avoid' then v_allowance else 0 end,
     -- Leere Auswahl waere eine Quest ohne einen einzigen Pflichttag.
     case when p_active_weekdays is null or cardinality(p_active_weekdays) = 0
          then '{1,2,3,4,5,6,7}'::smallint[] else p_active_weekdays end)
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

revoke execute on function public.create_challenge(
  text, integer, integer, integer, integer, date, text, text,
  integer, text, text, numeric, text, boolean, integer, smallint[]
) from public, anon;
grant execute on function public.create_challenge(
  text, integer, integer, integer, integer, date, text, text,
  integer, text, text, numeric, text, boolean, integer, smallint[]
) to authenticated;
