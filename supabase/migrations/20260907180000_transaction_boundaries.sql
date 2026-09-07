-- All economy/roster mutations acquire the same transaction lock BEFORE row
-- locks. This small self-hosted game's transactions touch multiple participants,
-- duels, and occasionally every quest. A single order prevents lost balances
-- and cycles between settlement, progress edits, purchases and account removal.
-- Read-only requests remain concurrent. Shard by quest only after replacing
-- global settlement calls inside user actions with a per-quest engine.
create or replace function public.lock_game_state()
returns void language sql volatile set search_path = '' as $$
 select pg_advisory_xact_lock(104857601::bigint);
$$;
revoke all on function public.lock_game_state() from public,anon,authenticated;
do $$
declare r record; definition text;
begin
 for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname = any(array[
    'create_challenge','start_quest','leave_challenge','respond_to_invite','invite_to_challenge',
    'log_check_in','add_progress','edit_progress_entry','delete_progress_entry',
    'log_slip','undo_last_slip','purchase_benefit','send_targeted_roast','attempt_aura_heist',
    'cast_blackout','create_duel','respond_to_duel','expire_duels','settle_periods',
    'delete_my_account','reset_my_stats','block_user'])
 loop
   definition:=pg_get_functiondef(r.oid);
   if position('perform public.lock_game_state();' in definition)=0 then
     definition:=regexp_replace(definition,E'\nbegin\n',E'\nbegin\n  perform public.lock_game_state();\n','i');
     execute definition;
   end if;
 end loop;
end $$;

-- A statistics reset cannot rewrite a competition that is still running.
-- Keep the user's existing reset semantics for archived activity.
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.reset_my_stats()'::regprocedure);
 definition:=replace(definition,'  -- 1. Delete all check-ins for this user',
 $guard$  if exists(select 1 from public.challenge_participants where user_id=v_user_id and status='active')
    or exists(select 1 from public.duels where v_user_id in (challenger_id,opponent_id) and status='pending') then
    raise exception 'Finish or leave active quests and settle pending duels before resetting stats.';
  end if;
  -- 1. Delete all check-ins for this user$guard$);
 execute definition;
end $$;

-- A current blackout must not block the engine's already completed avoid period.
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.reject_if_blacked_out()'::regprocedure);
 definition:=replace(definition,'  select b.ends_at into v_ends_at',
 $guard$  if tg_table_name='check_ins' then
    if new.checked_on < (now() at time zone 'utc')::date and exists(
      select 1 from public.challenges where id=new.challenge_id and goal_type='avoid') then
      return new;
    end if;
  end if;
  select b.ends_at into v_ends_at$guard$);
 execute definition;
end $$;

create or replace function public.reminder_due_at(p_now timestamptz,p_time time,p_offset integer)
returns timestamp language sql immutable set search_path = '' as $$
 select local_now::date+p_time-case when local_now::time<p_time then interval '1 day' else interval '0 days' end
 from (select (p_now at time zone 'utc')+make_interval(mins=>p_offset) local_now) t;
$$;
revoke all on function public.reminder_due_at(timestamptz,time,integer) from public,anon,authenticated;
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.send_due_reminders()'::regprocedure);
 definition:=replace(definition,'  v_due     timestamp;',E'  v_due     timestamp;\n  v_quest_today date := (now() at time zone ''utc'')::date;');
 definition:=replace(definition,'    v_due   := v_today + rec.remind_at;',
   E'    v_due := public.reminder_due_at(now(),rec.remind_at,rec.offset_min);\n    v_today := v_due::date;');
 definition:=replace(definition,'extract(isodow from v_local)','extract(isodow from v_quest_today)');
 definition:=replace(definition,'if v_today < rec.starts_on','if v_quest_today < rec.starts_on');
 definition:=replace(definition,'and v_today >= rec.starts_on','and v_quest_today >= rec.starts_on');
 definition:=replace(definition,'((v_today - rec.starts_on)','((v_quest_today - rec.starts_on)');
 definition:=replace(definition,'else v_today','else v_quest_today');
 execute definition;
end $$;
