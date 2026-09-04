-- =================================================================
--  AURA QUEST - Security Hardening & Integrity Fixes
--
--  1. RLS-Abdichtung: challenge_participants & challenges
--     Entzieht ungefilterte INSERT/UPDATE/DELETE-Rechte fuer Clients,
--     sodass Punkte (challenge_aura), Strikes und Status nicht mehr
--     per REST-API manipuliert werden koennen.
--  2. Column-Level Grants: Acknowledged-At fuer Angriffe
--     Beschraenkt das UPDATE-Recht bei blackouts, aura_heists und
--     targeted_roasts auf die Spalte acknowledged_at, damit Opfer
--     weder Zeiten noch Texte noch Ergebniswerte manipulieren koennen.
--  3. Foreign Key: duels.winner_id
--     Erhaelt ON DELETE SET NULL, damit Account-Loeschungen nicht
--     an einem Fremdschluesselfehler scheitern.
--  4. SSRF-Schutz: register_device
--     UnifiedPush-Tokens muessen valide HTTPS-URLs sein und duerfen
--     keine privaten Netzbereiche (RFC 1918 / Localhost) adressieren.
--  5. Blockier-Schutz: Freundschaften & Quest-Einladungen
--     send_friend_request und invite_to_challenge pruefen is_blocked_pair;
--     zusaetzliche Trigger sichern die Tabellen ab.
-- =================================================================

-- ── 1. RLS & Rechte: challenge_participants & challenges ─────────

-- Schreibzugriffe auf challenge_participants duerfen ausschliesslich
-- ueber die serverseitigen RPCs erfolgen.
revoke insert, update, delete on public.challenge_participants from public, anon, authenticated;
drop policy if exists "participants: user can join" on public.challenge_participants;
drop policy if exists "participants: user can update own row" on public.challenge_participants;

-- Schreibzugriffe auf challenges ebenfalls nur ueber gepruefte RPCs.
revoke insert, update, delete on public.challenges from public, anon, authenticated;
drop policy if exists "challenges: creator can insert" on public.challenges;
drop policy if exists "challenges: creator can update" on public.challenges;
drop policy if exists "challenges: creator can delete" on public.challenges;


-- ── 2. Column-Level Grants fuer Acknowledged-At ────────────────────

-- blackouts: Das Ziel darf ausschliesslich acknowledged_at setzen.
revoke update on public.blackouts from public, anon, authenticated;
grant update (acknowledged_at) on public.blackouts to authenticated;

-- aura_heists: Das Ziel darf ausschliesslich acknowledged_at setzen.
revoke update on public.aura_heists from public, anon, authenticated;
grant update (acknowledged_at) on public.aura_heists to authenticated;

-- targeted_roasts: Das Ziel darf ausschliesslich acknowledged_at setzen.
revoke update on public.targeted_roasts from public, anon, authenticated;
grant update (acknowledged_at) on public.targeted_roasts to authenticated;


-- ── 3. Foreign Key: duels.winner_id auf SET NULL ─────────────────

alter table public.duels
  drop constraint if exists duels_winner_id_fkey;

alter table public.duels
  add constraint duels_winner_id_fkey
  foreign key (winner_id) references public.profiles (id)
  on delete set null;


-- ── 4. SSRF-Schutz in register_device ────────────────────────────

create or replace function public.register_device(
  p_provider text,
  p_platform text,
  p_token    text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_clean_token text;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if p_token is null or length(trim(p_token)) = 0 then
    raise exception 'Empty token.';
  end if;

  v_clean_token := trim(p_token);

  -- SSRF-Schutz fuer UnifiedPush: Die Datenbank schickt HTTP-Requests
  -- an diesen Endpunkt. Daher duerfen weder lokale Adressen noch
  -- unsichere Protokolle eingetragen werden.
  if p_provider = 'unifiedpush' then
    if not (v_clean_token ~* '^https://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$') then
      raise exception 'UnifiedPush endpoint must be a valid HTTPS URL.';
    end if;

    if v_clean_token ~* '(localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|10\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+)' then
      raise exception 'UnifiedPush endpoint must not target private or local networks.';
    end if;
  end if;

  insert into public.device_tokens (user_id, provider, platform, token)
  values (v_user_id, p_provider, p_platform, v_clean_token)
  on conflict (provider, token) do update
    set user_id      = excluded.user_id,
        platform     = excluded.platform,
        last_seen_at = now();

  insert into public.notification_settings (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;
end;
$$;

revoke execute on function public.register_device(text, text, text) from public, anon;
grant  execute on function public.register_device(text, text, text) to authenticated;


-- ── 5. Blockier-Schutz: Freundschaften & Quest-Einladungen ────────

-- Trigger-Absicherung fuer direkte Inserts (falls vorhanden)
drop trigger if exists trg_block_friendship on public.friendships;
create trigger trg_block_friendship
  before insert on public.friendships
  for each row execute function public.reject_if_blocked('requester_id', 'addressee_id');

drop trigger if exists trg_block_invite on public.invites;
create trigger trg_block_invite
  before insert on public.invites
  for each row execute function public.reject_if_blocked('inviter_id', 'invitee_id');

-- send_friend_request prueft Blockierung
create or replace function public.send_friend_request(p_username text)
returns text
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

  if public.is_blocked_pair(v_user_id, v_target) then
    raise exception 'You cannot interact with this player.';
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
    update public.friendships set status = 'accepted' where id = v_row.id;
    return 'accepted';
  end if;

  insert into public.friendships (requester_id, addressee_id)
  values (v_user_id, v_target);
  return 'pending';
end;
$$;

revoke execute on function public.send_friend_request(text) from public, anon;
grant  execute on function public.send_friend_request(text) to authenticated;

-- invite_to_challenge prueft Blockierung
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

  if public.is_blocked_pair(v_user_id, v_invitee) then
    raise exception 'You cannot interact with this player.';
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
grant  execute on function public.invite_to_challenge(uuid, text) to authenticated;
