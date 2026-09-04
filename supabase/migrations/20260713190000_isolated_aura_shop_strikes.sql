-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST - Phase 5: isolated per-challenge aura, quest shop,
--  strikes (allowed misses) and flexible schedules.
--
--  BREAKING: profiles.total_aura is REMOVED. Aura now lives on
--  challenge_participants.challenge_aura, earned and spent strictly
--  within one challenge.
-- ═════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- 1. PER-CHALLENGE AURA
-- ─────────────────────────────────────────────────────────────────
alter table public.challenge_participants
  add column challenge_aura integer not null default 0
  check (challenge_aura >= 0);

-- Backfill from existing check-ins (count × the challenge's gain).
update public.challenge_participants cp
set challenge_aura = sub.earned
from (
  select ci.challenge_id, ci.user_id,
         count(*)::int * max(c.aura_gain) as earned
  from public.check_ins ci
  join public.challenges c on c.id = ci.challenge_id
  group by ci.challenge_id, ci.user_id
) sub
where sub.challenge_id = cp.challenge_id
  and sub.user_id = cp.user_id;

-- Global aura is gone for good.
alter table public.profiles drop column total_aura;

-- ─────────────────────────────────────────────────────────────────
-- 2. STRIKES + FLEXIBLE SCHEDULE on challenges
-- ─────────────────────────────────────────────────────────────────
alter table public.challenges
  add column max_strikes integer not null default 1
    check (max_strikes between 0 and 10),
  add column starts_on date not null default (now() at time zone 'utc')::date;

-- Existing challenges started the day they were created.
update public.challenges
set starts_on = (created_at at time zone 'utc')::date;

-- ─────────────────────────────────────────────────────────────────
-- 3. QUEST SHOP - benefits are scoped to ONE challenge
-- ─────────────────────────────────────────────────────────────────
create table public.benefits (
  id            uuid primary key default gen_random_uuid(),
  challenge_id  uuid not null references public.challenges (id) on delete cascade,
  title         text not null,
  description   text not null default '',
  cost          integer not null check (cost > 0),
  created_at    timestamptz not null default now()
);
create index benefits_challenge_id_idx on public.benefits (challenge_id);

create table public.benefit_purchases (
  id            uuid primary key default gen_random_uuid(),
  benefit_id    uuid not null references public.benefits (id) on delete cascade,
  -- challenge + user denormalized: purchases stay tied to the quest
  -- entry and make RLS trivial.
  challenge_id  uuid not null references public.challenges (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  created_at    timestamptz not null default now()
);
create index benefit_purchases_user_idx
  on public.benefit_purchases (user_id, challenge_id);

alter table public.benefits          enable row level security;
alter table public.benefit_purchases enable row level security;

-- Benefits are readable by all signed-in users; written only by the
-- create_challenge function (no client insert grants).
grant select on public.benefits to authenticated;
create policy "benefits: signed-in users can read"
  on public.benefits for select to authenticated using (true);

-- Purchases: users see their own; the ONLY write path is purchase_benefit.
grant select on public.benefit_purchases to authenticated;
create policy "purchases: users read their own"
  on public.benefit_purchases for select to authenticated
  using ((select auth.uid()) = user_id);

-- ─────────────────────────────────────────────────────────────────
-- 4. CREATE_CHALLENGE v2 - strikes, start date, default shop stock
--    (signature changes → drop + recreate)
-- ─────────────────────────────────────────────────────────────────
drop function public.create_challenge(text, integer, integer, integer);

-- Now SECURITY DEFINER (was INVOKER): the function seeds this quest's
-- shop, and clients deliberately have no INSERT grant on benefits.
-- Same discipline as log_check_in: acting user comes ONLY from
-- auth.uid(), all inputs validated, search_path pinned, EXECUTE
-- restricted to authenticated.
create or replace function public.create_challenge(
  p_title text,
  p_duration_days integer,
  p_aura_gain integer,
  p_aura_penalty integer,
  p_max_strikes integer default 1,
  p_starts_on date default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_challenge_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if p_title is null or length(trim(p_title)) between 1 and 80 is not true then
    raise exception 'Title must be 1-80 characters.';
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

  insert into public.challenges
    (creator_id, title, duration_days, aura_gain, aura_penalty,
     max_strikes, starts_on)
  values
    (v_user_id, trim(p_title), p_duration_days, p_aura_gain,
     p_aura_penalty, p_max_strikes,
     coalesce(p_starts_on, (now() at time zone 'utc')::date))
  returning id into v_challenge_id;

  insert into public.challenge_participants (challenge_id, user_id)
  values (v_challenge_id, v_user_id);

  insert into public.benefits (challenge_id, title, description, cost) values
    (v_challenge_id, 'Title Badge',
     'A golden badge on this quest - pure flex.', 50),
    (v_challenge_id, 'Half Damage',
     'Your next missed day costs only half the penalty.', 150),
    (v_challenge_id, 'Streak Shield',
     'One missed day is forgiven - no strike.', 300);

  return v_challenge_id;
end;
$$;

revoke execute on function
  public.create_challenge(text, integer, integer, integer, integer, date)
  from public, anon;
grant execute on function
  public.create_challenge(text, integer, integer, integer, integer, date)
  to authenticated;

-- Stock the shops of the challenges that already exist.
insert into public.benefits (challenge_id, title, description, cost)
select c.id, b.title, b.description, b.cost
from public.challenges c
cross join (values
  ('Title Badge',   'A golden badge on this quest - pure flex.', 50),
  ('Half Damage',   'Your next missed day costs only half the penalty.', 150),
  ('Streak Shield', 'One missed day is forgiven - no strike.', 300)
) as b(title, description, cost);

-- ─────────────────────────────────────────────────────────────────
-- 5. LOG_CHECK_IN v2 - window + strikes enforcement, pays into
--    challenge_aura instead of the removed profiles.total_aura.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.log_check_in(p_challenge_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id     uuid := (select auth.uid());
  v_challenge   public.challenges%rowtype;
  v_participant public.challenge_participants%rowtype;
  v_today       date := (now() at time zone 'utc')::date;
  v_active_from date;
  v_expected    integer;
  v_done        integer;
  v_missed      integer;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_challenge
  from public.challenges where id = p_challenge_id;
  if not found then
    raise exception 'Quest not found.';
  end if;

  -- Flexible schedule window.
  if v_today < v_challenge.starts_on then
    raise exception 'This quest has not started yet.';
  end if;
  if v_today >= v_challenge.starts_on + v_challenge.duration_days then
    raise exception 'This quest has already ended.';
  end if;

  -- Lock the participant row: aura math must be race-free.
  select * into v_participant
  from public.challenge_participants
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and status = 'active'
  for update;
  if not found then
    raise exception 'You are not an active participant of this quest.';
  end if;

  -- STRIKES: every day since you became active (join date or quest
  -- start, whichever is later) up to YESTERDAY needed a check-in.
  v_active_from := greatest(
    v_challenge.starts_on,
    (v_participant.created_at at time zone 'utc')::date
  );
  v_expected := greatest(v_today - v_active_from, 0);

  select count(*)::int into v_done
  from public.check_ins
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and checked_on >= v_active_from
    and checked_on < v_today;

  v_missed := v_expected - v_done;
  if v_missed > v_challenge.max_strikes then
    update public.challenge_participants
    set status = 'failed'
    where id = v_participant.id;
    raise exception
      'Quest failed - % missed day(s), only % strike(s) allowed.',
      v_missed, v_challenge.max_strikes;
  end if;

  begin
    insert into public.check_ins (challenge_id, user_id)
    values (p_challenge_id, v_user_id);
  exception when unique_violation then
    raise exception 'Already checked in today - come back tomorrow!';
  end;

  update public.challenge_participants
  set challenge_aura = challenge_aura + v_challenge.aura_gain
  where id = v_participant.id;

  return v_challenge.aura_gain;
end;
$$;

-- ─────────────────────────────────────────────────────────────────
-- 6. PURCHASE_BENEFIT - spend quest aura on a quest benefit.
--    SECURITY DEFINER for the same reason as log_check_in: clients
--    cannot write challenge_aura or benefit_purchases directly.
-- ─────────────────────────────────────────────────────────────────
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
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_benefit
  from public.benefits where id = p_benefit_id;
  if not found then
    raise exception 'Benefit not found.';
  end if;

  -- Lock the participant row for the balance check + deduction.
  select * into v_participant
  from public.challenge_participants
  where challenge_id = v_benefit.challenge_id
    and user_id = v_user_id
    and status = 'active'
  for update;
  if not found then
    raise exception 'You are not an active participant of this quest.';
  end if;

  if v_participant.challenge_aura < v_benefit.cost then
    raise exception 'Not enough aura in this quest (% needed, % available).',
      v_benefit.cost, v_participant.challenge_aura;
  end if;

  update public.challenge_participants
  set challenge_aura = challenge_aura - v_benefit.cost
  where id = v_participant.id;

  insert into public.benefit_purchases (benefit_id, challenge_id, user_id)
  values (v_benefit.id, v_benefit.challenge_id, v_user_id);

  return v_participant.challenge_aura - v_benefit.cost;
end;
$$;

revoke execute on function public.log_check_in(uuid) from public, anon;
grant  execute on function public.log_check_in(uuid) to authenticated;
revoke execute on function public.purchase_benefit(uuid) from public, anon;
grant  execute on function public.purchase_benefit(uuid) to authenticated;
