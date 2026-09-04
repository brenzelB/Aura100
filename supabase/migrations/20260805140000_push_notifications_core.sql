-- =================================================================
--  AURA QUEST - Push-Benachrichtigungen, Stufe 1: Datenmodell
--
--  Ohne Push verpufft die halbe Spielmechanik: Ein Blackout, ein Raub
--  oder eine Duell-Herausforderung wirkt erst, wenn das Opfer davon
--  erfaehrt. Bisher erfuhr es das erst beim naechsten Oeffnen der App.
--
--  Aufbau in drei Teilen, weil jeder Teil fuer sich pruefbar sein soll:
--
--    1. device_tokens        - wohin darf zugestellt werden
--    2. notification_settings- was will der Spieler ueberhaupt wissen
--    3. notification_outbox  - was ist zu senden (Warteschlange)
--
--  WARUM EINE WARTESCHLANGE UND KEIN DIREKTER VERSAND AUS DEM TRIGGER:
--
--  Ein Trigger laeuft INNERHALB der Transaktion des Spielers. Wuerde er
--  direkt einen HTTP-Aufruf machen, haette das drei Folgen: Der Check-in
--  des Spielers wartet auf einen fremden Server; ein Ausfall von Firebase
--  liesse seine Aktion fehlschlagen; und ein Rollback wuerde eine bereits
--  verschickte Nachricht nicht zurueckholen. Die Warteschlange entkoppelt
--  das: Der Trigger schreibt nur eine Zeile, der Versand passiert danach
--  und darf beliebig oft scheitern, ohne das Spiel zu stoeren.
--
--  ZWEI ZUSTELLWEGE, EIN DATENMODELL: Ein Geraet kann per Firebase (FCM)
--  oder per UnifiedPush erreichbar sein. Beide sind nur eine Zeichenkette
--  in derselben Spalte - bei FCM ein Registrierungs-Token, bei
--  UnifiedPush eine Endpunkt-URL. Der Versand unterscheidet sie, das
--  Datenmodell muss es nicht.
-- =================================================================

-- ── 1. Geraete ───────────────────────────────────────────────────

create table if not exists public.device_tokens (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  provider     text not null check (provider in ('fcm', 'unifiedpush')),
  platform     text not null check (platform in ('android', 'ios')),
  -- FCM: Registrierungs-Token. UnifiedPush: die Endpunkt-URL.
  token        text not null,
  created_at   timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  -- Ein Token gehoert immer genau einem Konto. Meldet sich auf demselben
  -- Geraet jemand anders an, wandert die Zeile mit (siehe register_device).
  unique (provider, token)
);

create index if not exists device_tokens_user_idx
  on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

-- Nur das eigene Geraet ist sichtbar. Der Versand laeuft ueber
-- SECURITY DEFINER und umgeht RLS ohnehin.
create policy "own devices readable"
  on public.device_tokens for select
  using ((select auth.uid()) = user_id);

create policy "own devices removable"
  on public.device_tokens for delete
  using ((select auth.uid()) = user_id);

-- ── 2. Einstellungen ─────────────────────────────────────────────
--
--  Vier Kategorien statt eines Schalters. Wer die Angriffe abschaltet,
--  will deswegen nicht auf Quest-Einladungen verzichten.

create table if not exists public.notification_settings (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  -- Blackout, Aura Heist, Targeted Roast
  attacks    boolean not null default true,
  -- Herausforderung und Ergebnis
  duels      boolean not null default true,
  -- Einladungen, Freundschaftsanfragen, Pokes
  social     boolean not null default true,
  -- Strike, Quest verloren, Quest geschafft
  quests     boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.notification_settings enable row level security;

create policy "own settings readable"
  on public.notification_settings for select
  using ((select auth.uid()) = user_id);

create policy "own settings writable"
  on public.notification_settings for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "own settings insertable"
  on public.notification_settings for insert
  with check ((select auth.uid()) = user_id);

-- ── 3. Warteschlange ─────────────────────────────────────────────

create table if not exists public.notification_outbox (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  category   text not null check (category in ('attack','duel','social','quest')),
  -- Die Zeile, die den Anlass gab - erlaubt der App, nach dem Wecken
  -- gezielt nachzuladen.
  ref_id     uuid,
  title      text not null,
  body       text not null,
  created_at timestamptz not null default now(),
  sent_at    timestamptz,
  attempts   integer not null default 0,
  last_error text
);

-- Der Versand fragt ausschliesslich nach unversandten Zeilen; ein
-- Teilindex haelt ihn auch dann schnell, wenn die Tabelle waechst.
create index if not exists notification_outbox_pending_idx
  on public.notification_outbox (created_at)
  where sent_at is null;

alter table public.notification_outbox enable row level security;
-- Absichtlich keine Policy: Die Warteschlange geht niemanden etwas an
-- ausser dem Versand, und der laeuft mit SECURITY DEFINER.

-- ── Geraet anmelden ──────────────────────────────────────────────

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
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if p_token is null or length(trim(p_token)) = 0 then
    raise exception 'Empty token.';
  end if;

  insert into public.device_tokens (user_id, provider, platform, token)
  values (v_user_id, p_provider, p_platform, trim(p_token))
  -- Dasselbe Geraet meldet sich bei jedem Start erneut. Der haeufige
  -- Fall ist also nicht "neu", sondern "schon bekannt" - dann nur die
  -- Lebenszeichen-Spalte nachziehen. Wechselt das Konto auf dem Geraet,
  -- wandert das Token mit, sonst bekaeme der Vorbesitzer weiter Post.
  on conflict (provider, token) do update
    set user_id      = excluded.user_id,
        platform     = excluded.platform,
        last_seen_at = now();

  -- Beim ersten Geraet die Standardeinstellungen anlegen.
  insert into public.notification_settings (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;
end;
$$;

-- Beim Abmelden aufraeumen, sonst bekommt das Geraet weiter Nachrichten
-- fuer ein Konto, an dem niemand mehr angemeldet ist.
create or replace function public.unregister_device(p_token text)
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
  delete from public.device_tokens
  where user_id = v_user_id and token = trim(p_token);
end;
$$;

-- ── Einstellungen lesen und schreiben ────────────────────────────

create or replace function public.get_notification_settings()
returns public.notification_settings
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_row     public.notification_settings;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_row from public.notification_settings where user_id = v_user_id;
  if not found then
    insert into public.notification_settings (user_id)
    values (v_user_id)
    returning * into v_row;
  end if;
  return v_row;
end;
$$;

create or replace function public.set_notification_settings(
  p_attacks boolean,
  p_duels   boolean,
  p_social  boolean,
  p_quests  boolean
) returns void
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

  insert into public.notification_settings
    (user_id, attacks, duels, social, quests)
  values (v_user_id, p_attacks, p_duels, p_social, p_quests)
  on conflict (user_id) do update
    set attacks = excluded.attacks,
        duels   = excluded.duels,
        social  = excluded.social,
        quests  = excluded.quests;
end;
$$;

-- ── Der Einwurf in die Warteschlange ─────────────────────────────
--
--  Ein einziger Weg hinein, damit die Regeln (eigene Aktion, stumm
--  geschaltete Kategorie, kein Geraet) an genau einer Stelle stehen.

create or replace function public.enqueue_notification(
  p_user_id  uuid,
  p_category text,
  p_ref_id   uuid,
  p_title    text,
  p_body     text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_wanted boolean;
begin
  if p_user_id is null then
    return;
  end if;

  -- Niemand will ueber die eigene Handlung benachrichtigt werden. Der
  -- Vergleich mit auth.uid() greift nur bei Aktionen aus der App; laeuft
  -- der Aufruf aus dem Cron (settle_periods), ist auth.uid() null und
  -- die Bedingung faellt korrekt durch.
  if p_user_id = (select auth.uid()) then
    return;
  end if;

  -- Ohne Geraet waere jede Zeile nur Ballast.
  if not exists (select 1 from public.device_tokens where user_id = p_user_id) then
    return;
  end if;

  -- Fehlende Einstellungen gelten als "alles an": Wer sich nie damit
  -- befasst hat, soll die Nachrichten trotzdem bekommen.
  select case p_category
           when 'attack' then s.attacks
           when 'duel'   then s.duels
           when 'social' then s.social
           when 'quest'  then s.quests
           else true
         end
    into v_wanted
  from public.notification_settings s
  where s.user_id = p_user_id;

  if v_wanted is false then
    return;
  end if;

  insert into public.notification_outbox
    (user_id, category, ref_id, title, body)
  values (p_user_id, p_category, p_ref_id, p_title, p_body);
end;
$$;

-- ── Rechte ───────────────────────────────────────────────────────
--
--  enqueue_notification ist bewusst NICHT fuer angemeldete Nutzer
--  freigegeben: Sonst koennte jeder jedem beliebigen Konto beliebigen
--  Text schicken. Aufgerufen wird sie ausschliesslich aus Triggern.

revoke all on function public.enqueue_notification(uuid, text, uuid, text, text)
  from public, anon, authenticated;

grant execute on function public.register_device(text, text, text) to authenticated;
grant execute on function public.unregister_device(text) to authenticated;
grant execute on function public.get_notification_settings() to authenticated;
grant execute on function public.set_notification_settings(boolean, boolean, boolean, boolean)
  to authenticated;
