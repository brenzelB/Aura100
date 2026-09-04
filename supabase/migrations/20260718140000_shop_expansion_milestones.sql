-- =================================================================
--  AURA QUEST - shop expansion + milestone moments
--
--  New shop stock (seeded for new AND existing quests):
--   * Double Down (100)   - next check-in earns DOUBLE aura
--   * Roast Shield (80)    - skip the next you-failed roast, once
--   * Strike Repair (500)  - instantly buy back one used strike
--   * The Relentless (400) - cosmetic title shown next to your name
--   * Aura Lord (1000)     - the ultimate flex title for aura hoarders
--
--  New celebrated moment: a consecutive-day check-in STREAK hitting
--  7 / 30 / 100 logs a 'milestone' event, which the app turns into a
--  full celebration screen (the winning counterpart to the roast).
-- =================================================================

-- The event feed learns the two new positive kinds.
alter table public.settlement_events
  drop constraint settlement_events_kind_check;
alter table public.settlement_events
  add constraint settlement_events_kind_check check (kind in
    ('penalty', 'strike', 'shield_saved', 'half_damage',
     'failed', 'completed', 'bonus', 'duel_won', 'duel_lost',
     'versus_won', 'versus_lost', 'milestone', 'strike_repaired'));

-- -----------------------------------------------------------------
-- CREATE_CHALLENGE v6: same signature, richer default shop stock.
-- -----------------------------------------------------------------
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

-- Stock the new items into every EXISTING quest that lacks them.
insert into public.benefits (challenge_id, title, description, cost)
select c.id, v.title, v.description, v.cost
from public.challenges c
cross join (values
  ('Roast Shield',   'Skip the next you-failed roast. We will spare you. Once.', 80),
  ('Double Down',    'Your next check-in earns DOUBLE aura.', 100),
  ('The Relentless', 'A title worn next to your name in the party.', 400),
  ('Strike Repair',  'Instantly buy back one used strike. Pricey.', 500),
  ('Aura Lord',      'The ultimate flex title for aura hoarders.', 1000)
) as v(title, description, cost)
where not exists (
  select 1 from public.benefits b
  where b.challenge_id = c.id and b.title = v.title
);

-- -----------------------------------------------------------------
-- LOG_CHECK_IN v5: + Double Down (double the gain) + streak
-- milestones (7 / 30 / 100 consecutive days -> celebration event).
-- -----------------------------------------------------------------
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

  -- DOUBLE DOWN: consume the oldest unused one to double this gain.
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

  -- STREAK MILESTONES: consecutive check-in days ending today. Fires
  -- once, exactly when the streak lands on a celebrated number.
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

  return v_gain;
end;
$$;

revoke execute on function public.log_check_in(uuid) from public, anon;
grant  execute on function public.log_check_in(uuid) to authenticated;

-- -----------------------------------------------------------------
-- PURCHASE_BENEFIT v2: Strike Repair heals a used strike on purchase
-- (needs one to spend on) and is consumed instantly.
-- -----------------------------------------------------------------
create or replace function public.purchase_benefit(p_benefit_id uuid)
returns integer  -- the new challenge_aura balance
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id     uuid := (select auth.uid());
  v_benefit     public.benefits%rowtype;
  v_participant public.challenge_participants%rowtype;
  v_purchase_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_benefit
  from public.benefits where id = p_benefit_id;
  if not found then
    raise exception 'Benefit not found.';
  end if;

  select * into v_participant
  from public.challenge_participants
  where challenge_id = v_benefit.challenge_id
    and user_id = v_user_id
    and status = 'active'
  for update;
  if not found then
    raise exception 'You are not an active participant of this quest.';
  end if;

  -- Strike Repair only makes sense with a strike on the board.
  if v_benefit.title = 'Strike Repair' and v_participant.strikes_used <= 0 then
    raise exception 'No strikes to repair in this quest.';
  end if;

  if v_participant.challenge_aura < v_benefit.cost then
    raise exception 'Not enough aura in this quest (% needed, % available).',
      v_benefit.cost, v_participant.challenge_aura;
  end if;

  update public.challenge_participants
  set challenge_aura = challenge_aura - v_benefit.cost
  where id = v_participant.id;

  insert into public.benefit_purchases (benefit_id, challenge_id, user_id)
  values (v_benefit.id, v_benefit.challenge_id, v_user_id)
  returning id into v_purchase_id;

  -- Strike Repair: heal one strike and mark the purchase spent.
  if v_benefit.title = 'Strike Repair' then
    update public.challenge_participants
    set strikes_used = strikes_used - 1
    where id = v_participant.id;
    update public.benefit_purchases
      set consumed_at = now() where id = v_purchase_id;
    insert into public.settlement_events
      (user_id, challenge_id, kind, amount, period_start)
    values (v_user_id, v_benefit.challenge_id, 'strike_repaired', 1, null);
  end if;

  return v_participant.challenge_aura - v_benefit.cost;
end;
$$;

revoke execute on function public.purchase_benefit(uuid) from public, anon;
grant  execute on function public.purchase_benefit(uuid) to authenticated;

-- -----------------------------------------------------------------
-- CONSUME_ROAST_SHIELD: spend one unused Roast Shield in this quest.
-- Called by the app when a quest fails; returns whether the roast is
-- to be skipped. Guards lives against the roast, not the failure.
-- -----------------------------------------------------------------
create or replace function public.consume_roast_shield(p_challenge_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select bp.id into v_id
  from public.benefit_purchases bp
  join public.benefits b on b.id = bp.benefit_id
  where bp.challenge_id = p_challenge_id
    and bp.user_id = v_user_id
    and bp.consumed_at is null
    and b.title = 'Roast Shield'
  order by bp.created_at limit 1;
  if not found then
    return false;
  end if;

  update public.benefit_purchases
    set consumed_at = now() where id = v_id;
  return true;
end;
$$;

revoke execute on function public.consume_roast_shield(uuid) from public, anon;
grant  execute on function public.consume_roast_shield(uuid) to authenticated;
