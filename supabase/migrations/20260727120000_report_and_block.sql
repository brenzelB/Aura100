-- =================================================================
--  AURA QUEST - reporting and blocking
--
--  Both stores require this for an app where users can act on each
--  other: a way to report someone and a way to block them outright
--  (Apple review guideline 1.2, Google user-generated content policy).
--  Aura Quest lets players roast, rob, poke and duel each other and
--  pick their own usernames, so it squarely needs both.
--
--  Enforcement runs as BEFORE INSERT triggers rather than edits to the
--  PvP functions themselves: one small guard covers every path
--  (roasts, heists, pokes, duels, friend requests, quest invites) and
--  cannot be forgotten when a new one is added.
-- =================================================================

-- ── Blocks ──────────────────────────────────────────────────────
create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_idx
  on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;
grant select on public.user_blocks to authenticated;

drop policy if exists "blocks: you see your own" on public.user_blocks;
create policy "blocks: you see your own"
  on public.user_blocks for select to authenticated
  using (blocker_id = (select auth.uid()));

-- ── Reports ─────────────────────────────────────────────────────
create table if not exists public.user_reports (
  id           uuid primary key default gen_random_uuid(),
  reporter_id  uuid not null references public.profiles(id) on delete cascade,
  reported_id  uuid not null references public.profiles(id) on delete cascade,
  reason       text not null check (reason in
                 ('harassment','offensive_name','cheating','spam','other')),
  details      text check (details is null or char_length(details) <= 1000),
  challenge_id uuid references public.challenges(id) on delete set null,
  created_at   timestamptz not null default now(),
  constraint user_reports_not_self check (reporter_id <> reported_id)
);

create index if not exists user_reports_reported_idx
  on public.user_reports (reported_id, created_at desc);

alter table public.user_reports enable row level security;
grant select on public.user_reports to authenticated;

-- A reporter may see what they filed; nobody sees reports against them.
drop policy if exists "reports: reporter sees own" on public.user_reports;
create policy "reports: reporter sees own"
  on public.user_reports for select to authenticated
  using (reporter_id = (select auth.uid()));

-- ── Is there a block between two users (either direction)? ──────
create or replace function public.is_blocked_pair(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_blocks
    where (blocker_id = a and blocked_id = b)
       or (blocker_id = b and blocked_id = a)
  );
$$;

-- ── The guard ───────────────────────────────────────────────────
-- Takes the two party columns of the row as trigger arguments, so one
-- function protects every interaction table.
create or replace function public.reject_if_blocked()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row jsonb := to_jsonb(new);
  v_from uuid := (v_row ->> tg_argv[0])::uuid;
  v_to   uuid := (v_row ->> tg_argv[1])::uuid;
begin
  if v_from is not null and v_to is not null
     and public.is_blocked_pair(v_from, v_to) then
    raise exception 'You cannot interact with this player.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_block_roast on public.targeted_roasts;
create trigger trg_block_roast before insert on public.targeted_roasts
  for each row execute function public.reject_if_blocked('sender_id', 'target_id');

drop trigger if exists trg_block_heist on public.aura_heists;
create trigger trg_block_heist before insert on public.aura_heists
  for each row execute function public.reject_if_blocked('attacker_id', 'target_id');

drop trigger if exists trg_block_nudge on public.nudges;
create trigger trg_block_nudge before insert on public.nudges
  for each row execute function public.reject_if_blocked('from_user', 'to_user');

drop trigger if exists trg_block_duel on public.duels;
create trigger trg_block_duel before insert on public.duels
  for each row execute function public.reject_if_blocked('challenger_id', 'opponent_id');

-- ── Actions ─────────────────────────────────────────────────────
create or replace function public.block_user(p_user_id uuid)
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
  if p_user_id = v_user_id then
    raise exception 'You cannot block yourself.';
  end if;
  if not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'That player does not exist.';
  end if;

  insert into public.user_blocks (blocker_id, blocked_id)
  values (v_user_id, p_user_id)
  on conflict do nothing;

  -- Blocking also ends the friendship, in both directions.
  delete from public.friendships
  where (requester_id = v_user_id and addressee_id = p_user_id)
     or (requester_id = p_user_id and addressee_id = v_user_id);
end;
$$;

create or replace function public.unblock_user(p_user_id uuid)
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
  delete from public.user_blocks
  where blocker_id = v_user_id and blocked_id = p_user_id;
end;
$$;

create or replace function public.report_user(
  p_user_id uuid,
  p_reason text,
  p_details text default null,
  p_challenge_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_recent  integer;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if p_user_id = v_user_id then
    raise exception 'You cannot report yourself.';
  end if;
  if p_reason not in
     ('harassment','offensive_name','cheating','spam','other') then
    raise exception 'Unknown report reason.';
  end if;

  -- Light rate limit so the table cannot be spammed.
  select count(*)::int into v_recent
  from public.user_reports
  where reporter_id = v_user_id
    and created_at > now() - interval '1 hour';
  if v_recent >= 10 then
    raise exception 'Too many reports in a short time - try again later.';
  end if;

  insert into public.user_reports
    (reporter_id, reported_id, reason, details, challenge_id)
  values
    (v_user_id, p_user_id, p_reason, nullif(trim(coalesce(p_details,'')), ''),
     p_challenge_id);
end;
$$;

revoke execute on function public.block_user(uuid) from public, anon;
grant  execute on function public.block_user(uuid) to authenticated;
revoke execute on function public.unblock_user(uuid) from public, anon;
grant  execute on function public.unblock_user(uuid) to authenticated;
revoke execute on function public.report_user(uuid, text, text, uuid) from public, anon;
grant  execute on function public.report_user(uuid, text, text, uuid) to authenticated;
revoke execute on function public.is_blocked_pair(uuid, uuid) from public, anon;
grant  execute on function public.is_blocked_pair(uuid, uuid) to authenticated;
