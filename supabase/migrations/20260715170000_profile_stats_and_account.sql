-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST - profile: player stats + account deletion
-- ═════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────
-- 1. GET_MY_STATS - lifetime numbers for the profile screen.
--    STABLE + INVOKER: pure reads, the user's own RLS applies.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.get_my_stats()
returns table (
  quests_joined  integer,
  active_quests  integer,
  total_checkins integer,
  total_aura     integer,
  gear_owned     integer,
  friends        integer
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  return query
  select
    (select count(*)::int from public.challenge_participants
      where user_id = v_user_id),
    (select count(*)::int from public.challenge_participants
      where user_id = v_user_id and status = 'active'),
    (select count(*)::int from public.check_ins
      where user_id = v_user_id),
    -- Aura lives per quest; the profile shows the sum as a "net worth".
    (select coalesce(sum(challenge_aura), 0)::int
      from public.challenge_participants where user_id = v_user_id),
    (select count(*)::int from public.benefit_purchases
      where user_id = v_user_id),
    (select count(*)::int from public.friendships
      where status = 'accepted'
        and (requester_id = v_user_id or addressee_id = v_user_id));
end;
$$;

revoke execute on function public.get_my_stats() from public, anon;
grant execute on function public.get_my_stats() to authenticated;

-- ─────────────────────────────────────────────────────────────────
-- 2. DELETE_MY_ACCOUNT
--
--    Deleting a profile cascades to challenges.creator_id — so a
--    naive delete would wipe out quests OTHER players are still in.
--    Owned quests are therefore handed over first (same rule as
--    leave_challenge: longest-standing member wins); only quests
--    nobody else is in get removed.
--
--    Deleting the auth.users row cascades to profiles, which cascades
--    to participants, check-ins, purchases, invites, nudges and
--    friendships. Requires DEFINER (auth schema is off-limits to
--    normal users); the acting user is always auth.uid().
-- ─────────────────────────────────────────────────────────────────
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id   uuid := (select auth.uid());
  v_quest     record;
  v_successor uuid;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  for v_quest in
    select id from public.challenges where creator_id = v_user_id
  loop
    select cp.user_id into v_successor
    from public.challenge_participants cp
    where cp.challenge_id = v_quest.id
      and cp.user_id <> v_user_id
      and cp.status = 'active'
    order by cp.created_at asc
    limit 1;

    if found then
      update public.challenges
      set creator_id = v_successor
      where id = v_quest.id;
    else
      -- Nobody else in it: the quest goes with the account.
      delete from public.challenges where id = v_quest.id;
    end if;
  end loop;

  delete from auth.users where id = v_user_id;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
