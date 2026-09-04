-- =================================================================
--  AURA QUEST - create_challenge learns the "avoid" goal type
--  Adds p_daily_allowance (slips permitted per period, 0 = cold turkey).
-- =================================================================
create or replace function public.create_challenge(
  p_title text, p_duration_days integer, p_aura_gain integer,
  p_aura_penalty integer, p_max_strikes integer default 1,
  p_starts_on date default null, p_description text default '',
  p_checkin_period text default 'daily', p_checkins_per_period integer default 1,
  p_mode text default 'solo', p_goal_type text default 'check',
  p_target_value numeric default null, p_unit text default null,
  p_is_endless boolean default false, p_daily_allowance integer default 0
)
returns uuid language plpgsql security definer set search_path = '' as $function$
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
    (creator_id, title, description, duration_days, aura_gain, aura_penalty, max_strikes, starts_on, checkin_period, checkins_per_period, mode, goal_type, target_value, unit, is_endless, lifecycle, started_at, daily_allowance)
  values
    (v_user_id, trim(p_title), coalesce(trim(p_description), ''), p_duration_days, p_aura_gain, p_aura_penalty, p_max_strikes,
     coalesce(p_starts_on, (now() at time zone 'utc')::date), p_checkin_period, v_per, p_mode, p_goal_type,
     case when p_goal_type = 'progress' then p_target_value end, case when p_goal_type = 'progress' then v_unit end,
     v_endless, v_lifecycle, case when v_lifecycle = 'active' then now() end,
     case when p_goal_type = 'avoid' then v_allowance else 0 end)
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
