-- Trial balance, permanent progression, and account-wide attack limits.
select public.lock_game_state();
alter table public.challenges
  add column balance_preset text not null default 'custom' check (balance_preset in ('chill','classic','chaos','custom')),
  add column attacks_enabled boolean not null default true;
alter table public.challenge_participants add column comeback_needed boolean not null default false;

create table public.player_xp_events (
  user_id uuid not null references public.profiles(id) on delete cascade,
  -- Deliberately survives leaving/deleting a quest. Account deletion still erases it.
  challenge_id uuid not null,
  unit_on date not null,
  xp integer not null check (xp between 0 and 100),
  created_at timestamptz not null default now(),
  primary key(user_id, challenge_id, unit_on)
);
create index player_xp_day_idx on public.player_xp_events(user_id, unit_on) include(xp);
alter table public.player_xp_events enable row level security;
revoke all on public.player_xp_events from public, anon, authenticated;
grant select on public.player_xp_events to authenticated;
create policy own_xp on public.player_xp_events for select to authenticated using(user_id=(select auth.uid()));

-- Available historical confirmations only. No inferred/deleted history.
insert into public.player_xp_events(user_id,challenge_id,unit_on,xp)
select user_id,challenge_id,checked_on,case when position<=5 then 100 else 0 end
from (select ci.*,row_number() over(partition by user_id,checked_on order by ci.created_at,ci.id) position
      from public.check_ins ci) historical;

create function public.record_unit_xp() returns trigger language plpgsql security definer set search_path='' as $$
declare v_used integer; v_eligible boolean;
begin
  perform public.lock_game_state();
  select new.checked_on >= greatest((c.created_at at time zone 'utc')::date,(cp.created_at at time zone 'utc')::date)
    into v_eligible from public.challenges c join public.challenge_participants cp on cp.challenge_id=c.id
    where c.id=new.challenge_id and cp.user_id=new.user_id;
  select coalesce(sum(xp),0)::int into v_used from public.player_xp_events where user_id=new.user_id and unit_on=new.checked_on;
  insert into public.player_xp_events(user_id,challenge_id,unit_on,xp)
    values(new.user_id,new.challenge_id,new.checked_on,case when v_eligible then greatest(0,least(100,500-v_used)) else 0 end)
    on conflict do nothing;
  update public.challenge_participants set comeback_needed=false
    where challenge_id=new.challenge_id and user_id=new.user_id
      and not exists(select 1 from public.settlement_events e where e.challenge_id=new.challenge_id and e.user_id=new.user_id
        and e.kind='penalty' and e.period_start>=new.checked_on);
  return new;
end $$;
revoke all on function public.record_unit_xp() from public,anon,authenticated;
create trigger record_unit_xp after insert on public.check_ins for each row execute function public.record_unit_xp();

create function public.mark_comeback() returns trigger language plpgsql security definer set search_path='' as $$
begin
  update public.challenge_participants set comeback_needed=true
    where challenge_id=new.challenge_id and user_id=new.user_id
      and not exists(select 1 from public.check_ins ci join public.challenges c on c.id=ci.challenge_id
        where ci.challenge_id=new.challenge_id and ci.user_id=new.user_id
        and ci.checked_on >= new.period_start + case c.checkin_period when 'daily' then 1 when 'weekly' then 7 else 30 end);
  return new;
end $$;
revoke all on function public.mark_comeback() from public,anon,authenticated;
create trigger mark_comeback after insert on public.settlement_events for each row when(new.kind='penalty') execute function public.mark_comeback();
update public.challenge_participants cp set comeback_needed=true
where exists(select 1 from public.settlement_events e join public.challenges c on c.id=e.challenge_id
  where e.challenge_id=cp.challenge_id and e.user_id=cp.user_id and e.kind='penalty'
  and not exists(select 1 from public.check_ins ci where ci.challenge_id=cp.challenge_id and ci.user_id=cp.user_id
    and ci.checked_on>=e.period_start+case c.checkin_period when 'daily' then 1 when 'weekly' then 7 else 30 end));

create function public.balance_price(p_reward integer,p_item text,p_tier integer default 1) returns integer
language plpgsql immutable set search_path='' as $$
declare v_percent integer;
begin
  v_percent := case p_item when 'Title Badge' then 200 when 'Double Down' then 80 when 'Streak Shield' then 100
    when 'Strike Repair' then 200 when 'Aura Lord' then 1000 when 'Aura Ward' then 25
    when 'Aura Heist' then case p_tier when 1 then 20 when 2 then 40 when 3 then 60 end
    when 'Targeted Roast' then case p_tier when 1 then 50 when 2 then 75 end when 'Blackout' then 150 end;
  if v_percent is null or p_reward is null or p_reward<0 then raise exception 'Invalid shop price input.'; end if;
  return greatest(1,ceil(p_reward::numeric*v_percent/100)::int);
end $$;
revoke all on function public.balance_price(integer,text,integer) from public,anon,authenticated;

create function public.price_quest_benefit() returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.title in ('Title Badge','Double Down','Streak Shield','Strike Repair','Aura Lord','Aura Ward','Aura Heist','Targeted Roast','Blackout') then
    new.cost:=public.balance_price((select aura_gain from public.challenges where id=new.challenge_id),new.title);
  end if;
  if new.title='Aura Heist' then new.description:='Choose 25%, 50% or 75% odds. Steals at most one base reward within 24 hours; wards can block it. One incoming success per UTC day.'; end if;
  if new.title='Streak Shield' then new.description:='One missed period costs no strike. The normal Aura penalty still applies.'; end if;
  return new;
end $$;
revoke all on function public.price_quest_benefit() from public,anon,authenticated;
create trigger price_quest_benefit before insert or update on public.benefits for each row execute function public.price_quest_benefit();
update public.benefits set cost=cost;

create function public.seed_aura_ward() returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.benefits(challenge_id,title,description,cost) values(new.id,'Aura Ward','Blocks the next successful heist in this quest. Consumed once; XP is always safe.',1);
  return new;
end $$;
revoke all on function public.seed_aura_ward() from public,anon,authenticated;
create trigger seed_aura_ward after insert on public.challenges for each row execute function public.seed_aura_ward();
insert into public.benefits(challenge_id,title,description,cost)
select id,'Aura Ward','Blocks the next successful heist in this quest. Consumed once; XP is always safe.',1 from public.challenges;
update public.benefits set description='Choose 25%, 50% or 75% odds. Steals at most one base reward within 24 hours; wards can block it. One incoming success per UTC day.' where title='Aura Heist';
update public.benefits set description='One missed period costs no strike. The normal Aura penalty still applies.' where title='Streak Shield';

alter table public.aura_heists drop constraint aura_heists_cost_check;
alter table public.aura_heists add constraint aura_heists_cost_check check(cost>0);
create index heist_target_day_idx on public.aura_heists(target_id,created_at) where succeeded;
create index heist_target_paid_idx on public.aura_heists(target_id,resolved_at) where stolen_amount>0;
create index heist_actor_day_idx on public.aura_heists(attacker_id,created_at);
create index roast_actor_day_idx on public.targeted_roasts(sender_id,created_at);
create index blackout_actor_day_idx on public.blackouts(attacker_id,created_at);

create function public.check_attack_rules(p_quest uuid,p_target uuid) returns void language plpgsql security definer set search_path='' as $$
declare v_c public.challenges%rowtype; v_today date:=(now() at time zone 'utc')::date; v_count integer;
begin
  perform public.lock_game_state();
  if auth.uid() is null or p_target is null or p_target=auth.uid() then raise exception 'Choose another active player.'; end if;
  select * into v_c from public.challenges where id=p_quest;
  if not found or v_c.lifecycle<>'active' or v_today<v_c.starts_on or (not v_c.is_endless and v_today>=v_c.starts_on+v_c.duration_days) then
    raise exception 'This quest is not running right now.';
  end if;
  if not v_c.attacks_enabled then raise exception 'Attacks are disabled for this quest.'; end if;
  if v_c.aura_gain<=0 then raise exception 'The shop needs a positive base reward.'; end if;
  if (select count(*) from public.challenge_participants where challenge_id=p_quest and status='active' and user_id in(auth.uid(),p_target))<>2 then
    raise exception 'Both players must be active members.';
  end if;
  select count(*) into v_count from (
    select 1 from public.aura_heists where attacker_id=auth.uid() and created_at>=v_today::timestamp at time zone 'utc'
    union all select 1 from public.targeted_roasts where sender_id=auth.uid() and created_at>=v_today::timestamp at time zone 'utc'
    union all select 1 from public.blackouts where attacker_id=auth.uid() and created_at>=v_today::timestamp at time zone 'utc'
  ) attacks;
  if v_count>=3 then raise exception 'Daily attack limit reached (3 per account, resets at 00:00 UTC).'; end if;
end $$;
revoke all on function public.check_attack_rules(uuid,uuid) from public,anon,authenticated;

-- Preserve all existing event kinds while adding explicit defense/expiry feedback.
do $$ declare v_check text; begin
  select pg_get_constraintdef(oid) into v_check from pg_constraint where conrelid='public.settlement_events'::regclass and conname='settlement_events_kind_check';
  alter table public.settlement_events drop constraint settlement_events_kind_check;
  execute 'alter table public.settlement_events add constraint settlement_events_kind_check check ((' || substring(v_check from 8 for length(v_check)-8) || ') or kind in (''heist_blocked'',''heist_expired''))';
end $$;

create function public.resolve_checkin_heist(p_quest uuid,p_user uuid,p_gain integer,p_base integer) returns integer
language plpgsql security definer set search_path='' as $$
declare v_h public.aura_heists%rowtype; v_ward uuid; v_stolen integer; v_day timestamptz:=date_trunc('day',now() at time zone 'utc') at time zone 'utc';
begin
  perform public.lock_game_state();
  for v_h in select * from public.aura_heists where challenge_id=p_quest and target_id=p_user and succeeded and resolved_at is null order by created_at,id for update loop
    if v_h.created_at<=now()-interval '24 hours'
      or exists(select 1 from public.aura_heists where target_id=p_user and stolen_amount>0 and resolved_at>=v_day)
      or not exists(select 1 from public.challenge_participants where challenge_id=p_quest and user_id=v_h.attacker_id and status='active') then
      update public.aura_heists set resolved_at=now(),stolen_amount=0,acknowledged_at=now() where id=v_h.id;
      insert into public.settlement_events(user_id,challenge_id,kind,amount) values(v_h.attacker_id,p_quest,'heist_expired',0);
      continue;
    end if;
    select bp.id into v_ward from public.benefit_purchases bp join public.benefits b on b.id=bp.benefit_id
      where bp.challenge_id=p_quest and bp.user_id=p_user and bp.consumed_at is null and b.title='Aura Ward' order by bp.created_at,bp.id limit 1;
    if found then
      update public.benefit_purchases set consumed_at=now() where id=v_ward;
      update public.aura_heists set resolved_at=now(),stolen_amount=0,acknowledged_at=now() where id=v_h.id;
      insert into public.settlement_events(user_id,challenge_id,kind,amount) values(p_user,p_quest,'heist_blocked',0),(v_h.attacker_id,p_quest,'heist_blocked',0);
      return p_gain;
    end if;
    v_stolen:=least(p_gain,p_base);
    update public.aura_heists set resolved_at=now(),stolen_amount=v_stolen where id=v_h.id;
    update public.challenge_participants set challenge_aura=challenge_aura+v_stolen where challenge_id=p_quest and user_id=v_h.attacker_id;
    insert into public.settlement_events(user_id,challenge_id,kind,amount,period_start) values
      (p_user,p_quest,'heist_robbed',-v_stolen,(now() at time zone 'utc')::date),
      (v_h.attacker_id,p_quest,'heist_hit',v_stolen,(now() at time zone 'utc')::date);
    return p_gain-v_stolen;
  end loop;
  return p_gain;
end $$;
revoke all on function public.resolve_checkin_heist(uuid,uuid,integer,integer) from public,anon,authenticated;

drop function public.create_challenge(text,integer,integer,integer,integer,date,text,text,integer,text,text,numeric,text,boolean,integer,smallint[]);
CREATE OR REPLACE FUNCTION public.create_challenge(p_title text, p_duration_days integer, p_aura_gain integer, p_aura_penalty integer, p_max_strikes integer DEFAULT 1, p_starts_on date DEFAULT NULL::date, p_description text DEFAULT ''::text, p_checkin_period text DEFAULT 'daily'::text, p_checkins_per_period integer DEFAULT 1, p_mode text DEFAULT 'solo'::text, p_goal_type text DEFAULT 'check'::text, p_target_value numeric DEFAULT NULL::numeric, p_unit text DEFAULT NULL::text, p_is_endless boolean DEFAULT false, p_daily_allowance integer DEFAULT 0, p_active_weekdays smallint[] DEFAULT '{1,2,3,4,5,6,7}'::smallint[], p_balance_preset text DEFAULT 'custom', p_attacks_enabled boolean DEFAULT true)
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
  perform public.lock_game_state();
  if p_balance_preset is null or p_balance_preset not in ('chill','classic','chaos','custom') or p_attacks_enabled is null then raise exception 'Invalid balance preset.'; end if;
  if p_balance_preset<>'custom' then
    p_aura_gain:=100;
    p_aura_penalty:=case p_balance_preset when 'chill' then 10 when 'classic' then 25 else 50 end;
    p_max_strikes:=case p_balance_preset when 'chill' then 5 when 'classic' then 3 else 1 end;
    p_attacks_enabled:=p_balance_preset<>'chill';
  end if;
  if p_starts_on<(now() at time zone 'utc')::date then raise exception 'New quests cannot start in the past.'; end if;
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
    (creator_id, title, description, duration_days, aura_gain, aura_penalty, max_strikes, starts_on, checkin_period, checkins_per_period, mode, goal_type, target_value, unit, is_endless, lifecycle, started_at, daily_allowance, active_weekdays, balance_preset, attacks_enabled)
  values
    (v_user_id, trim(p_title), coalesce(trim(p_description), ''), p_duration_days, p_aura_gain, p_aura_penalty, p_max_strikes,
     coalesce(p_starts_on, (now() at time zone 'utc')::date), p_checkin_period, v_per, p_mode, p_goal_type,
     case when p_goal_type = 'progress' then p_target_value end, case when p_goal_type = 'progress' then v_unit end,
     v_endless, v_lifecycle, case when v_lifecycle = 'active' then now() end,
     case when p_goal_type = 'avoid' then v_allowance else 0 end,
     -- Leere Auswahl waere eine Quest ohne einen einzigen Pflichttag.
     case when p_active_weekdays is null or cardinality(p_active_weekdays) = 0
          then '{1,2,3,4,5,6,7}'::smallint[] else p_active_weekdays end, p_balance_preset, p_attacks_enabled)
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
$function$
;

revoke all on function public.create_challenge(text,integer,integer,integer,integer,date,text,text,integer,text,text,numeric,text,boolean,integer,smallint[],text,boolean) from public,anon;
grant execute on function public.create_challenge(text,integer,integer,integer,integer,date,text,text,integer,text,text,numeric,text,boolean,integer,smallint[],text,boolean) to authenticated;
drop function public.attempt_aura_heist(uuid,uuid,integer);
CREATE OR REPLACE FUNCTION public.attempt_aura_heist(p_challenge_id uuid, p_target_id uuid, p_tier integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id   uuid := (select auth.uid());
  v_lifecycle text;
  p_cost integer;
  v_chance    numeric;
  v_aura      integer;
  v_succeeded boolean;
begin
  perform public.lock_game_state();
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if v_user_id = p_target_id then
    raise exception 'You cannot rob yourself.';
  end if;
  if p_tier is null or p_tier not in (1,2,3) then
    raise exception 'Invalid heist tier.';
  end if;
  perform public.check_attack_rules(p_challenge_id,p_target_id);
  if (select goal_type from public.challenges where id=p_challenge_id)='avoid' then raise exception 'Heists need a check-in or progress quest.'; end if;
  p_cost:=public.balance_price((select aura_gain from public.challenges where id=p_challenge_id),'Aura Heist',p_tier);
  v_chance:=p_tier*0.25;

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

  if exists(select 1 from public.aura_heists where target_id=p_target_id and succeeded
    and ((created_at>=date_trunc('day',now() at time zone 'utc') at time zone 'utc')
      or (resolved_at is null and created_at>now()-interval '24 hours')
      or (stolen_amount>0 and resolved_at>=date_trunc('day',now() at time zone 'utc') at time zone 'utc'))) then
    raise exception 'This player is protected: one incoming success per UTC day and no pending stack.';
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
$function$
;

revoke all on function public.attempt_aura_heist(uuid,uuid,integer) from public,anon;
grant execute on function public.attempt_aura_heist(uuid,uuid,integer) to authenticated;
CREATE OR REPLACE FUNCTION public.log_check_in(p_challenge_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  v_streak       integer;
  v_cursor       date;
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

  v_gain:=public.resolve_checkin_heist(p_challenge_id,v_user_id,v_gain,v_challenge.aura_gain);
  update public.challenge_participants set challenge_aura=challenge_aura+v_gain where id=v_participant.id;

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
$function$
;
CREATE OR REPLACE FUNCTION public.purchase_benefit(p_benefit_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id     uuid := (select auth.uid());
  v_benefit     public.benefits%rowtype;
  v_participant public.challenge_participants%rowtype;
  v_purchase_id uuid;
begin
  perform public.lock_game_state();
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

  if not exists(select 1 from public.challenges where id=v_benefit.challenge_id and aura_gain>0 and lifecycle='active'
    and starts_on<=(now() at time zone 'utc')::date and (is_endless or starts_on+duration_days>(now() at time zone 'utc')::date)) then
    raise exception 'The shop needs a running quest with a positive base reward.';
  end if;
  if v_benefit.title in ('Aura Heist','Targeted Roast','Blackout') then raise exception 'Choose a target through the attack dialog.'; end if;
  if v_benefit.title in ('Title Badge','Aura Lord') and exists(select 1 from public.benefit_purchases where benefit_id=p_benefit_id and user_id=v_user_id) then
    raise exception 'You already own this title.';
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
$function$
;
CREATE OR REPLACE FUNCTION public.send_targeted_roast(p_challenge_id uuid, p_target_id uuid, p_roast_text text, p_duration_seconds integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id     uuid := (select auth.uid());
  v_lifecycle   text;
  v_cost        integer;
  v_sender_aura integer;
begin
  perform public.lock_game_state();
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if v_user_id = p_target_id then
    raise exception 'You cannot roast yourself.';
  end if;
  if p_duration_seconds not in (3, 5) then
    raise exception 'Invalid duration - 3 or 5 seconds.';
  end if;
  if p_roast_text is null or length(trim(p_roast_text)) = 0
     or length(p_roast_text) > 300 then
    raise exception 'Invalid roast text.';
  end if;

  select lifecycle into v_lifecycle
  from public.challenges where id = p_challenge_id;
  if not found then
    raise exception 'Quest not found.';
  end if;
  if v_lifecycle <> 'active' then
    raise exception 'This quest is not running right now.';
  end if;

  perform public.check_attack_rules(p_challenge_id,p_target_id);
  v_cost:=public.balance_price((select aura_gain from public.challenges where id=p_challenge_id),'Targeted Roast',case p_duration_seconds when 3 then 1 else 2 end);

  if not exists (
    select 1 from public.challenge_participants
    where challenge_id = p_challenge_id
      and user_id = p_target_id
      and status = 'active'
  ) then
    raise exception 'Target is not an active member of this quest.';
  end if;

  select challenge_aura into v_sender_aura
  from public.challenge_participants
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and status = 'active'
  for update;
  if not found then
    raise exception 'You are not an active member of this quest.';
  end if;
  if v_sender_aura < v_cost then
    raise exception 'Not enough aura - this roast costs %.', v_cost;
  end if;

  update public.challenge_participants
  set challenge_aura = challenge_aura - v_cost
  where challenge_id = p_challenge_id and user_id = v_user_id;

  insert into public.targeted_roasts
    (challenge_id, sender_id, target_id, roast_text, duration_seconds)
  values
    (p_challenge_id, v_user_id, p_target_id, p_roast_text, p_duration_seconds);

  return v_sender_aura - v_cost;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.cast_blackout(p_challenge_id uuid, p_target_id uuid, p_daypart text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id     uuid := (select auth.uid());
  v_cost        integer;
  v_challenge   public.challenges%rowtype;
  v_offset      integer;
  v_hour        integer;
  v_local_now   timestamp;
  v_local_start timestamp;
  v_starts_at   timestamptz;
  v_ends_at     timestamptz;
  v_aura        integer;
  v_members     integer;
  v_target_name text;
  v_immediate   boolean := false;
begin
  perform public.lock_game_state();
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if v_user_id = p_target_id then
    raise exception 'You cannot black out yourself.';
  end if;
  if p_daypart not in ('morning', 'noon', 'evening') then
    raise exception 'Pick morning, noon or evening.';
  end if;

  select * into v_challenge
  from public.challenges where id = p_challenge_id;
  if not found then
    raise exception 'Quest not found.';
  end if;
  if v_challenge.lifecycle <> 'active' then
    raise exception 'This quest is not running right now.';
  end if;
  if v_challenge.goal_type = 'avoid' then
    raise exception 'A blackout has nothing to block on an avoid quest.';
  end if;

  perform public.check_attack_rules(p_challenge_id,p_target_id);
  v_cost:=public.balance_price(v_challenge.aura_gain,'Blackout');
  select count(*)::int into v_members
  from public.challenge_participants
  where challenge_id = p_challenge_id and status = 'active';
  if v_members < 2 then
    raise exception 'A blackout needs someone to aim at.';
  end if;

  if not exists (
    select 1 from public.challenge_participants
    where challenge_id = p_challenge_id
      and user_id = p_target_id
      and status = 'active'
  ) then
    raise exception 'Target is not an active member of this quest.';
  end if;

  if exists (
    select 1 from public.blackouts
    where challenge_id = p_challenge_id
      and target_id = p_target_id
      and ends_at > now()
  ) then
    raise exception 'They are already blacked out - wait your turn.';
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
  if v_aura < v_cost then
    raise exception 'Not enough aura - a blackout costs %.', v_cost;
  end if;

  -- Alles in der ORTSZEIT DES OPFERS.
  select coalesce(utc_offset_minutes, 0) into v_offset
  from public.profiles where id = p_target_id;

  v_hour := case p_daypart
              when 'morning' then 7
              when 'noon'    then 12
              else                20
            end;

  v_local_now   := (now() at time zone 'utc') + make_interval(mins => v_offset);
  v_local_start := date_trunc('day', v_local_now) + make_interval(hours => v_hour);

  if v_local_now >= v_local_start
     and v_local_now < v_local_start + interval '2 hours' then
    -- Mitten im gewaehlten Fenster: ab sofort.
    v_starts_at := now();
    v_immediate := true;
  else
    if v_local_start <= v_local_now then
      v_local_start := v_local_start + interval '1 day';
    end if;
    v_starts_at := (v_local_start - make_interval(mins => v_offset))
                     at time zone 'utc';
  end if;

  v_ends_at := v_starts_at + interval '2 hours';

  update public.challenge_participants
  set challenge_aura = challenge_aura - v_cost
  where challenge_id = p_challenge_id and user_id = v_user_id;

  insert into public.blackouts
    (challenge_id, attacker_id, target_id, daypart,
     starts_at, ends_at, cost)
  values
    (p_challenge_id, v_user_id, p_target_id, p_daypart,
     v_starts_at, v_ends_at, v_cost);

  select username into v_target_name
  from public.profiles where id = p_target_id;

  return jsonb_build_object(
    'target',     v_target_name,
    'daypart',    p_daypart,
    'starts_at',  v_starts_at,
    'ends_at',    v_ends_at,
    'immediate',  v_immediate,
    'cost',       v_cost,
    'balance',    v_aura - v_cost
  );
end;
$function$
;
drop function public.get_my_stats();
CREATE OR REPLACE FUNCTION public.get_my_stats()
 RETURNS TABLE(quests_joined integer, active_quests integer, total_checkins integer, total_aura integer, gear_owned integer, friends integer, lifetime_xp bigint)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
begin
  return query
  select
    (select count(*)::int from public.challenge_participants
      where user_id = v_user_id),
    (select count(*)::int from public.challenge_participants
      where user_id = v_user_id and status = 'active'),
    (select count(*)::int from public.check_ins
      where user_id = v_user_id),
    -- Aura lives per quest; the profile shows the sum as a "net worth".
    (select coalesce(sum(challenge_aura), 0)::int
      from public.challenge_participants where user_id = v_user_id),
    (select count(*)::int from public.benefit_purchases
      where user_id = v_user_id),
    (select count(*)::int from public.friendships
      where status = 'accepted'
        and (requester_id = v_user_id or addressee_id = v_user_id)),
    (select coalesce(sum(xp),0)::bigint from public.player_xp_events where user_id=v_user_id);
end;
$function$
;

revoke all on function public.get_my_stats() from public,anon;
grant execute on function public.get_my_stats() to authenticated;
notify pgrst, 'reload schema';
