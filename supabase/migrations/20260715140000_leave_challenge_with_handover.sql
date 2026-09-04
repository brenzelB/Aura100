-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST - leaving a quest hands ownership over
--
--  Leaving used to be a plain DELETE from the client. If the OWNER
--  left, the quest kept pointing at someone who was gone: nobody
--  could ever invite again. Now one RPC does both atomically:
--  remove the participant AND pass the crown to the longest-standing
--  remaining member.
--
--  SECURITY DEFINER is required (not just convenient): the RLS policy
--  "challenges: creator can update" has WITH CHECK (auth.uid() =
--  creator_id), so the departing owner could never set creator_id to
--  somebody else. Safe as always: the acting user comes only from
--  auth.uid(), search_path is pinned, EXECUTE is restricted.
-- ═════════════════════════════════════════════════════════════════

create or replace function public.leave_challenge(p_challenge_id uuid)
returns text  -- username of the new owner, or null if none/not owner
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id        uuid := (select auth.uid());
  v_participant_id uuid;
  v_creator_id     uuid;
  v_successor      uuid;
  v_successor_name text;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select id into v_participant_id
  from public.challenge_participants
  where challenge_id = p_challenge_id
    and user_id = v_user_id
  for update;
  if not found then
    raise exception 'You are not part of this quest.';
  end if;

  select creator_id into v_creator_id
  from public.challenges
  where id = p_challenge_id
  for update;

  delete from public.challenge_participants where id = v_participant_id;

  -- Only the owner needs a successor.
  if v_creator_id is distinct from v_user_id then
    return null;
  end if;

  -- The longest-standing active member inherits the quest.
  select cp.user_id, p.username
  into v_successor, v_successor_name
  from public.challenge_participants cp
  join public.profiles p on p.id = cp.user_id
  where cp.challenge_id = p_challenge_id
    and cp.status = 'active'
  order by cp.created_at asc
  limit 1;

  if not found then
    -- Last one out: creator_id stays as-is (historical record).
    return null;
  end if;

  update public.challenges
  set creator_id = v_successor
  where id = p_challenge_id;

  return v_successor_name;
end;
$$;

revoke execute on function public.leave_challenge(uuid) from public, anon;
grant execute on function public.leave_challenge(uuid) to authenticated;

-- The direct client DELETE is no longer the way out: revoke it so
-- leaving always goes through the handover logic above.
drop policy "participants: user can leave" on public.challenge_participants;
revoke delete on public.challenge_participants from authenticated;
