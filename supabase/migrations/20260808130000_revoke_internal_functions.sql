-- =================================================================
--  AURA QUEST - Interne Funktionen von aussen entziehen
--
--  GEFUNDEN BEI EINER SICHERHEITSPRUEFUNG, AUSNUTZBAR BESTAETIGT:
--
--  push_username(uuid) und push_quest_title(uuid) sind SECURITY
--  DEFINER - sie umgehen also RLS - und standen `anon` offen. Damit
--  liess sich OHNE KONTO, allein mit dem oeffentlichen Schluessel aus
--  der ausgelieferten App, jede UUID in einen Benutzernamen oder einen
--  Quest-Titel aufloesen:
--
--      POST /rest/v1/rpc/push_username  {"p_user_id": "..."}
--        -> "@newBrenzel"
--      POST /rest/v1/rpc/push_quest_title  {"p_challenge_id": "..."}
--        -> "NAS Testlauf"
--
--  Das hebelt die Lese-Policies vollstaendig aus. UUIDs sind kein
--  Geheimnis: Sie reisen in Push-Nutzlasten (refId) mit, stehen in
--  Verweisen und tauchen in Fehlermeldungen auf.
--
--  URSACHE: Beim Anlegen der Push-Funktionen habe ich die Rechte nie
--  entzogen. Postgres gibt neue Funktionen standardmaessig an PUBLIC
--  frei - man muss aktiv widersprechen. Beides wird ausschliesslich
--  aus Trigger-Funktionen aufgerufen, die selbst als DEFINER laufen;
--  der Entzug bricht daher nichts.
--
--  Die notify_*-Trigger bekommen denselben Entzug. PostgREST bietet
--  Trigger-Funktionen zwar nicht als RPC an, aber ein Recht, das
--  niemand braucht, gehoert niemandem gegeben.
-- =================================================================

revoke all on function public.push_username(uuid)     from public, anon, authenticated;
revoke all on function public.push_quest_title(uuid)  from public, anon, authenticated;

-- Hilfsfunktion der Blockier-Logik: prueft ein Paar, gibt nur
-- wahr/falsch zurueck, wird aber ebenfalls nur intern gebraucht.
revoke all on function public.is_blocked_pair(uuid, uuid) from public, anon, authenticated;

-- Trigger-Funktionen: werden von Postgres aufgerufen, nie von Clients.
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prorettype = 'trigger'::regtype
  loop
    execute format('revoke all on function %s from public, anon, authenticated', r.sig);
  end loop;
end $$;

-- Auch die Cron-Funktionen noch einmal absichern, falls eine davon
-- beim Anlegen durchgerutscht ist.
revoke all on function public.settle_periods()            from public, anon, authenticated;
revoke all on function public.expire_duels()              from public, anon, authenticated;
revoke all on function public.send_due_reminders()        from public, anon, authenticated;
revoke all on function public.aura_multiplier(uuid, uuid) from public, anon, authenticated;
revoke all on function public.seed_pvp_benefits()            from public, anon, authenticated;
revoke all on function public.seed_targeted_roast_benefit()  from public, anon, authenticated;
