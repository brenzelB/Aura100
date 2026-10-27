begin;
select no_plan();
insert into auth.users(id,email,raw_user_meta_data) values
 ('b0270000-0000-0000-0000-000000000001','bonus-test@example.invalid','{"username":"bonus_test"}');
create function pg_temp.bonus_quest(n integer, mode text, goal text default 'check', period text default 'weekly')
returns uuid language plpgsql as $$
declare q uuid := ('b0270000-0000-0000-0001-'||lpad(n::text,12,'0'))::uuid;
  t date := (now() at time zone 'utc')::date;
begin
 insert into public.challenges(id,creator_id,title,starts_on,duration_days,aura_gain,aura_penalty,max_strikes,
   mode,goal_type,target_value,unit,is_endless,checkin_period,checkins_per_period,created_at)
 values(q,'b0270000-0000-0000-0000-000000000001','Bonus regression',t-3,30,100,25,3,
   mode,goal,case when goal='progress' then 100 end,case when goal='progress' then 'reps' end,
   mode='last_man_standing',period,3,now()-interval '4 days');
 insert into public.challenge_participants(challenge_id,user_id,challenge_aura,created_at)
 values(q,'b0270000-0000-0000-0000-000000000001',500,now()-interval '4 days');
 if goal='check' then
   insert into public.check_ins(challenge_id,user_id,checked_on) select q,'b0270000-0000-0000-0000-000000000001',t-d from generate_series(1,3) d;
 elsif goal='progress' then
   insert into public.progress_entries(challenge_id,user_id,amount,period_start) values(q,'b0270000-0000-0000-0000-000000000001',100,t-3);
   insert into public.check_ins(challenge_id,user_id,checked_on) values(q,'b0270000-0000-0000-0000-000000000001',t-1);
 end if;
 return q;
end $$;
select pg_temp.bonus_quest(1,'solo'),pg_temp.bonus_quest(2,'coop'),pg_temp.bonus_quest(3,'versus'),pg_temp.bonus_quest(4,'last_man_standing'),
 pg_temp.bonus_quest(5,'solo','check','monthly'),pg_temp.bonus_quest(6,'solo','progress'),pg_temp.bonus_quest(7,'solo','avoid'),
 pg_temp.bonus_quest(8,'solo','check','daily');
select set_config('request.jwt.claim.sub','b0270000-0000-0000-0000-000000000001',true);
create temporary table xp_before as select count(*) n from public.player_xp_events where user_id='b0270000-0000-0000-0000-000000000001';
set local role authenticated;
select is(public.log_check_in(('b0270000-0000-0000-0001-'||lpad(n::text,12,'0'))::uuid),0,'optional bonus works in mode '||n) from generate_series(1,5) n;
select throws_ok($$select public.log_check_in('b0270000-0000-0000-0001-000000000001')$$,'P0001','Already checked in today - come back tomorrow!','same-day bonus cannot be duplicated');
select is(public.add_progress('b0270000-0000-0000-0001-000000000006',10)->>'overshoot','true','progress after goal is bonus');
select lives_ok($$select public.add_progress('b0270000-0000-0000-0001-000000000006',5)$$,'multiple progress amounts do not duplicate the bonus day');
select throws_ok($$select public.log_check_in('b0270000-0000-0000-0001-000000000007')$$,'P0001','Avoid successes are recorded by settlement only.','avoid does not invite fake successful ticks');
reset role;
select is((select count(*) from public.check_ins where user_id='b0270000-0000-0000-0000-000000000001' and is_bonus),6::bigint,'one bonus marker per extra day across modes and progress');
select is((select count(*) from public.player_xp_events where user_id='b0270000-0000-0000-0000-000000000001'),(select n from xp_before),'bonus gives no permanent XP');
select ok((select bool_and(challenge_aura=500) from public.challenge_participants where user_id='b0270000-0000-0000-0000-000000000001'),'bonus does not change Aura');
select is((select count(*) from public.check_ins where challenge_id='b0270000-0000-0000-0001-000000000006' and is_bonus),1::bigint,'progress creates only one extra calendar marker');
-- A short final week stays playable even after all required check-ins.
update public.challenges set duration_days=7 where id='b0270000-0000-0000-0001-000000000001';
select public.settle_periods();
select is((select status from public.challenge_participants where challenge_id='b0270000-0000-0000-0001-000000000001'),'active','last weekly goal stays open until its actual end');
select set_config('request.jwt.claim.sub','b0270000-0000-0000-0000-000000000001',true);
set local role authenticated;
select is(public.log_check_in('b0270000-0000-0000-0001-000000000008'),100,'daily target resets normally');
select throws_ok($$select public.log_check_in('b0270000-0000-0000-0001-000000000008')$$,'P0001','Already checked in today - come back tomorrow!','daily quest still has one tick per day');
select throws_ok($$insert into public.check_ins(challenge_id,user_id,is_bonus) values('b0270000-0000-0000-0001-000000000007','b0270000-0000-0000-0000-000000000001',false)$$,'42501',null,'clients cannot forge reward-bearing check-ins');
reset role;
select * from finish();
rollback;
