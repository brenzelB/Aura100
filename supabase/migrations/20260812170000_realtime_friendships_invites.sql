-- =================================================================
--  AURA QUEST - Freundschaften und Einladungen in Echtzeit
--
--  Beide Tabellen fehlten in der Realtime-Veroeffentlichung. Eine
--  eingehende Freundschaftsanfrage erschien deshalb erst, wenn der
--  Freunde-Tab zufaellig geoeffnet wurde - also genau der Tab, den man
--  NICHT oeffnet, solange man nichts von der Anfrage weiss.
--
--  Ohne diesen Eintrag sendet Postgres keine Aenderungen, und ein
--  Abonnement im Client haengt still in der Luft. Das ist die Sorte
--  Fehler, die niemand sieht: kein Absturz, keine Meldung, es passiert
--  nur nichts.
-- =================================================================

alter publication supabase_realtime add table public.friendships;
alter publication supabase_realtime add table public.invites;
