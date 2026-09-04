-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST - profile: reset player stats
-- ═════════════════════════════════════════════════════════════════

create or replace function public.reset_my_stats()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  -- 1. Delete all check-ins for this user
  delete from public.check_ins where user_id = v_user_id;

  -- 2. Delete all benefit purchases for this user
  delete from public.benefit_purchases where user_id = v_user_id;

  -- 3. Reset the challenge aura balance for this user in all participants
  update public.challenge_participants
  set challenge_aura = 0
  where user_id = v_user_id;
end;
$$;

revoke execute on function public.reset_my_stats() from public, anon;
grant execute on function public.reset_my_stats() to authenticated;
