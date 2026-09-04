-- =================================================================
--  AURA QUEST - alte create_challenge-Signatur entfernen
--
--  20260724120100 hat create_challenge um p_daily_allowance erweitert
--  (Negativ-Quests). Postgres behandelt das als NEUE Funktion, weil sich
--  die Argumentliste aendert - die 14-stellige Variante blieb daneben
--  bestehen.
--
--  Auf den bestehenden Datenbanken war das nie zu sehen, weil die alte
--  Variante dort per Hand entfernt wurde. Eine frisch aus diesen
--  Migrationen gebaute Datenbank hatte dagegen beide, und jeder Aufruf
--  ohne vollstaendige Parameterliste scheiterte mit:
--
--      ERROR: function public.create_challenge(...) is not unique
--
--  Aufgefallen beim Neuaufbau auf dem NAS.
-- =================================================================

drop function if exists public.create_challenge(
  text, integer, integer, integer, integer, date, text, text,
  integer, text, text, numeric, text, boolean
);
