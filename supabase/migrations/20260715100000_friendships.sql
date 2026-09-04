-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST - friendships
--
--  One row per friendship, storing WHO asked (requester) and WHO was
--  asked (addressee). Friendship itself is symmetric, so a unique
--  index on the unordered pair prevents A->B and B->A from coexisting.
--  Mutual requests auto-accept (nice UX: both asked = instant friends).
-- ═════════════════════════════════════════════════════════════════

create table public.friendships (
  id            uuid primary key default gen_random_uuid(),
  requester_id  uuid not null references public.profiles (id) on delete cascade,
  addressee_id  uuid not null references public.profiles (id) on delete cascade,
  status        text not null default 'pending'
                check (status in ('pending', 'accepted')),
  created_at    timestamptz not null default now(),
  check (requester_id <> addressee_id)
);

-- The unordered pair is unique: only ONE friendship row per couple,
-- no matter who asked first.
create unique index friendships_pair_idx on public.friendships (
  least(requester_id, addressee_id),
  greatest(requester_id, addressee_id)
);
create index friendships_addressee_idx
  on public.friendships (addressee_id, status);
create index friendships_requester_idx
  on public.friendships (requester_id, status);

alter table public.friendships enable row level security;
grant select on public.friendships to authenticated;

-- Both sides can read their own friendships; all writes via RPC.
create policy "friendships: both parties can read"
  on public.friendships for select
  to authenticated
  using ((select auth.uid()) in (requester_id, addressee_id));

-- ─────────────────────────────────────────────────────────────────
-- RPC: send_friend_request(username)
-- ─────────────────────────────────────────────────────────────────
create or replace function public.send_friend_request(p_username text)
returns text  -- 'pending' or 'accepted' (auto-accepted mutual request)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_target  uuid;
  v_row     public.friendships%rowtype;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select id into v_target
  from public.profiles
  where lower(username) = lower(trim(p_username));
  if not found then
    raise exception 'No player named "%" found.', trim(p_username);
  end if;
  if v_target = v_user_id then
    raise exception 'You cannot add yourself.';
  end if;

  select * into v_row
  from public.friendships
  where least(requester_id, addressee_id) = least(v_user_id, v_target)
    and greatest(requester_id, addressee_id) = greatest(v_user_id, v_target)
  for update;

  if found then
    if v_row.status = 'accepted' then
      raise exception 'You are already friends with %.', trim(p_username);
    end if;
    if v_row.requester_id = v_user_id then
      raise exception 'Request to % is already pending.', trim(p_username);
    end if;
    -- They asked us first -> asking back means yes.
    update public.friendships set status = 'accepted' where id = v_row.id;
    return 'accepted';
  end if;

  insert into public.friendships (requester_id, addressee_id)
  values (v_user_id, v_target);
  return 'pending';
end;
$$;

revoke execute on function public.send_friend_request(text) from public, anon;
grant execute on function public.send_friend_request(text) to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- RPC: respond_to_friend_request(id, accept)
--   Declining DELETES the row so they may ask again later.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.respond_to_friend_request(
  p_friendship_id uuid,
  p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_row public.friendships%rowtype;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_row
  from public.friendships
  where id = p_friendship_id
    and addressee_id = v_user_id
    and status = 'pending'
  for update;
  if not found then
    raise exception 'Friend request not found or already handled.';
  end if;

  if p_accept then
    update public.friendships set status = 'accepted' where id = v_row.id;
  else
    delete from public.friendships where id = v_row.id;
  end if;
end;
$$;

revoke execute on function public.respond_to_friend_request(uuid, boolean)
  from public, anon;
grant execute on function public.respond_to_friend_request(uuid, boolean)
  to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- RPC: remove_friend(user_id) - works from either side.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.remove_friend(p_user_id uuid)
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

  delete from public.friendships
  where least(requester_id, addressee_id) = least(v_user_id, p_user_id)
    and greatest(requester_id, addressee_id) = greatest(v_user_id, p_user_id);
end;
$$;

revoke execute on function public.remove_friend(uuid) from public, anon;
grant execute on function public.remove_friend(uuid) to authenticated;
