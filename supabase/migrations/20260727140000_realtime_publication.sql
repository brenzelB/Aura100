-- =================================================================
--  AURA QUEST - push instead of poll
--
--  The app refreshed itself with two 8-second timers: one on Home and
--  one on the quest detail screen, each invalidating several providers
--  per tick. Idle that is roughly 20-50 requests per minute PER OPEN
--  APP, whether or not anything changed — untenable once real users
--  arrive, and billed per request on a managed backend.
--
--  Publishing these tables lets clients subscribe to the rows that
--  concern them and refetch only when something actually happened. The
--  timers stay as a slow safety net (see RealtimeSync in the client).
--
--  Row Level Security still applies to realtime: a subscriber only ever
--  receives rows their SELECT policy already allows.
-- =================================================================

do $$
declare
  t text;
  wanted text[] := array[
    'targeted_roasts',        -- an incoming roast must lock the screen now
    'nudges',                 -- pokes, and the reaction coming back
    'aura_heists',            -- "you got robbed" the moment it resolves
    'duels',                  -- someone challenges you
    'settlement_events',      -- penalties, strikes, clean-period payouts
    'challenge_participants', -- aura and strike balances
    'check_ins',              -- party progress
    'progress_entries',
    'slips'
  ];
begin
  foreach t in array wanted loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
