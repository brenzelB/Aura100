-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST - social phase: quest invites, nudges, shared visibility
--
--  * invites: ask a friend (by username) into a quest; they accept or
--    decline. Writes only via RPCs.
--  * nudges: poke a quest-mate who hasn't checked in - max once per
--    day per person per quest (enforced by a unique index).
--  * visibility: quest members may now see each other's check-ins and
--    shop purchases (was: own rows only).
-- ═════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- 1. INVITES
-- ─────────────────────────────────────────────────────────────────
create table public.invites (
  id            uuid primary key default gen_random_uuid(),
  challenge_id  uuid not null references public.challenges (id) on delete cascade,
  inviter_id    uuid not null references public.profiles (id) on delete cascade,
  invitee_id    uuid not null references public.profiles (id) on delete cascade,
  status        text not null default 'pending'
                check (status in ('pending', 'accepted', 'declined')),
  created_at    timestamptz not null default now(),
  unique (challenge_id, invitee_id)
);
create index invites_invitee_idx on public.invites (invitee_id, status);

alter table public.invites enable row level security;
grant select on public.invites to authenticated;

-- Both sides of an invite may read it; all writes go through RPCs.
create policy "invites: inviter and invitee can read"
  on public.invites for select
  to authenticated
  using ((select auth.uid()) in (inviter_id, invitee_id));

-- ─────────────────────────────────────────────────────────────────
-- 2. NUDGES (pokes)
-- ─────────────────────────────────────────────────────────────────
create table public.nudges (
  id            uuid primary key default gen_random_uuid(),
  challenge_id  uuid not null references public.challenges (id) on delete cascade,
  from_user     uuid not null references public.profiles (id) on delete cascade,
  to_user       uuid not null references public.profiles (id) on delete cascade,
  nudged_on     date not null default (now() at time zone 'utc')::date,
  created_at    timestamptz not null default now(),
  -- Anti-spam: one poke per person per quest per day.
  unique (challenge_id, from_user, to_user, nudged_on)
);
create index nudges_to_user_idx on public.nudges (to_user, created_at desc);

alter table public.nudges enable row level security;
grant select on public.nudges to authenticated;

create policy "nudges: sender and recipient can read"
  on public.nudges for select
  to authenticated
  using ((select auth.uid()) in (from_user, to_user));

-- ─────────────────────────────────────────────────────────────────
-- 3. SHARED VISIBILITY inside a quest
--    Members of the same quest see each other's check-ins and gear.
-- ─────────────────────────────────────────────────────────────────
drop policy "check_ins: users read their own" on public.check_ins;
create policy "check_ins: quest members read each other"
  on public.check_ins for select
  to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.challenge_participants me
      where me.challenge_id = check_ins.challenge_id
        and me.user_id = (select auth.uid())
    )
  );

drop policy "purchases: users read their own" on public.benefit_purchases;
create policy "purchases: quest members read each other"
  on public.benefit_purchases for select
  to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.challenge_participants me
      where me.challenge_id = benefit_purchases.challenge_id
        and me.user_id = (select auth.uid())
    )
  );

-- ─────────────────────────────────────────────────────────────────
-- 4. RPC: invite_to_challenge(challenge, username)
-- ─────────────────────────────────────────────────────────────────
create or replace function public.invite_to_challenge(
  p_challenge_id uuid,
  p_username text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_invitee uuid;
  v_existing public.invites%rowtype;
  v_invite_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  -- Only active quest members may invite.
  if not exists (
    select 1 from public.challenge_participants
    where challenge_id = p_challenge_id
      and user_id = v_user_id and status = 'active'
  ) then
    raise exception 'You are not an active participant of this quest.';
  end if;

  select id into v_invitee
  from public.profiles
  where lower(username) = lower(trim(p_username));
  if not found then
    raise exception 'No player named "%" found.', trim(p_username);
  end if;
  if v_invitee = v_user_id then
    raise exception 'You are already in this quest.';
  end if;
  if exists (
    select 1 from public.challenge_participants
    where challenge_id = p_challenge_id and user_id = v_invitee
  ) then
    raise exception '% is already part of this quest.', trim(p_username);
  end if;

  select * into v_existing
  from public.invites
  where challenge_id = p_challenge_id and invitee_id = v_invitee;

  if found then
    if v_existing.status = 'pending' then
      raise exception '% was already invited.', trim(p_username);
    end if;
    -- Declined earlier (or stale accepted after leaving) -> re-invite.
    update public.invites
    set status = 'pending', inviter_id = v_user_id, created_at = now()
    where id = v_existing.id;
    return v_existing.id;
  end if;

  insert into public.invites (challenge_id, inviter_id, invitee_id)
  values (p_challenge_id, v_user_id, v_invitee)
  returning id into v_invite_id;
  return v_invite_id;
end;
$$;

revoke execute on function public.invite_to_challenge(uuid, text) from public, anon;
grant execute on function public.invite_to_challenge(uuid, text) to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- 5. RPC: respond_to_invite(invite, accept?)
--    Accepting joins the quest in the same transaction.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.respond_to_invite(
  p_invite_id uuid,
  p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_invite public.invites%rowtype;
  v_challenge public.challenges%rowtype;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_invite
  from public.invites
  where id = p_invite_id and invitee_id = v_user_id and status = 'pending'
  for update;
  if not found then
    raise exception 'Invite not found or already handled.';
  end if;

  if not p_accept then
    update public.invites set status = 'declined' where id = v_invite.id;
    return;
  end if;

  select * into v_challenge
  from public.challenges where id = v_invite.challenge_id;
  if (now() at time zone 'utc')::date
       >= v_challenge.starts_on + v_challenge.duration_days then
    raise exception 'This quest has already ended.';
  end if;

  insert into public.challenge_participants (challenge_id, user_id)
  values (v_invite.challenge_id, v_user_id)
  on conflict (challenge_id, user_id) do nothing;

  update public.invites set status = 'accepted' where id = v_invite.id;
end;
$$;

revoke execute on function public.respond_to_invite(uuid, boolean) from public, anon;
grant execute on function public.respond_to_invite(uuid, boolean) to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- 6. RPC: nudge_participant(challenge, user)
-- ─────────────────────────────────────────────────────────────────
create or replace function public.nudge_participant(
  p_challenge_id uuid,
  p_to_user uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if p_to_user = v_user_id then
    raise exception 'Nudging yourself will not help.';
  end if;
  -- Both must be active members of the quest.
  if not exists (
    select 1 from public.challenge_participants
    where challenge_id = p_challenge_id
      and user_id = v_user_id and status = 'active'
  ) or not exists (
    select 1 from public.challenge_participants
    where challenge_id = p_challenge_id
      and user_id = p_to_user and status = 'active'
  ) then
    raise exception 'Both players must be active members of this quest.';
  end if;

  begin
    insert into public.nudges (challenge_id, from_user, to_user)
    values (p_challenge_id, v_user_id, p_to_user);
  exception when unique_violation then
    raise exception 'Already nudged today - give them a break!';
  end;
end;
$$;

revoke execute on function public.nudge_participant(uuid, uuid) from public, anon;
grant execute on function public.nudge_participant(uuid, uuid) to authenticated;
