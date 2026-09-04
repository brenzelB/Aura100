-- =================================================================
--  AURA QUEST - Shop-Item "Blackout"
--
--  Zwei Stunden Funkstille: der Angreifer kauft das Item, waehlt einen
--  Mitstreiter und einen Tagesabschnitt. Waehrend des Fensters kann das
--  Opfer in DIESER Quest nichts eintragen - weder einen Check-in noch
--  Wiederholungen. Was genau gesperrt ist, ergibt sich aus dem Quest-Typ
--  von selbst; auswaehlen muss das niemand.
--
--  Zwei Entwurfsentscheidungen, die man kennen sollte:
--
--  1. "Morgens/Mittags/Abends" meint die ORTSZEIT DES OPFERS. Dafuer
--     merkt sich profiles.utc_offset_minutes, wie weit das Geraet des
--     Spielers von UTC entfernt ist; die App meldet das beim Start.
--     Sonst traefe die Sperre einen Mitspieler im Ausland mitten in
--     der Nacht.
--
--  2. Die Sperre haengt an TRIGGERN auf check_ins und progress_entries,
--     nicht an den RPCs. Damit kommt auch ein kuenftiger Codepfad nicht
--     daran vorbei - dieselbe Bauweise wie reject_if_blocked.
-- =================================================================

-- ── Zeitzone des Spielers ────────────────────────────────────────
alter table public.profiles
  add column if not exists utc_offset_minutes integer not null default 0;

comment on column public.profiles.utc_offset_minutes is
  'Versatz der Geraetezeit zu UTC in Minuten (Berlin Sommer = 120). '
  'Die App meldet ihn beim Start. Nur fuer die Blackout-Tagesabschnitte.';

create or replace function public.set_my_timezone(p_offset_minutes integer)
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
  -- Reale Zeitzonen liegen zwischen -12:00 und +14:00.
  if p_offset_minutes is null
     or p_offset_minutes < -720 or p_offset_minutes > 840 then
    raise exception 'Implausible timezone offset.';
  end if;
  update public.profiles
  set utc_offset_minutes = p_offset_minutes
  where id = v_user_id;
end;
$$;

revoke all on function public.set_my_timezone(integer) from public, anon;
grant execute on function public.set_my_timezone(integer) to authenticated;


-- ── Die Sperren selbst ───────────────────────────────────────────
create table if not exists public.blackouts (
  id              uuid primary key default gen_random_uuid(),
  challenge_id    uuid not null references public.challenges(id) on delete cascade,
  attacker_id     uuid not null references public.profiles(id)   on delete cascade,
  target_id       uuid not null references public.profiles(id)   on delete cascade,
  daypart         text not null check (daypart in ('morning', 'noon', 'evening')),
  starts_at       timestamptz not null,
  ends_at         timestamptz not null,
  cost            integer not null check (cost > 0),
  created_at      timestamptz not null default now(),
  -- Das Opfer hat den Hinweis "du wurdest geblockt" gesehen.
  acknowledged_at timestamptz,
  check (ends_at > starts_at)
);

-- Laeuft gerade eine Sperre? Diese Abfrage stellt jeder Check-in.
create index if not exists blackouts_active_idx
  on public.blackouts (challenge_id, target_id, starts_at, ends_at);

-- Offene Meldung fuer das Opfer.
create index if not exists blackouts_notice_idx
  on public.blackouts (target_id)
  where acknowledged_at is null;

alter table public.blackouts enable row level security;

-- Wie bei Roast und Heist: nur die beiden Beteiligten sehen die Zeile.
-- Ein Dritter soll nicht ausspaehen koennen, wer wann geblockt wird.
drop policy if exists "blackouts readable by the two sides" on public.blackouts;
create policy "blackouts readable by the two sides"
  on public.blackouts for select to authenticated
  using (attacker_id = (select auth.uid()) or target_id = (select auth.uid()));

drop policy if exists "blackouts ack by target" on public.blackouts;
create policy "blackouts ack by target"
  on public.blackouts for update to authenticated
  using (target_id = (select auth.uid()));

-- Kein insert/delete per API - das laeuft ausschliesslich ueber die RPC.
grant select, update on public.blackouts to authenticated;

-- Geblockte Spielerpaare duerfen einander auch hiermit nicht erreichen.
drop trigger if exists trg_block_blackout on public.blackouts;
create trigger trg_block_blackout
  before insert on public.blackouts
  for each row execute function public.reject_if_blocked('attacker_id', 'target_id');


-- ── Die eigentliche Sperre: Trigger auf beiden Tabellen ──────────
create or replace function public.reject_if_blacked_out()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ends_at timestamptz;
begin
  select b.ends_at into v_ends_at
  from public.blackouts b
  where b.challenge_id = new.challenge_id
    and b.target_id = new.user_id
    and now() >= b.starts_at
    and now() <  b.ends_at
  order by b.ends_at desc
  limit 1;

  if found then
    raise exception
      'Blackout - you are locked out of this quest for another % minutes.',
      greatest(1, ceil(extract(epoch from (v_ends_at - now())) / 60)::int);
  end if;

  return new;
end;
$$;

revoke all on function public.reject_if_blacked_out()
  from public, anon, authenticated;

drop trigger if exists trg_blackout_checkin on public.check_ins;
create trigger trg_blackout_checkin
  before insert on public.check_ins
  for each row execute function public.reject_if_blacked_out();

-- Auch UPDATE: edit_progress_entry korrigiert bestehende Eintraege nach
-- oben, das waere sonst ein Schlupfloch.
drop trigger if exists trg_blackout_progress on public.progress_entries;
create trigger trg_blackout_progress
  before insert or update on public.progress_entries
  for each row execute function public.reject_if_blacked_out();


-- ── Kaufen und scharfstellen ─────────────────────────────────────
create or replace function public.cast_blackout(
  p_challenge_id uuid,
  p_target_id    uuid,
  p_daypart      text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id     uuid := (select auth.uid());
  v_cost        constant integer := 250;
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
begin
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
  -- Auf Vermeidungs-Quests gibt es nichts einzutragen, was sich zu
  -- sperren lohnte - das Item wird dort gar nicht erst angeboten.
  if v_challenge.goal_type = 'avoid' then
    raise exception 'A blackout has nothing to block on an avoid quest.';
  end if;

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

  -- Kein Stapeln: solange eine Sperre auf diesem Spieler laeuft oder
  -- ansteht, kommt keine zweite dazu - egal von wem.
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

  -- Das Fenster liegt in der ORTSZEIT DES OPFERS. Gewaehlt wird immer
  -- das naechste, das noch nicht begonnen hat - wer um 07:30 "morgens"
  -- kauft, trifft den morgigen Morgen, nicht die letzte halbe Stunde.
  select coalesce(utc_offset_minutes, 0) into v_offset
  from public.profiles where id = p_target_id;

  v_hour := case p_daypart
              when 'morning' then 7
              when 'noon'    then 12
              else                20
            end;

  v_local_now   := (now() at time zone 'utc') + make_interval(mins => v_offset);
  v_local_start := date_trunc('day', v_local_now) + make_interval(hours => v_hour);
  if v_local_start <= v_local_now then
    v_local_start := v_local_start + interval '1 day';
  end if;

  v_starts_at := (v_local_start - make_interval(mins => v_offset))
                   at time zone 'utc';
  v_ends_at   := v_starts_at + interval '2 hours';

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
    'cost',       v_cost,
    'balance',    v_aura - v_cost
  );
end;
$$;

revoke all on function public.cast_blackout(uuid, uuid, text) from public, anon;
grant execute on function public.cast_blackout(uuid, uuid, text) to authenticated;


-- Das Opfer hakt den Hinweis ab, nachdem es ihn gesehen hat.
create or replace function public.ack_blackouts(p_challenge_id uuid)
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
  update public.blackouts
  set acknowledged_at = now()
  where challenge_id = p_challenge_id
    and target_id = v_user_id
    and acknowledged_at is null
    and starts_at <= now();
end;
$$;

revoke all on function public.ack_blackouts(uuid) from public, anon;
grant execute on function public.ack_blackouts(uuid) to authenticated;


-- ── Ins Sortiment aufnehmen ──────────────────────────────────────
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

  -- Auf einer Vermeidungs-Quest gibt es nichts einzutragen - dort waere
  -- eine Sperre wirkungslos und nur verwirrend.
  if new.goal_type <> 'avoid' then
    insert into public.benefits (challenge_id, title, description, cost) values
      (new.id, 'Blackout',
       'Lock a quest mate out for 2 hours - morning, noon or night. '
       'They cannot log a thing while it lasts.',
       250);
  end if;

  return new;
end;
$$;

revoke all on function public.seed_pvp_benefits()
  from public, anon, authenticated;

-- Bestehende Quests nachruesten.
insert into public.benefits (challenge_id, title, description, cost)
select c.id, 'Blackout',
       'Lock a quest mate out for 2 hours - morning, noon or night. '
       'They cannot log a thing while it lasts.',
       250
from public.challenges c
where c.goal_type <> 'avoid'
  and not exists (
    select 1 from public.benefits b
    where b.challenge_id = c.id and b.title = 'Blackout'
  );


-- ── Live-Übertragung ─────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'blackouts'
  ) then
    alter publication supabase_realtime add table public.blackouts;
  end if;
end $$;
