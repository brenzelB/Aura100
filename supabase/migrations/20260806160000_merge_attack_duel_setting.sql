-- =================================================================
--  AURA QUEST - Angriffe und Duelle teilen sich eine Einstellung
--
--  Aus Spielersicht ist beides dasselbe: etwas, das ein Mitspieler
--  gegen einen unternimmt. Zwei Schalter dafuer waren eine Unterschei-
--  dung, die nur der Datenbank etwas bedeutete.
--
--  UMGESETZT ALS EINE QUELLE, NICHT ALS ZWEI GLEICHGESCHALTETE:
--  Die Spalte `attacks` entscheidet ab jetzt fuer beide Kategorien.
--  `duels` bleibt bestehen, wird aber nicht mehr gelesen - zwei
--  Spalten, die immer gleich sein muessen, sind eine stille Bedingung,
--  die frueher oder spaeter auseinanderlaeuft.
--
--  Die Kategorien in notification_outbox bleiben getrennt ('attack'
--  und 'duel'): Sie steuern, wohin ein Antippen der Meldung fuehrt -
--  Angriffe zur Quest, Duelle zur Startseite. Das ist unabhaengig
--  davon, ob man sie ueberhaupt bekommen will.
-- =================================================================

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

  -- Niemand will ueber die eigene Handlung benachrichtigt werden.
  if p_user_id = (select auth.uid()) then
    return;
  end if;

  -- Ohne Geraet waere jede Zeile nur Ballast.
  if not exists (select 1 from public.device_tokens where user_id = p_user_id) then
    return;
  end if;

  -- Fehlende Einstellungen gelten als "alles an".
  select case p_category
           -- Angriff und Duell hoeren auf denselben Schalter.
           when 'attack' then s.attacks
           when 'duel'   then s.attacks
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

revoke all on function public.enqueue_notification(uuid, text, uuid, text, text)
  from public, anon, authenticated;

-- Bestand angleichen: Wer Duelle abgeschaltet hatte, Angriffe aber
-- nicht, haette sonst durch den Umbau ungefragt wieder Duelle bekommen.
update public.notification_settings
   set attacks = false
 where duels = false and attacks = true;
