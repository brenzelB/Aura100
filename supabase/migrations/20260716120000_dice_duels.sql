-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST - dice duels
--
--  Challenge a quest-mate: both stake quest aura, the SERVER rolls
--  2d6 vs 2d6, winner takes the pot. Zero-sum - aura moves between
--  players, none is created or destroyed.
--
--  * Escrow: the challenger's stake is locked at creation; the
--    opponent's at acceptance. Decline/expiry refunds.
--  * Fair: dice are rolled server-side at acceptance; the client
--    only ever animates a result that is already decided.
--  * Guardrails: stake 10+, at most 25% of the challenger's aura,
--    one open duel per pair per quest, 48h expiry (cron refunds).
-- ═════════════════════════════════════════════════════════════════

create table public.duels (
  id             uuid primary key default gen_random_uuid(),
  challenge_id   uuid not null references public.challenges (id) on delete cascade,
  challenger_id  uuid not null references public.profiles (id) on delete cascade,
  opponent_id    uuid not null references public.profiles (id) on delete cascade,
  stake          integer not null check (stake >= 10),
  status         text not null default 'pending'
                 check (status in ('pending', 'resolved', 'declined', 'expired')),
  challenger_d1  integer,
  challenger_d2  integer,
  opponent_d1    integer,
  opponent_d2    integer,
  winner_id      uuid references public.profiles (id),
  created_at     timestamptz not null default now(),
  expires_at     timestamptz not null default now() + interval '48 hours',
  resolved_at    timestamptz,
  check (challenger_id <> opponent_id)
);

-- One open duel per pair per quest, regardless of who challenged.
create unique index duels_open_pair_idx on public.duels (
  challenge_id,
  least(challenger_id, opponent_id),
  greatest(challenger_id, opponent_id)
) where status = 'pending';
create index duels_opponent_idx
  on public.duels (opponent_id, status);

alter table public.duels enable row level security;
grant select on public.duels to authenticated;
create policy "duels: both parties can read"
  on public.duels for select
  to authenticated
  using ((select auth.uid()) in (challenger_id, opponent_id));

-- The engine's event feed learns two new kinds.
alter table public.settlement_events
  drop constraint settlement_events_kind_check;
alter table public.settlement_events
  add constraint settlement_events_kind_check check (kind in
    ('penalty', 'strike', 'shield_saved', 'half_damage',
     'failed', 'completed', 'bonus', 'duel_won', 'duel_lost'));

-- ─────────────────────────────────────────────────────────────────
-- RPC: create_duel - challenge someone, stake goes into escrow.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.create_duel(
  p_challenge_id uuid,
  p_opponent_id uuid,
  p_stake integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_me public.challenge_participants%rowtype;
  v_duel_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if p_opponent_id = v_user_id then
    raise exception 'You cannot duel yourself.';
  end if;

  select * into v_me
  from public.challenge_participants
  where challenge_id = p_challenge_id
    and user_id = v_user_id and status = 'active'
  for update;
  if not found then
    raise exception 'You are not an active participant of this quest.';
  end if;
  if not exists (
    select 1 from public.challenge_participants
    where challenge_id = p_challenge_id
      and user_id = p_opponent_id and status = 'active'
  ) then
    raise exception 'Your opponent is not an active member of this quest.';
  end if;

  if p_stake < 10 then
    raise exception 'Minimum stake is 10 aura.';
  end if;
  -- At most a quarter of your quest aura - nobody goes broke on dice.
  if p_stake * 4 > v_me.challenge_aura then
    raise exception 'You can stake at most 25%% of your quest aura (max %).',
      v_me.challenge_aura / 4;
  end if;

  -- Escrow the challenger's stake.
  update public.challenge_participants
  set challenge_aura = challenge_aura - p_stake
  where id = v_me.id;

  begin
    insert into public.duels (challenge_id, challenger_id, opponent_id, stake)
    values (p_challenge_id, v_user_id, p_opponent_id, p_stake)
    returning id into v_duel_id;
  exception when unique_violation then
    raise exception 'There is already an open duel between you two here.';
  end;

  return v_duel_id;
end;
$$;

revoke execute on function public.create_duel(uuid, uuid, integer)
  from public, anon;
grant execute on function public.create_duel(uuid, uuid, integer)
  to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- RPC: respond_to_duel - decline refunds; accepting locks the
-- opponent's stake, rolls both dice pairs and pays the winner.
-- Returns the full result for the client-side animation.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.respond_to_duel(
  p_duel_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_duel public.duels%rowtype;
  v_me public.challenge_participants%rowtype;
  v_c1 int; v_c2 int; v_o1 int; v_o2 int;
  v_winner uuid;
  v_pot int;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_duel
  from public.duels
  where id = p_duel_id and opponent_id = v_user_id and status = 'pending'
  for update;
  if not found then
    raise exception 'Duel not found or already settled.';
  end if;

  if now() > v_duel.expires_at then
    update public.duels set status = 'expired' where id = v_duel.id;
    update public.challenge_participants
    set challenge_aura = challenge_aura + v_duel.stake
    where challenge_id = v_duel.challenge_id
      and user_id = v_duel.challenger_id;
    raise exception 'This duel has expired.';
  end if;

  if not p_accept then
    update public.duels set status = 'declined', resolved_at = now()
    where id = v_duel.id;
    -- Give the challenger their escrowed stake back.
    update public.challenge_participants
    set challenge_aura = challenge_aura + v_duel.stake
    where challenge_id = v_duel.challenge_id
      and user_id = v_duel.challenger_id;
    return jsonb_build_object('status', 'declined');
  end if;

  select * into v_me
  from public.challenge_participants
  where challenge_id = v_duel.challenge_id
    and user_id = v_user_id and status = 'active'
  for update;
  if not found then
    raise exception 'You are no longer an active member of this quest.';
  end if;
  if v_me.challenge_aura < v_duel.stake then
    raise exception 'You need % aura to accept this duel.', v_duel.stake;
  end if;

  -- Opponent's stake into the pot.
  update public.challenge_participants
  set challenge_aura = challenge_aura - v_duel.stake
  where id = v_me.id;

  -- Roll until there is a winner (server-side randomness).
  loop
    v_c1 := floor(random() * 6 + 1)::int;
    v_c2 := floor(random() * 6 + 1)::int;
    v_o1 := floor(random() * 6 + 1)::int;
    v_o2 := floor(random() * 6 + 1)::int;
    exit when v_c1 + v_c2 <> v_o1 + v_o2;
  end loop;

  v_winner := case when v_c1 + v_c2 > v_o1 + v_o2
                   then v_duel.challenger_id else v_duel.opponent_id end;
  v_pot := v_duel.stake * 2;

  update public.challenge_participants
  set challenge_aura = challenge_aura + v_pot
  where challenge_id = v_duel.challenge_id and user_id = v_winner;

  update public.duels
  set status = 'resolved', resolved_at = now(), winner_id = v_winner,
      challenger_d1 = v_c1, challenger_d2 = v_c2,
      opponent_d1 = v_o1, opponent_d2 = v_o2
  where id = v_duel.id;

  -- Feed events for both players (LATEST list now, FCM later).
  insert into public.settlement_events
    (user_id, challenge_id, kind, amount)
  values
    (v_winner, v_duel.challenge_id, 'duel_won', v_duel.stake),
    (case when v_winner = v_duel.challenger_id
          then v_duel.opponent_id else v_duel.challenger_id end,
     v_duel.challenge_id, 'duel_lost', -v_duel.stake);

  return jsonb_build_object(
    'status', 'resolved',
    'challenger_dice', jsonb_build_array(v_c1, v_c2),
    'opponent_dice', jsonb_build_array(v_o1, v_o2),
    'winner_id', v_winner,
    'pot', v_pot
  );
end;
$$;

revoke execute on function public.respond_to_duel(uuid, boolean)
  from public, anon;
grant execute on function public.respond_to_duel(uuid, boolean)
  to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- Expiry: refund challengers of duels nobody answered. Hourly.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.expire_duels()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_duel record;
begin
  for v_duel in
    select id, challenge_id, challenger_id, stake
    from public.duels
    where status = 'pending' and expires_at < now()
    for update
  loop
    update public.duels set status = 'expired', resolved_at = now()
    where id = v_duel.id;
    update public.challenge_participants
    set challenge_aura = challenge_aura + v_duel.stake
    where challenge_id = v_duel.challenge_id
      and user_id = v_duel.challenger_id;
  end loop;
end;
$$;

revoke execute on function public.expire_duels()
  from public, anon, authenticated;

do $$
begin
  perform cron.unschedule('duel-expiry');
exception when others then
  null;
end $$;

select cron.schedule(
  'duel-expiry',
  '10 * * * *',
  $$select public.expire_duels()$$
);
