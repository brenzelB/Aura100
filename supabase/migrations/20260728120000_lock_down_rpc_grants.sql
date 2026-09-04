-- =================================================================
--  AURA QUEST - RPC-Rechte abdichten
--
--  Postgres vergibt neuen Funktionen standardmaessig EXECUTE an PUBLIC.
--  Bei den meisten RPCs wurde das gleich wieder entzogen - bei diesen
--  sechs nicht, sodass sie ueber /rest/v1/rpc/... sogar OHNE Anmeldung
--  aufrufbar waren. Aufgefallen im Supabase-Security-Advisor.
--
--  Gefahr war begrenzt (create_challenge bricht ohne auth.uid() ab, die
--  Trigger-Funktionen laufen direkt aufgerufen ohnehin auf einen Fehler),
--  aber nichts davon gehoert an die oeffentliche API.
--
--  Ausdruecklich NICHT angefasst: die uebrigen SECURITY-DEFINER-RPCs,
--  die 'authenticated' aufrufen darf. Das ist die Architektur - die
--  Regeln (Aura, Strikes, Blocks) werden in diesen Funktionen
--  durchgesetzt, nicht im Client.
-- =================================================================

-- Quests anlegen: nur angemeldet.
revoke execute on function public.create_challenge(
  text, integer, integer, integer, integer, date, text, text,
  integer, text, text, numeric, text, boolean, integer
) from public, anon;
grant execute on function public.create_challenge(
  text, integer, integer, integer, integer, date, text, text,
  integer, text, text, numeric, text, boolean, integer
) to authenticated;

-- Interner Helfer der Settlement-Engine - kein API-Endpunkt.
-- Die aufrufenden Funktionen sind SECURITY DEFINER und laufen als
-- Eigentuemer, ihnen fehlt danach nichts.
revoke all on function public.aura_multiplier(uuid, uuid)
  from public, anon, authenticated;

-- Trigger-Funktionen: werden von Triggern ausgefuehrt, niemals direkt.
revoke all on function public.mark_pokes_seen_on_checkin()
  from public, anon, authenticated;
revoke all on function public.reject_if_blocked()
  from public, anon, authenticated;
revoke all on function public.seed_pvp_benefits()
  from public, anon, authenticated;

do $$
begin
  if to_regproc('public.seed_targeted_roast_benefit') is not null then
    execute 'revoke all on function public.seed_targeted_roast_benefit() '
            'from public, anon, authenticated';
  end if;
end $$;
