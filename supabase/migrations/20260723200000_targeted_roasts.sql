-- =================================================================
--  AURA QUEST - Targeted Roasts (PvP shop item)
--
--  Pay aura to hit a quest mate with a savage roast that locks their
--  screen for 3s (120 aura) or 5s (200 aura) before they can dismiss
--  it. The roast text is chosen client-side from the 300-roast pool.
--
--  Payment happens INSIDE send_targeted_roast (not purchase_benefit),
--  so there is no insert policy on the table - the RPC is the only
--  legit way in. The 'Targeted Roast' benefit row exists purely so the
--  item shows up in the quest shop.
-- =================================================================

create table if not exists public.targeted_roasts (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  target_id uuid not null references public.profiles(id) on delete cascade,
  roast_text text not null,
  duration_seconds integer not null check (duration_seconds in (3, 5)),
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz default null
);

create index if not exists targeted_roasts_target_idx
  on public.targeted_roasts (target_id) where acknowledged_at is null;

alter table public.targeted_roasts enable row level security;

-- RLS gates the rows; these grants open the table itself. No INSERT /
-- DELETE for clients - the RPC (security definer) is the only way in.
grant select, update on public.targeted_roasts to authenticated;

drop policy if exists "Targeted roasts viewable by challenge members" on public.targeted_roasts;
create policy "Targeted roasts viewable by challenge members"
  on public.targeted_roasts for select
  to authenticated
  using (
    exists (
      select 1 from public.challenge_participants cp
      where cp.challenge_id = targeted_roasts.challenge_id
        and cp.user_id = (select auth.uid())
    )
  );

-- No insert policy on purpose: roasts only enter via the RPC below.
drop policy if exists "Targeted roasts insertable by sender" on public.targeted_roasts;

drop policy if exists "Targeted roasts updatable by target" on public.targeted_roasts;
create policy "Targeted roasts updatable by target"
  on public.targeted_roasts for update
  to authenticated
  using (target_id = (select auth.uid()));

-- ── Buy & fire in one transaction ────────────────────────────────
create or replace function public.send_targeted_roast(
  p_challenge_id uuid,
  p_target_id uuid,
  p_roast_text text,
  p_duration_seconds integer
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id     uuid := (select auth.uid());
  v_lifecycle   text;
  v_cost        integer;
  v_sender_aura integer;
begin
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

  v_cost := case p_duration_seconds when 3 then 120 else 200 end;

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
$$;

revoke execute on function public.send_targeted_roast(uuid, uuid, text, integer) from public, anon;
grant  execute on function public.send_targeted_roast(uuid, uuid, text, integer) to authenticated;

-- ── Shop listing ─────────────────────────────────────────────────
-- One benefit row per quest so the item appears in the shop. Cost 120
-- is the base (3s) price; the send dialog shows both tiers.
insert into public.benefits (challenge_id, title, description, cost)
select c.id, 'Targeted Roast',
       'Roast a quest mate: locks their screen with a savage burn. 3s for 120, 5s for 200.',
       120
from public.challenges c
where not exists (
  select 1 from public.benefits b
  where b.challenge_id = c.id and b.title = 'Targeted Roast'
);

-- Future quests get it automatically, independent of create_challenge.
create or replace function public.seed_targeted_roast_benefit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.benefits (challenge_id, title, description, cost)
  values (new.id, 'Targeted Roast',
    'Roast a quest mate: locks their screen with a savage burn. 3s for 120, 5s for 200.',
    120);
  return new;
end;
$$;

drop trigger if exists trg_seed_targeted_roast on public.challenges;
create trigger trg_seed_targeted_roast
  after insert on public.challenges
  for each row execute function public.seed_targeted_roast_benefit();
