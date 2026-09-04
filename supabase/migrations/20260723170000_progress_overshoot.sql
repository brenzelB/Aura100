-- =================================================================
--  AURA QUEST - progress overshoot
--
--  Once a progress quest's period target is met you can KEEP logging.
--  The extra reps don't change the goal (it's already done, the aura +
--  check-in fire exactly once), but every rep is recorded so lifetime
--  / weekly / monthly totals reflect the real work.
--
--  Also makes add_progress endless-aware and lifecycle-safe.
-- =================================================================

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
  v_overshoot    boolean := false;
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

  -- Period bounds, anchored to starts_on (same rule as everywhere).
  v_period_len := case v_challenge.checkin_period
                    when 'daily' then 1 when 'weekly' then 7 else 30 end;
  v_period_start := v_challenge.starts_on
    + ((v_today - v_challenge.starts_on) / v_period_len) * v_period_len;
  v_period_end := v_period_start + v_period_len;
  if not v_challenge.is_endless then
    v_period_end := least(v_period_end,
      v_challenge.starts_on + v_challenge.duration_days);
  end if;

  -- Was the target already reached this period? (A check-in exists.)
  select count(*)::int into v_done
  from public.check_ins
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and checked_on >= v_period_start
    and checked_on < v_period_end;

  -- Always record the rep - overshoot is documented, not blocked.
  insert into public.progress_entries
    (challenge_id, user_id, amount, period_start)
  values (p_challenge_id, v_user_id, p_amount, v_period_start);

  select coalesce(sum(amount), 0) into v_total
  from public.progress_entries
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and period_start = v_period_start;

  if v_done > 0 then
    -- Goal was already met earlier: this rep is bonus. No second
    -- check-in, no extra aura - just on the record.
    v_completed := true;
    v_overshoot := true;
  elsif v_total >= v_challenge.target_value then
    -- First time crossing the line: the real check-in pays out once
    -- (aura, Double Down, streak milestones, instant win).
    v_completed := true;
    v_gained := public.log_check_in(p_challenge_id);
  end if;

  return jsonb_build_object(
    'total', v_total,
    'target', v_challenge.target_value,
    'completed', v_completed,
    'overshoot', v_overshoot,
    'gained', v_gained
  );
end;
$$;

revoke execute on function public.add_progress(uuid, numeric) from public, anon;
grant  execute on function public.add_progress(uuid, numeric) to authenticated;
