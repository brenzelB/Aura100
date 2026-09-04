-- =================================================================
--  AURA QUEST - Push-Benachrichtigungen, Stufe 3: Zustellung
--
--  Leert die Warteschlange und schickt jede Nachricht an alle Geraete
--  des Empfaengers. Zwei Wege, absichtlich verschieden gebaut:
--
--  UNIFIEDPUSH (selbst gehostet): Die Datenbank ruft die Endpunkt-URL
--    direkt per pg_net auf. Kein Zwischenstueck, kein fremder Dienst,
--    und der volle Text darf mitreisen - der Server gehoert dir.
--
--  FIREBASE (FCM): Braucht ein mit einem Dienstkonto signiertes
--    OAuth2-Token. Das in plpgsql zu bauen waere Unfug, deshalb macht
--    es eine Edge Function. Die Datenbank uebergibt ihr nur Token und
--    Nutzlast.
--
--  WAS AN GOOGLE GEHT: nur Kategorie und die ID des ausloesenden
--  Datensatzes. Keine Namen, keine Quest-Titel, keine Sprueche. Die App
--  wird geweckt, holt den Text von DIESEM Server und zeigt ihn selbst
--  an. Google sieht, DASS etwas passiert ist - nicht, was.
--
--  ZUR EHRLICHKEIT UEBER pg_net: Es arbeitet asynchron. Der Aufruf
--  reiht die Anfrage nur ein und liefert eine ID; die Antwort landet
--  spaeter in net._http_response. "Gesendet" heisst hier also
--  "uebergeben", nicht "zugestellt". Genau dafuer gibt es
--  reap_push_failures(): Es sieht die Antworten nachtraeglich durch und
--  wirft Geraete weg, die der Empfaenger-Dienst als tot meldet.
-- =================================================================

-- ── Konfiguration ────────────────────────────────────────────────
--
--  Eine Zeile, damit URL und Geheimnis nicht im Code stehen. Ohne
--  Firebase-Eintrag ueberspringt die Zustellung den FCM-Weg still -
--  UnifiedPush laeuft davon unabhaengig.

create table if not exists public.push_config (
  id             boolean primary key default true check (id),
  -- Vollstaendige URL der Edge Function, die an FCM ausliefert.
  fcm_function_url text,
  -- Wird als Header mitgeschickt, damit die Funktion nicht von
  -- beliebigen Absendern benutzt werden kann.
  fcm_shared_secret text,
  updated_at     timestamptz not null default now()
);

alter table public.push_config enable row level security;
-- Keine Policy: geht ausschliesslich SECURITY-DEFINER-Funktionen etwas an.

insert into public.push_config (id) values (true) on conflict (id) do nothing;

-- ── Die Zustellung ───────────────────────────────────────────────

create or replace function public.deliver_notifications(p_limit integer default 200)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row    record;
  v_dev    record;
  v_cfg    public.push_config;
  v_sent   integer := 0;
  v_reach  integer;
begin
  select * into v_cfg from public.push_config where id;

  for v_row in
    select * from public.notification_outbox
    where sent_at is null
      -- Nach fuenf Fehlversuchen ist es hoffnungslos; die Zeile bleibt
      -- als Beleg liegen, blockiert aber die Warteschlange nicht mehr.
      and attempts < 5
    order by created_at
    limit p_limit
    -- Verhindert doppelten Versand, falls zwei Laeufe sich ueberholen.
    for update skip locked
  loop
    v_reach := 0;

    for v_dev in
      select * from public.device_tokens where user_id = v_row.user_id
    loop
      begin
        if v_dev.provider = 'unifiedpush' then
          -- Eigener Server: Der Text darf mit.
          perform net.http_post(
            url     := v_dev.token,
            headers := jsonb_build_object('Content-Type', 'application/json'),
            body    := jsonb_build_object(
                         'title',    v_row.title,
                         'message',  v_row.body,
                         'category', v_row.category,
                         'refId',    v_row.ref_id,
                         'id',       v_row.id)
          );
          v_reach := v_reach + 1;

        elsif v_dev.provider = 'fcm'
              and v_cfg.fcm_function_url is not null then
          -- Fremder Server: nur ein inhaltsleeres Wecksignal.
          perform net.http_post(
            url     := v_cfg.fcm_function_url,
            headers := jsonb_build_object(
                         'Content-Type', 'application/json',
                         'x-push-secret', coalesce(v_cfg.fcm_shared_secret, '')),
            body    := jsonb_build_object(
                         'token',    v_dev.token,
                         'platform', v_dev.platform,
                         'category', v_row.category,
                         'refId',    v_row.ref_id,
                         'id',       v_row.id)
          );
          v_reach := v_reach + 1;
        end if;
      exception when others then
        -- Ein kaputtes Geraet darf die anderen nicht mitreissen.
        update public.notification_outbox
          set last_error = left(sqlerrm, 300)
          where id = v_row.id;
      end;
    end loop;

    if v_reach > 0 then
      update public.notification_outbox
        set sent_at = now(), attempts = attempts + 1
        where id = v_row.id;
      v_sent := v_sent + 1;
    else
      -- Kein erreichbares Geraet: zaehlen und beim naechsten Lauf erneut
      -- versuchen. Meldet sich das Geraet zwischendurch an, klappt es.
      update public.notification_outbox
        set attempts = attempts + 1,
            last_error = 'no reachable device'
        where id = v_row.id;
    end if;
  end loop;

  return v_sent;
end;
$$;

-- ── Tote Geraete aussortieren ────────────────────────────────────
--
--  Ein Token verfaellt, wenn die App deinstalliert wird. Der Dienst
--  antwortet dann mit 404 oder 410. Wer das ignoriert, schickt auf
--  ewig Nachrichten ins Leere.

create or replace function public.reap_push_failures()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_gone integer := 0;
begin
  with tot as (
    select r.url
    from net._http_response r
    where r.status_code in (404, 410)
      and r.created > now() - interval '2 hours'
  )
  delete from public.device_tokens d
  using tot
  where d.provider = 'unifiedpush' and d.token = tot.url;
  get diagnostics v_gone = row_count;

  -- Aufraeumen, damit die Antworttabelle nicht unbegrenzt waechst.
  delete from net._http_response where created < now() - interval '1 day';

  return v_gone;
end;
$$;

-- ── Alte Nachrichten wegwerfen ───────────────────────────────────

create or replace function public.prune_notification_outbox()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_deleted integer;
begin
  delete from public.notification_outbox
  where created_at < now() - interval '14 days';
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

-- ── Zeitplan ─────────────────────────────────────────────────────
--
--  Jede Minute. Eine Duell-Herausforderung, die zehn Minuten braucht,
--  waere keine Benachrichtigung mehr, sondern eine Nachricht aus der
--  Vergangenheit.

select cron.schedule('deliver-notifications', '* * * * *',
                     'select public.deliver_notifications()');
select cron.schedule('reap-push-failures', '*/15 * * * *',
                     'select public.reap_push_failures()');
select cron.schedule('prune-notification-outbox', '30 4 * * *',
                     'select public.prune_notification_outbox()');

revoke all on function public.deliver_notifications(integer) from public, anon, authenticated;
revoke all on function public.reap_push_failures() from public, anon, authenticated;
revoke all on function public.prune_notification_outbox() from public, anon, authenticated;
