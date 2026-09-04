-- =================================================================
--  AURA QUEST - Erinnerungen je Spieler und je Quest
--
--  Jeder Teilnehmer stellt fuer JEDE seiner Quests eine eigene Uhrzeit
--  ein. Zwei Spieler derselben Quest koennen also voellig verschiedene
--  Zeiten haben, und derselbe Spieler fuer "Gym" eine andere als fuer
--  "Meditation".
--
--  DIE UHRZEIT IST ORTSZEIT DES SPIELERS. Dafuer gibt es
--  profiles.utc_offset_minutes bereits - die App meldet den Wert beim
--  Start, urspruenglich fuer den Blackout. Ohne das bekaeme ein
--  Mitspieler im Ausland seine Erinnerung mitten in der Nacht.
--
--  WICHTIGER ALS DAS AUSLOESEN IST DAS UNTERDRUECKEN:
--  Eine Erinnerung an etwas laengst Erledigtes ist der schnellste Weg,
--  dass jemand Benachrichtigungen komplett abschaltet - und dann auch
--  die Angriffe nicht mehr sieht. Deshalb faellt sie aus, wenn
--    * heute schon eingetragen wurde (Check-in oder Fortschrittsziel),
--    * die Quest heute gar nicht laeuft (inaktiver Wochentag),
--    * der Spieler ausgeschieden ist oder nur zuschaut,
--    * die Quest noch in der Lobby steht oder vorbei ist,
--    * heute bereits eine Erinnerung verschickt wurde.
-- =================================================================

create table if not exists public.quest_reminders (
  challenge_id  uuid not null references public.challenges(id) on delete cascade,
  user_id       uuid not null references auth.users(id) on delete cascade,
  -- Ortszeit des Spielers, nicht UTC.
  remind_at     time not null,
  enabled       boolean not null default true,
  -- Verhindert mehrere Erinnerungen am selben Tag, auch wenn der
  -- Cron-Job mehrfach laeuft. Ebenfalls Ortszeit.
  last_sent_on  date,
  created_at    timestamptz not null default now(),
  primary key (challenge_id, user_id)
);

alter table public.quest_reminders enable row level security;

create policy "own reminders readable"
  on public.quest_reminders for select
  using ((select auth.uid()) = user_id);

-- ── Setzen und Loeschen ──────────────────────────────────────────

create or replace function public.set_quest_reminder(
  p_challenge_id uuid,
  p_remind_at    time
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

  -- Nur wer mitspielt, darf sich erinnern lassen. Ein Ausgeschiedener
  -- kann ohnehin nichts eintragen; ihn zu erinnern waere Hohn.
  if not exists (
    select 1 from public.challenge_participants
    where challenge_id = p_challenge_id
      and user_id = v_user_id
      and status = 'active'
  ) then
    raise exception 'You are not an active participant of this quest.';
  end if;

  insert into public.quest_reminders (challenge_id, user_id, remind_at, enabled)
  values (p_challenge_id, v_user_id, p_remind_at, true)
  on conflict (challenge_id, user_id) do update
    set remind_at = excluded.remind_at,
        enabled   = true,
        -- Zuruecksetzen, damit eine neu gesetzte Zeit noch heute
        -- greifen kann und nicht bis morgen blockiert ist.
        last_sent_on = null;
end;
$$;

create or replace function public.clear_quest_reminder(p_challenge_id uuid)
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
  delete from public.quest_reminders
  where challenge_id = p_challenge_id and user_id = v_user_id;
end;
$$;

-- ── Der Versand ──────────────────────────────────────────────────

create or replace function public.send_due_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  rec       record;
  v_local   timestamp;
  v_today   date;
  v_erledigt boolean;
  v_pstart  date;
  v_gesendet integer := 0;
begin
  for rec in
    select r.challenge_id, r.user_id, r.remind_at, r.last_sent_on,
           c.title, c.goal_type, c.checkin_period, c.checkins_per_period,
           c.target_value, c.active_weekdays, c.starts_on, c.duration_days,
           c.is_endless, c.lifecycle,
           coalesce(p.utc_offset_minutes, 0) as offset_min
    from public.quest_reminders r
    join public.challenges c on c.id = r.challenge_id
    join public.profiles   p on p.id = r.user_id
    join public.challenge_participants cp
         on cp.challenge_id = r.challenge_id and cp.user_id = r.user_id
    where r.enabled
      and c.lifecycle = 'active'
      and cp.status = 'active'
  loop
    -- Ortszeit des Spielers.
    v_local := (now() at time zone 'utc') + make_interval(mins => rec.offset_min);
    v_today := v_local::date;

    -- Noch nicht so weit, oder heute schon erinnert.
    if v_local::time < rec.remind_at then continue; end if;
    if rec.last_sent_on is not null and rec.last_sent_on >= v_today then
      continue;
    end if;

    -- Zu spaet: Was mehr als zwei Stunden zurueckliegt, ist keine
    -- Erinnerung mehr. Sonst prasselt nach einem Serverausfall alles
    -- auf einmal herein.
    if v_local::time > rec.remind_at + interval '2 hours' then continue; end if;

    -- Laeuft die Quest heute ueberhaupt?
    if not (extract(isodow from v_local)::int = any(rec.active_weekdays)) then
      continue;
    end if;
    if v_today < rec.starts_on then continue; end if;
    if not rec.is_endless
       and v_today >= rec.starts_on + rec.duration_days then continue; end if;

    -- Schon erledigt? Der Periodenanfang haengt am Startdatum der Quest,
    -- nicht am Kalender.
    v_pstart := case rec.checkin_period
      when 'weekly'  then rec.starts_on + (((v_today - rec.starts_on) / 7) * 7)
      when 'monthly' then rec.starts_on + (((v_today - rec.starts_on) / 30) * 30)
      else v_today
    end;

    v_erledigt := case rec.goal_type
      when 'progress' then coalesce((
          select sum(pe.amount) from public.progress_entries pe
          where pe.challenge_id = rec.challenge_id
            and pe.user_id = rec.user_id
            and pe.period_start = v_pstart), 0) >= coalesce(rec.target_value, 0)
      when 'check' then (
          select count(*) from public.check_ins ci
          where ci.challenge_id = rec.challenge_id
            and ci.user_id = rec.user_id
            and ci.checked_on >= v_pstart) >= rec.checkins_per_period
      -- Avoid-Quests verlangen keine Eintragung; dort gibt es nichts,
      -- was "schon erledigt" waere.
      else false
    end;

    if v_erledigt then
      -- Nicht erinnern, aber den Tag abhaken: Sonst prueft der naechste
      -- Lauf in fuenf Minuten dasselbe noch einmal.
      update public.quest_reminders
        set last_sent_on = v_today
        where challenge_id = rec.challenge_id and user_id = rec.user_id;
      continue;
    end if;

    perform public.enqueue_notification(
      rec.user_id,
      'quest',
      rec.challenge_id,
      'Still open: ' || rec.title,
      case rec.goal_type
        when 'avoid' then 'Still clean today? Log a slip if not.'
        when 'progress' then 'You have not hit today''s target yet.'
        else 'You have not checked in yet today.'
      end
    );

    update public.quest_reminders
      set last_sent_on = v_today
      where challenge_id = rec.challenge_id and user_id = rec.user_id;
    v_gesendet := v_gesendet + 1;
  end loop;

  return v_gesendet;
end;
$$;

-- Alle fuenf Minuten. Feiner waere Genauigkeit ohne Nutzen: Wer 18:00
-- einstellt, dem ist 18:04 recht - und der NAS hat Besseres zu tun.
select cron.schedule('send-quest-reminders', '*/5 * * * *',
                     'select public.send_due_reminders()');

grant execute on function public.set_quest_reminder(uuid, time) to authenticated;
grant execute on function public.clear_quest_reminder(uuid) to authenticated;
revoke all on function public.send_due_reminders() from public, anon, authenticated;
