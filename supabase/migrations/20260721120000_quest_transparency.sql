-- =================================================================
--  AURA QUEST - quest transparency
--
--  Inside a quest, the party now sees everything about THAT quest:
--  each other's progress towards the target, and each other's wins
--  and losses (check-ins, strikes, penalties, shields, failures,
--  completions, milestones, duels).
--
--  Scope is deliberately tight: only members of the same quest, and
--  only for that quest's rows. The personal Home feed is unaffected
--  because it filters on user_id explicitly.
-- =================================================================

drop policy "events: users read their own" on public.settlement_events;

create policy "events: quest members read each other"
  on public.settlement_events for select
  to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.challenge_participants me
      where me.challenge_id = settlement_events.challenge_id
        and me.user_id = (select auth.uid())
    )
  );
