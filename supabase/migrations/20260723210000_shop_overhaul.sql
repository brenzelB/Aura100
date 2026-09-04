-- =================================================================
--  AURA QUEST - shop overhaul
--
--  * Retire Roast Shield, Half Damage, The Relentless.
--  * Title Badge  -> visual emblem by the name + PERMANENT +20% aura
--                    on every check-in.
--  * Aura Lord    -> visual crown by the name + PERMANENT x2 aura
--                    on every check-in.
--  * Only the strongest multiplier ever applies (they don't stack);
--    Double Down (one-shot x2) is only spent when it actually beats
--    the standing title multiplier.
--  * NEW Aura Heist (PvP): pay 150/300/500 for a 25/50/75% chance to
--    rob a quest mate's NEXT check-in aura. The dice are rolled at
--    purchase (attacker sees hit/miss at once); a hit lies in wait and,
--    on the victim's next check-in, transfers that payout to the
--    attacker while the victim earns nothing (their streak still holds).
-- =================================================================

-- ── 1. Retire three items (dev purchases cascade away) ───────────
delete from public.benefits
where title in ('Roast Shield', 'Half Damage', 'The Relentless');

update public.benefits
set description = 'A golden emblem by your name — and +20% aura on every check-in.'
where title = 'Title Badge';

update public.benefits
set description = 'A crown by your name — and DOUBLE aura on every check-in.'
where title = 'Aura Lord';

-- ── 2. Aura Heist table ──────────────────────────────────────────
create table if not exists public.aura_heists (
  id              uuid primary key default gen_random_uuid(),
  challenge_id    uuid not null references public.challenges(id) on delete cascade,
  attacker_id     uuid not null references public.profiles(id) on delete cascade,
  target_id       uuid not null references public.profiles(id) on delete cascade,
  cost            integer not null check (cost in (150, 300, 500)),
  chance          numeric not null,
  succeeded       boolean not null,
  stolen_amount   integer,
  created_at      timestamptz not null default now(),
  resolved_at     timestamptz,   -- when a check-in settled the hit
  acknowledged_at timestamptz    -- when the victim saw the notice
);

create index if not exists aura_heists_pending_idx
  on public.aura_heists (target_id)
  where succeeded and resolved_at is null;
create index if not exists aura_heists_notice_idx
  on public.aura_heists (target_id)
  where succeeded and resolved_at is not null and acknowledged_at is null;

alter table public.aura_heists enable row level security;
grant select, update on public.aura_heists to authenticated;

drop policy if exists "heists readable by the two sides" on public.aura_heists;
create policy "heists readable by the two sides"
  on public.aura_heists for select to authenticated
  using (attacker_id = (select auth.uid()) or target_id = (select auth.uid()));

drop policy if exists "heists ack by target" on public.aura_heists;
create policy "heists ack by target"
  on public.aura_heists for update to authenticated
  using (target_id = (select auth.uid()));

-- ── 3. New settlement kinds for the activity feed ────────────────
alter table public.settlement_events drop constraint settlement_events_kind_check;
alter table public.settlement_events add constraint settlement_events_kind_check
  check (kind = any (array[
    'penalty','strike','shield_saved','half_damage','failed','completed',
    'bonus','duel_won','duel_lost','versus_won','versus_lost','milestone',
    'strike_repaired','eliminated','lms_finished','heist_robbed','heist_hit'
  ]));

-- ── 4. Buy & roll a heist in one transaction ─────────────────────
create or replace function public.attempt_aura_heist(
  p_challenge_id uuid,
  p_target_id uuid,
  p_cost integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id   uuid := (select auth.uid());
  v_lifecycle text;
  v_chance    numeric;
  v_aura      integer;
  v_succeeded boolean;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if v_user_id = p_target_id then
    raise exception 'You cannot rob yourself.';
  end if;
  if p_cost not in (150, 300, 500) then
    raise exception 'Invalid heist tier.';
  end if;
  v_chance := case p_cost when 150 then 0.25 when 300 then 0.50 else 0.75 end;

  select lifecycle into v_lifecycle
  from public.challenges where id = p_challenge_id;
  if not found then
    raise exception 'Quest not found.';
  end if;
  if v_lifecycle <> 'active' then
    raise exception 'This quest is not running right now.';
  end if;

  if not exists (
    select 1 from public.challenge_participants
    where challenge_id = p_challenge_id
      and user_id = p_target_id
      and status = 'active'
  ) then
    raise exception 'Target is not an active member of this quest.';
  end if;

  -- One live heist per attacker+target: no stacking a queue on someone.
  if exists (
    select 1 from public.aura_heists
    where challenge_id = p_challenge_id
      and attacker_id = v_user_id
      and target_id = p_target_id
      and succeeded and resolved_at is null
  ) then
    raise exception 'You already have a heist waiting on them.';
  end if;

  select challenge_aura into v_aura
  from public.challenge_participants
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and status = 'active'
  for update;
  if not found then
    raise exception 'You are not an active member of this quest.';
  end if;
  if v_aura < p_cost then
    raise exception 'Not enough aura - this heist costs %.', p_cost;
  end if;

  update public.challenge_participants
  set challenge_aura = challenge_aura - p_cost
  where challenge_id = p_challenge_id and user_id = v_user_id;

  v_succeeded := random() < v_chance;

  insert into public.aura_heists
    (challenge_id, attacker_id, target_id, cost, chance, succeeded, resolved_at)
  values
    (p_challenge_id, v_user_id, p_target_id, p_cost, v_chance, v_succeeded,
     case when v_succeeded then null else now() end);

  return jsonb_build_object(
    'succeeded', v_succeeded,
    'chance', v_chance,
    'cost', p_cost,
    'new_balance', v_aura - p_cost
  );
end;
$$;

revoke execute on function public.attempt_aura_heist(uuid, uuid, integer) from public, anon;
grant  execute on function public.attempt_aura_heist(uuid, uuid, integer) to authenticated;

-- ── 5. Check-in with title multipliers + heist settlement ────────
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

revoke execute on function public.log_check_in(uuid) from public, anon;
grant  execute on function public.log_check_in(uuid) to authenticated;

-- ── 6. Seeding: core set on create, PvP items via trigger ────────
create or replace function public.create_challenge(
  p_title text, p_duration_days integer, p_aura_gain integer,
  p_aura_penalty integer, p_max_strikes integer default 1,
  p_starts_on date default null, p_description text default '',
  p_checkin_period text default 'daily', p_checkins_per_period integer default 1,
  p_mode text default 'solo', p_goal_type text default 'check',
  p_target_value numeric default null, p_unit text default null,
  p_is_endless boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_challenge_id uuid;
  v_per integer := p_checkins_per_period;
  v_unit text := nullif(trim(coalesce(p_unit, '')), '');
  v_endless boolean := p_is_endless or p_mode = 'last_man_standing';
  v_lifecycle text := case when p_mode = 'last_man_standing'
                           then 'lobby' else 'active' end;
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
  if p_mode not in ('solo', 'coop', 'versus', 'last_man_standing') then
    raise exception 'Invalid quest mode.';
  end if;
  if p_goal_type not in ('check', 'progress') then
    raise exception 'Invalid goal type.';
  end if;
  if v_endless and p_mode = 'versus' then
    raise exception 'Versus quests need a fixed end date.';
  end if;

  if p_goal_type = 'progress' then
    v_per := 1;
    if p_target_value is null or p_target_value <= 0 then
      raise exception 'Set a target greater than 0.';
    end if;
    if p_target_value > 1000000 then
      raise exception 'Target must be at most 1000000.';
    end if;
    if v_unit is null or length(v_unit) > 24 then
      raise exception 'Give the target a unit (max 24 characters).';
    end if;
  elsif p_checkin_period = 'daily' then
    v_per := 1;
  elsif p_checkin_period = 'weekly' and v_per not between 1 and 7 then
    raise exception 'Weekly quests need 1-7 check-ins per week.';
  elsif p_checkin_period = 'monthly' and v_per not between 1 and 30 then
    raise exception 'Monthly quests need 1-30 check-ins per month.';
  end if;

  insert into public.challenges
    (creator_id, title, description, duration_days, aura_gain, aura_penalty,
     max_strikes, starts_on, checkin_period, checkins_per_period, mode,
     goal_type, target_value, unit, is_endless, lifecycle, started_at)
  values
    (v_user_id, trim(p_title), coalesce(trim(p_description), ''),
     p_duration_days, p_aura_gain, p_aura_penalty, p_max_strikes,
     coalesce(p_starts_on, (now() at time zone 'utc')::date),
     p_checkin_period, v_per, p_mode,
     p_goal_type,
     case when p_goal_type = 'progress' then p_target_value end,
     case when p_goal_type = 'progress' then v_unit end,
     v_endless, v_lifecycle,
     case when v_lifecycle = 'active' then now() end)
  returning id into v_challenge_id;

  insert into public.challenge_participants (challenge_id, user_id, team)
  values (v_challenge_id, v_user_id,
          case when p_mode = 'versus' then 'red' else null end);

  -- Core shop. PvP items (Targeted Roast, Aura Heist) are added by the
  -- after-insert trigger so every path to a new challenge gets them.
  insert into public.benefits (challenge_id, title, description, cost) values
    (v_challenge_id, 'Title Badge',
     'A golden emblem by your name — and +20% aura on every check-in.', 50),
    (v_challenge_id, 'Double Down',
     'Your next check-in earns DOUBLE aura.', 100),
    (v_challenge_id, 'Streak Shield',
     'One missed day is forgiven - no strike.', 300),
    (v_challenge_id, 'Strike Repair',
     'Instantly buy back one used strike. Pricey.', 500),
    (v_challenge_id, 'Aura Lord',
     'A crown by your name — and DOUBLE aura on every check-in.', 1000);

  return v_challenge_id;
end;
$function$;

-- PvP items seeded on every new challenge (replaces the roast-only trigger).
create or replace function public.seed_pvp_benefits()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.benefits (challenge_id, title, description, cost) values
    (new.id, 'Targeted Roast',
     'Roast a quest mate: locks their screen with a savage burn. 3s for 120, 5s for 200.',
     120),
    (new.id, 'Aura Heist',
     'Rob a quest mate''s next check-in aura. 150 = 25%, 300 = 50%, 500 = 75% odds.',
     150);
  return new;
end;
$$;

drop trigger if exists trg_seed_targeted_roast on public.challenges;
drop trigger if exists trg_seed_pvp on public.challenges;
create trigger trg_seed_pvp
  after insert on public.challenges
  for each row execute function public.seed_pvp_benefits();

-- Backfill Aura Heist into existing challenges (roast already seeded).
insert into public.benefits (challenge_id, title, description, cost)
select c.id, 'Aura Heist',
       'Rob a quest mate''s next check-in aura. 150 = 25%, 300 = 50%, 500 = 75% odds.',
       150
from public.challenges c
where not exists (
  select 1 from public.benefits b
  where b.challenge_id = c.id and b.title = 'Aura Heist'
);
