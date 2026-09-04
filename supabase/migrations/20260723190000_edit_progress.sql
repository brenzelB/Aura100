-- =================================================================
--  AURA QUEST - correct a progress entry
--
--  Typos happen: you meant +20 and logged +200. These two RPCs let a
--  player edit or delete one of their OWN progress entries, but only:
--    * in the CURRENT period (past periods are settled and locked), and
--    * without dropping a period that was already completed back below
--      its target - the aura / streak / check-in for that crossing has
--      already paid out and can't be cleanly unwound.
--
--  Correcting an over-goal bonus rep, or fixing a typo that stays at or
--  above the goal, is always fine. An edit that first reaches the goal
--  fires the real check-in (aura) exactly like add_progress would.
-- =================================================================

-- ── Shared guard: load the entry + challenge, enforce ownership,
--    current-period-only, and return the bits both RPCs need. ────────
create or replace function public.edit_progress_entry(
  p_entry_id uuid,
  p_amount   numeric
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id      uuid := (select auth.uid());
  v_entry        public.progress_entries%rowtype;
  v_challenge    public.challenges%rowtype;
  v_today        date := (now() at time zone 'utc')::date;
  v_period_len   integer;
  v_cur_start    date;
  v_period_end   date;
  v_done         integer;
  v_old_total    numeric;
  v_new_total    numeric;
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

  select * into v_entry
  from public.progress_entries
  where id = p_entry_id and user_id = v_user_id
  for update;
  if not found then
    raise exception 'That entry is not yours or no longer exists.';
  end if;

  select * into v_challenge
  from public.challenges where id = v_entry.challenge_id;
  if v_challenge.lifecycle <> 'active' then
    raise exception 'This quest is not active right now.';
  end if;

  -- Current period bounds, anchored to starts_on.
  v_period_len := case v_challenge.checkin_period
                    when 'daily' then 1 when 'weekly' then 7 else 30 end;
  v_cur_start := v_challenge.starts_on
    + ((v_today - v_challenge.starts_on) / v_period_len) * v_period_len;
  if v_entry.period_start <> v_cur_start then
    raise exception 'You can only correct entries from the current period.';
  end if;
  v_period_end := v_cur_start + v_period_len;
  if not v_challenge.is_endless then
    v_period_end := least(v_period_end,
      v_challenge.starts_on + v_challenge.duration_days);
  end if;

  -- Did this period already cross the goal (a check-in exists)?
  select count(*)::int into v_done
  from public.check_ins
  where challenge_id = v_entry.challenge_id
    and user_id = v_user_id
    and checked_on >= v_cur_start
    and checked_on < v_period_end;

  select coalesce(sum(amount), 0) into v_old_total
  from public.progress_entries
  where challenge_id = v_entry.challenge_id
    and user_id = v_user_id
    and period_start = v_cur_start;
  v_new_total := v_old_total - v_entry.amount + p_amount;

  if v_done > 0 and v_new_total < v_challenge.target_value then
    raise exception
      'Can''t drop below a goal you already completed - the reward '
      'already paid out. Log a bonus rep or start the next period instead.';
  end if;

  update public.progress_entries
  set amount = p_amount where id = p_entry_id;

  -- Edited up and only now reached the goal: fire the real check-in.
  if v_done = 0 and v_new_total >= v_challenge.target_value then
    perform public.log_check_in(v_entry.challenge_id);
    v_completed := true;
  else
    v_completed := v_done > 0;
  end if;

  return jsonb_build_object(
    'total', v_new_total,
    'target', v_challenge.target_value,
    'completed', v_completed
  );
end;
$$;

create or replace function public.delete_progress_entry(
  p_entry_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id      uuid := (select auth.uid());
  v_entry        public.progress_entries%rowtype;
  v_challenge    public.challenges%rowtype;
  v_today        date := (now() at time zone 'utc')::date;
  v_period_len   integer;
  v_cur_start    date;
  v_period_end   date;
  v_done         integer;
  v_new_total    numeric;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_entry
  from public.progress_entries
  where id = p_entry_id and user_id = v_user_id
  for update;
  if not found then
    raise exception 'That entry is not yours or no longer exists.';
  end if;

  select * into v_challenge
  from public.challenges where id = v_entry.challenge_id;
  if v_challenge.lifecycle <> 'active' then
    raise exception 'This quest is not active right now.';
  end if;

  v_period_len := case v_challenge.checkin_period
                    when 'daily' then 1 when 'weekly' then 7 else 30 end;
  v_cur_start := v_challenge.starts_on
    + ((v_today - v_challenge.starts_on) / v_period_len) * v_period_len;
  if v_entry.period_start <> v_cur_start then
    raise exception 'You can only correct entries from the current period.';
  end if;
  v_period_end := v_cur_start + v_period_len;
  if not v_challenge.is_endless then
    v_period_end := least(v_period_end,
      v_challenge.starts_on + v_challenge.duration_days);
  end if;

  select count(*)::int into v_done
  from public.check_ins
  where challenge_id = v_entry.challenge_id
    and user_id = v_user_id
    and checked_on >= v_cur_start
    and checked_on < v_period_end;

  select coalesce(sum(amount), 0) - v_entry.amount into v_new_total
  from public.progress_entries
  where challenge_id = v_entry.challenge_id
    and user_id = v_user_id
    and period_start = v_cur_start;

  if v_done > 0 and v_new_total < v_challenge.target_value then
    raise exception
      'Can''t drop below a goal you already completed - the reward '
      'already paid out. Log a bonus rep or start the next period instead.';
  end if;

  delete from public.progress_entries where id = p_entry_id;

  return jsonb_build_object(
    'total', v_new_total,
    'target', v_challenge.target_value,
    'completed', v_done > 0
  );
end;
$$;

revoke execute on function public.edit_progress_entry(uuid, numeric) from public, anon;
grant  execute on function public.edit_progress_entry(uuid, numeric) to authenticated;
revoke execute on function public.delete_progress_entry(uuid) from public, anon;
grant  execute on function public.delete_progress_entry(uuid) to authenticated;
