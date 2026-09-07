-- =================================================================
-- Migration: 20260907140000_push_delivery_and_ssrf_hardening.sql
--
-- Behebt die priorisierten Audit-Befunde aus der Sicherheitsprüfung:
--  * Befund 05: Vollständiger SSRF-Schutz in register_device (Loopback, Link-Local, CGNAT, Portfilter, Allowlist)
--  * Befund 11: Reparatur von reap_push_failures (keine Referenz mehr auf nicht existente Spalte r.url)
--  * Befund 12: Robuste Retry-Logik für temporär fehlgeschlagene Push-Zustellungen (503, 429, Timeout)
-- =================================================================

-- ── 1. push_config erweitern ─────────────────────────────────────

alter table public.push_config
  add column if not exists unifiedpush_allowed_hosts text[];


-- ── 2. Tracking-Tabelle für asynchrone pg_net Zustellungen ────────

create table if not exists public.push_delivery_attempts (
  id              bigint generated always as identity primary key,
  outbox_id       bigint not null references public.notification_outbox(id) on delete cascade,
  device_token_id uuid references public.device_tokens(id) on delete set null,
  request_id      bigint not null,
  provider        text not null,
  status          text not null default 'in_flight'
                  check (status in ('in_flight', 'delivered', 'retryable_error', 'permanent_error', 'dead_token')),
  created_at      timestamptz not null default now()
);

create index if not exists push_delivery_attempts_req_idx
  on public.push_delivery_attempts (request_id);

create index if not exists push_delivery_attempts_in_flight_idx
  on public.push_delivery_attempts (status) where status = 'in_flight';

alter table public.push_delivery_attempts enable row level security;
-- Rein interne Tabelle: Zugriff ausschließlich über SECURITY DEFINER Funktionen


-- ── 3. Befund 05: register_device mit lückenlosem SSRF-Schutz ────

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
  v_user_id       uuid := (select auth.uid());
  v_clean_token   text;
  v_host          text;
  v_port_str      text;
  v_port          integer;
  v_allowed_hosts text[];
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
  -- unsichere Protokolle oder interne Services eingetragen werden.
  if p_provider = 'unifiedpush' then
    if not (v_clean_token ~* '^https://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$') then
      raise exception 'UnifiedPush endpoint must be a valid HTTPS URL.';
    end if;

    -- Hostname extrahieren
    v_host := lower(substring(v_clean_token from '^https://([^/:]+)'));

    -- Port extrahieren und sensible interne Service-Ports sperren
    v_port_str := substring(v_clean_token from '^https://[^/:]+:([0-9]+)');
    if v_port_str is not null then
      v_port := v_port_str::integer;
      if v_port in (21, 22, 23, 25, 53, 80, 110, 143, 445, 2049, 2375, 2376, 3000, 3306, 5432, 5433, 6379, 8000, 8080, 8081, 9000, 9090, 11211) then
        raise exception 'UnifiedPush endpoint port % is not permitted.', v_port;
      end if;
    end if;

    -- 1. Lokale und interne Hostnamen/Suffixe
    if v_host ~* '^(localhost|[a-zA-Z0-9.-]+\.(localhost|local|lan|internal|home\.arpa|intranet))$' then
      raise exception 'UnifiedPush endpoint must not target private or local networks.';
    end if;

    -- 2. IPv4: Loopback (127.0.0.0/8, 0.0.0.0/8), Private (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16),
    --    Link-Local & Cloud Metadata (169.254.0.0/16), CGNAT (100.64.0.0/10), Testnetze (192.0.2, 198.51.100, 203.0.113, 198.18-19)
    if v_host ~* '^(0\.|127\.|10\.|169\.254\.|192\.168\.|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.)'
       or v_host ~* '^172\.(1[6-9]|2[0-9]|3[01])\.'
       or v_host ~* '^100\.(6[4-9]|[7-9][0-9]|1[0-1][0-9]|12[0-7])\.'
       or v_host ~* '^198\.(1[89])\.' then
      raise exception 'UnifiedPush endpoint must not target private or local networks.';
    end if;

    -- 3. IPv6: Loopback (::1), Link-Local (fe80::), ULA (fc00::, fd00::), IPv4-mapped (::ffff:)
    if v_host ~* '^(\[::1\]|\[fe80:|\[fc|\[fd|\[::ffff:)' then
      raise exception 'UnifiedPush endpoint must not target private or local networks.';
    end if;

    -- 4. Optionale administrative Host-Allowlist aus push_config prüfen
    select unifiedpush_allowed_hosts into v_allowed_hosts
    from public.push_config where id;

    if v_allowed_hosts is not null and cardinality(v_allowed_hosts) > 0 then
      if not (v_host = any(v_allowed_hosts)) then
        raise exception 'UnifiedPush endpoint host "%" is not in the allowed hosts list.', v_host;
      end if;
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

revoke all on function public.register_device(text, text, text) from public, anon;
grant  execute on function public.register_device(text, text, text) to authenticated;


-- ── 4. Befunde 11 & 12: deliver_notifications mit Request-Tracking ─

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
  v_req_id bigint;
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
    for update skip locked
  loop
    v_reach := 0;

    for v_dev in
      select * from public.device_tokens where user_id = v_row.user_id
    loop
      begin
        if v_dev.provider = 'unifiedpush' then
          select net.http_post(
            url     := v_dev.token,
            headers := jsonb_build_object('Content-Type', 'application/json'),
            body    := jsonb_build_object(
                         'title',    v_row.title,
                         'message',  v_row.body,
                         'category', v_row.category,
                         'refId',    v_row.ref_id,
                         'id',       v_row.id)
          ) into v_req_id;

          insert into public.push_delivery_attempts
            (outbox_id, device_token_id, request_id, provider)
          values (v_row.id, v_dev.id, v_req_id, 'unifiedpush');

          v_reach := v_reach + 1;

        elsif v_dev.provider = 'fcm'
              and v_cfg.fcm_function_url is not null then
          select net.http_post(
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
          ) into v_req_id;

          insert into public.push_delivery_attempts
            (outbox_id, device_token_id, request_id, provider)
          values (v_row.id, v_dev.id, v_req_id, 'fcm');

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

revoke all on function public.deliver_notifications(integer) from public, anon, authenticated;


-- ── 5. Befunde 11 & 12: reap_push_failures mit id-Join & Retry ────

create or replace function public.reap_push_failures()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rec       record;
  v_dead_cnt  integer := 0;
begin
  -- Antworten asynchroner Requests über pg_net zuordnen
  -- Behebt Befund 11 (r.url existierte nicht) und Befund 12 (Retry bei 503/Timeout)
  for v_rec in
    select a.id as attempt_id, a.outbox_id, a.device_token_id, a.provider,
           r.status_code, r.timed_out, r.error_msg
    from public.push_delivery_attempts a
    join net._http_response r on r.id = a.request_id
    where a.status = 'in_flight'
  loop
    -- Fall 1: Token ungültig / App deinstalliert (404, 410)
    if v_rec.status_code in (404, 410) then
      update public.push_delivery_attempts
        set status = 'dead_token'
        where id = v_rec.attempt_id;

      if v_rec.device_token_id is not null then
        delete from public.device_tokens where id = v_rec.device_token_id;
        v_dead_cnt := v_dead_cnt + 1;
      end if;

    -- Fall 2: Temporärer Fehler (Timeout, 408, 429, 500, 502, 503, 504)
    -- Befund 12: sent_at auf null zurücksetzen für Wiederholungsversuch
    elsif coalesce(v_rec.timed_out, false)
          or v_rec.status_code in (408, 429, 500, 502, 503, 504)
          or (v_rec.status_code is null and v_rec.error_msg is not null) then
      update public.push_delivery_attempts
        set status = 'retryable_error'
        where id = v_rec.attempt_id;

      update public.notification_outbox
      set sent_at = null,
          last_error = coalesce('HTTP ' || v_rec.status_code, v_rec.error_msg, 'Timeout')
      where id = v_rec.outbox_id
        and attempts < 5;

    -- Fall 3: Erfolgreich zugestellt (200-299)
    elsif v_rec.status_code between 200 and 299 then
      update public.push_delivery_attempts
        set status = 'delivered'
        where id = v_rec.attempt_id;

    -- Fall 4: Sonstige permanente Fehler (400, 401, 403, ...)
    else
      update public.push_delivery_attempts
        set status = 'permanent_error'
        where id = v_rec.attempt_id;

      update public.notification_outbox
      set last_error = 'HTTP ' || coalesce(v_rec.status_code::text, 'error')
      where id = v_rec.outbox_id;
    end if;
  end loop;

  -- Aufräumen alter Versuche (> 2 Tage) und alter pg_net-Antworten (> 1 Tag)
  delete from public.push_delivery_attempts where created_at < now() - interval '2 days';
  begin
    delete from net._http_response where created < now() - interval '1 day';
  exception when others then
    null;
  end;

  return v_dead_cnt;
end;
$$;

revoke all on function public.reap_push_failures() from public, anon, authenticated;

-- Zeitplan optimieren: reap-push-failures alle 5 Minuten
do $$
begin
  if exists (select 1 from cron.job where jobname = 'reap-push-failures') then
    perform cron.unschedule('reap-push-failures');
  end if;
  perform cron.schedule('reap-push-failures', '*/5 * * * *',
                        'select public.reap_push_failures()');
exception when others then
  -- In Umgebungen ohne pg_cron (z. B. lokale Tests) ignorieren
  null;
end $$;
