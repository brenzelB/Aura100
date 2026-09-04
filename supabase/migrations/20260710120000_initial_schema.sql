-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST — Phase 3: foundational schema
--  Tables: profiles, challenges, challenge_participants
--
--  Runs identically as a local CLI migration and pasted into the
--  hosted project's SQL Editor (Dashboard → SQL Editor → New query).
-- ═════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────
-- 1. PROFILES — public player data, 1:1 with auth.users
-- ─────────────────────────────────────────────────────────────────
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  username    text not null unique
              check (char_length(username) between 3 and 24),
  total_aura  integer not null default 4800,
  created_at  timestamptz not null default now()
);

comment on table public.profiles is
  'Public-facing player data. Created automatically by trigger on signup.';

-- Auto-create a profile whenever a user signs up.
-- Uses the username passed in auth metadata (signUp(data: {username: ...}));
-- falls back to the email local-part. SECURITY DEFINER because the
-- signing-up user has no INSERT rights on profiles (see grants below).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  base_name text;
begin
  base_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'username'), ''),
    split_part(new.email, '@', 1)
  );
  -- Keep within the 3–24 char check constraint no matter the input.
  base_name := left(base_name, 20);
  if char_length(base_name) < 3 then
    base_name := base_name || left(replace(new.id::text, '-', ''), 4);
  end if;

  begin
    insert into public.profiles (id, username) values (new.id, base_name);
  exception when unique_violation then
    -- Username taken → append a short chunk of the user id.
    insert into public.profiles (id, username)
    values (new.id, base_name || '_' || left(replace(new.id::text, '-', ''), 4));
  end;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ─────────────────────────────────────────────────────────────────
-- 2. CHALLENGES — habit challenges created by players
-- ─────────────────────────────────────────────────────────────────
create table public.challenges (
  id            uuid primary key default gen_random_uuid(),
  creator_id    uuid not null references public.profiles (id) on delete cascade,
  title         text not null check (char_length(title) between 1 and 80),
  difficulty    text not null default 'normal'
                check (difficulty in ('easy', 'normal', 'hard', 'legendary')),
  aura_gain     integer not null default 100 check (aura_gain >= 0),
  aura_penalty  integer not null default 50  check (aura_penalty >= 0),
  created_at    timestamptz not null default now()
);

create index challenges_creator_id_idx on public.challenges (creator_id);


-- ─────────────────────────────────────────────────────────────────
-- 3. CHALLENGE_PARTICIPANTS — who is in which challenge
-- ─────────────────────────────────────────────────────────────────
create table public.challenge_participants (
  id            uuid primary key default gen_random_uuid(),
  challenge_id  uuid not null references public.challenges (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  -- 'completed' included now so finishing a challenge (Phase 4) needs no migration
  status        text not null default 'active'
                check (status in ('active', 'failed', 'completed')),
  created_at    timestamptz not null default now(),
  unique (challenge_id, user_id)  -- can't join the same challenge twice
);

create index challenge_participants_user_id_idx
  on public.challenge_participants (user_id);


-- ─────────────────────────────────────────────────────────────────
-- 4. API GRANTS
--    New tables are NOT auto-exposed to the Data API roles (see
--    config.toml [api] note / new cloud default), so grants are
--    explicit. Column-level grants keep sensitive columns
--    (total_aura!) out of reach even before RLS is evaluated.
-- ─────────────────────────────────────────────────────────────────
-- profiles: read all; clients may only ever change their username.
-- total_aura is deliberately NOT client-writable — aura changes will
-- go through a server-side RPC in a later phase.
grant select            on public.profiles to authenticated;
grant update (username) on public.profiles to authenticated;

-- challenges: full lifecycle for signed-in users (row access via RLS).
grant select, insert, update, delete on public.challenges to authenticated;

-- participants: join (insert) and update your status; no delete for
-- now — leaving/kicking will be designed in the social phase.
grant select, insert          on public.challenge_participants to authenticated;
grant update (status)         on public.challenge_participants to authenticated;


-- ─────────────────────────────────────────────────────────────────
-- 5. ROW LEVEL SECURITY
--    (select auth.uid()) instead of bare auth.uid() lets Postgres
--    cache the value per statement — the documented perf pattern.
-- ─────────────────────────────────────────────────────────────────
alter table public.profiles               enable row level security;
alter table public.challenges             enable row level security;
alter table public.challenge_participants enable row level security;

-- ── profiles ──
-- Any signed-in user can see all profiles (friends lists, leaderboards).
create policy "profiles: signed-in users can read"
  on public.profiles for select
  to authenticated
  using (true);

-- Users can update only their own row (and only username, per grants).
create policy "profiles: owner can update"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- No INSERT policy: rows come from the SECURITY DEFINER trigger.
-- No DELETE policy: deletion cascades from auth.users.

-- ── challenges ──
create policy "challenges: signed-in users can read"
  on public.challenges for select
  to authenticated
  using (true);

create policy "challenges: creator can insert"
  on public.challenges for insert
  to authenticated
  with check ((select auth.uid()) = creator_id);

create policy "challenges: creator can update"
  on public.challenges for update
  to authenticated
  using ((select auth.uid()) = creator_id)
  with check ((select auth.uid()) = creator_id);

create policy "challenges: creator can delete"
  on public.challenges for delete
  to authenticated
  using ((select auth.uid()) = creator_id);

-- ── challenge_participants ──
create policy "participants: signed-in users can read"
  on public.challenge_participants for select
  to authenticated
  using (true);

-- You can only add YOURSELF to a challenge.
create policy "participants: user can join"
  on public.challenge_participants for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

-- You can only update your own participation (e.g. status).
create policy "participants: user can update own row"
  on public.challenge_participants for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
