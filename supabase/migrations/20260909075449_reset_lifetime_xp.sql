CREATE OR REPLACE FUNCTION public.reset_my_stats()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
begin
  perform public.lock_game_state();
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  if exists(select 1 from public.challenge_participants where user_id=v_user_id and status='active')
    or exists(select 1 from public.duels where v_user_id in (challenger_id,opponent_id) and status='pending') then
    raise exception 'Finish or leave active quests and settle pending duels before resetting stats.';
  end if;
  delete from public.player_xp_events where user_id = v_user_id;
  -- 1. Delete all check-ins for this user
  delete from public.check_ins where user_id = v_user_id;

  -- 2. Delete all benefit purchases for this user
  delete from public.benefit_purchases where user_id = v_user_id;

  -- 3. Reset the challenge aura balance for this user in all participants
  update public.challenge_participants
  set challenge_aura = 0
  where user_id = v_user_id;
end;
$function$
;

