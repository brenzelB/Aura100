-- =================================================================
--  AURA QUEST - clock quests respect rest days at START
--
--  Before this, clock_start ignored active_weekdays. A clock started
--  on a rest day could not be stopped that day, because the progress
--  entry it becomes is rejected by trg_weekday_progress. The player
--  was left with a running clock and DISCARD as the only exit.
--
--  Only clock_start changes. It is replaced as a whole; the body is
--  the one from 20261102120000_clock_quests.sql plus the weekday check.
--  Additive and safe to apply before or after the 1.0.5 app build.
-- =================================================================

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

  -- A rest day takes no entries (trg_weekday_progress), so a clock
  -- started on one could never be banked: STOP would be refused and
  -- DISCARD would be the only way out. Refuse at the start instead,
  -- with the same words the check-in uses.
  if not (extract(isodow from v_today)::int = any(v_challenge.active_weekdays)) then
    raise exception 'This quest is paused today - it only runs on the days it was set for.';
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
