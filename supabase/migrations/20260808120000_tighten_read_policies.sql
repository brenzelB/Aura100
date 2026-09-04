-- =================================================================
--  AURA QUEST - Lesezugriff einschraenken
--
--  Bisher galt fuer challenges und challenge_participants eine
--  SELECT-Policy mit `using (true)` fuer alle angemeldeten Nutzer. Wer
--  ein Konto hatte, konnte damit JEDE Quest im System lesen - Titel und
--  Beschreibung inklusive. Quest-Titel sind aber selten neutral:
--  "Nicht mehr rauchen", "Therapie-Hausaufgaben", "Keinen Alkohol".
--
--  Ohne Konto war ohnehin nichts lesbar (geprueft), das hier schliesst
--  die Luecke zwischen registrierten Nutzern.
--
--  ZWEI FALLEN, DIE DEN NAIVEN ANSATZ VERHINDERN:
--
--  1. REKURSION. Die Regel fuer challenge_participants muesste lauten
--     "sichtbar, wenn ich in derselben Quest bin" - und dafuer
--     challenge_participants abfragen, waehrend RLS auf genau dieser
--     Tabelle ausgewertet wird. Postgres bricht das ab. Deshalb eine
--     SECURITY-DEFINER-Funktion, die RLS umgeht.
--
--  2. EINLADUNGEN. Wer eingeladen wird, ist noch KEIN Teilnehmer, muss
--     den Quest-Titel aber sehen, um die Einladung beurteilen zu
--     koennen. Eine Regel "nur eigene Quests" verwandelt jede Einladung
--     in eine leere Karte.
--
--  profiles bleibt absichtlich offen: Die Freundessuche per
--  Benutzername braucht es, und dort stehen nur Name und Avatar - keine
--  Mailadresse, kein Spielstand.
-- =================================================================

-- ── Hilfsfunktion ────────────────────────────────────────────────
--
--  SECURITY DEFINER laeuft mit den Rechten des Eigentuemers und
--  umgeht damit RLS - genau das bricht die Rekursion. Sie gibt nur
--  wahr/falsch zurueck, gibt also keine Daten preis.

create or replace function public.is_quest_member(p_challenge_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.challenge_participants
    where challenge_id = p_challenge_id
      and user_id = (select auth.uid())
  );
$$;

-- Auch Zuschauer und Ausgeschiedene zaehlen als Mitglied: Sie duerfen
-- die Quest weiterhin sehen, nur nichts mehr eintragen. Der Status wird
-- hier bewusst NICHT geprueft.

create or replace function public.is_quest_invitee(p_challenge_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.invites
    where challenge_id = p_challenge_id
      and invitee_id = (select auth.uid())
      and status = 'pending'
  );
$$;

grant execute on function public.is_quest_member(uuid) to authenticated;
grant execute on function public.is_quest_invitee(uuid) to authenticated;

-- ── challenges ───────────────────────────────────────────────────

drop policy if exists "challenges: signed-in users can read" on public.challenges;

create policy "challenges: members and invitees can read"
  on public.challenges for select
  to authenticated
  using (
    public.is_quest_member(id)
    or public.is_quest_invitee(id)
  );

-- ── challenge_participants ───────────────────────────────────────

drop policy if exists "participants: signed-in users can read"
  on public.challenge_participants;

create policy "participants: co-members can read"
  on public.challenge_participants for select
  to authenticated
  using (
    -- Die eigene Zeile immer, auch bevor die Hilfsfunktion greift.
    user_id = (select auth.uid())
    or public.is_quest_member(challenge_id)
  );

-- ── benefits ─────────────────────────────────────────────────────
--
--  Shop-Bestand ist pro Quest angelegt. Fremde Bestaende zu lesen
--  verraet zwar nichts Persoenliches, gehoert aber ebenso wenig
--  jedem - und die Einschraenkung kostet nichts.

drop policy if exists "benefits: signed-in users can read" on public.benefits;

create policy "benefits: members can read"
  on public.benefits for select
  to authenticated
  using (public.is_quest_member(challenge_id));
