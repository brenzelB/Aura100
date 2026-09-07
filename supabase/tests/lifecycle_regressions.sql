begin;
select no_plan();
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-0000-0000-000000000001','rules-a@example.invalid','{"username":"abcdefghijklmnopqrst"}'),
 ('00000000-0000-0000-0000-000000000002','rules-b@example.invalid','{"username":"abcdefghijklmnopqrst"}'),
 ('00000000-0000-0000-0000-000000000003','rules-c@example.invalid','{"username":"rules_charlie"}');
select is((select count(*) from public.profiles where id in (
 '00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002',
 '00000000-0000-0000-0000-000000000003')),3::bigint,'duplicate 20 character signup succeeds');
select ok((select bool_and(length(username)<=24) from public.profiles),'all signup names satisfy length constraint');
create function pg_temp.quest(n integer, goal text default 'check') returns uuid language plpgsql as $$
declare q uuid := ('10000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid;
begin
 insert into public.challenges(id,creator_id,title,starts_on,duration_days,aura_gain,aura_penalty,max_strikes,goal_type,target_value,unit,is_endless)
 values(q,'00000000-0000-0000-0000-000000000001','Rule test',current_date,30,100,50,0,goal,
 case when goal='progress' then 100 end,case when goal='progress' then 'reps' end,true);
 insert into public.challenge_participants(challenge_id,user_id,challenge_aura) values(q,'00000000-0000-0000-0000-000000000001',500);
 return q;
end $$;
select pg_temp.quest(1,'avoid'),pg_temp.quest(2,'avoid'),pg_temp.quest(3),pg_temp.quest(4,'progress');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select lives_ok($$select public.log_slip('10000000-0000-0000-0000-000000000001')$$,'zero-budget avoid slip can finish');
reset role;
select is((select status from public.challenge_participants where challenge_id='10000000-0000-0000-0000-000000000001'),'failed','first strike exceeds zero budget');
select is((select challenge_aura from public.challenge_participants where challenge_id='10000000-0000-0000-0000-000000000001'),112,'failure preserves quarter of balance AFTER penalty');
select is((select amount from public.settlement_events where challenge_id='10000000-0000-0000-0000-000000000001' and kind='failed'),112,'failure event agrees with balance');
select public.settle_periods(); select public.settle_periods();
select is((select count(*) from public.settlement_events where challenge_id='10000000-0000-0000-0000-000000000001' and kind='failed'),1::bigint,'failure booked once');
insert into public.benefits(challenge_id,title,cost,description) values('10000000-0000-0000-0000-000000000002','Streak Shield',300,'test');
insert into public.benefit_purchases(challenge_id,user_id,benefit_id)
 select challenge_id,'00000000-0000-0000-0000-000000000001',id from public.benefits where challenge_id='10000000-0000-0000-0000-000000000002' and title='Streak Shield';
set local role authenticated;
select lives_ok($$select public.log_slip('10000000-0000-0000-0000-000000000002')$$,'shielded slip works');
select throws_ok('select public.reset_my_stats()','P0001',null,'cannot reset an active competition');
select throws_ok($$update public.challenge_participants set challenge_aura=999999$$,'42501',null,'direct aura manipulation denied');
reset role;
select is((select status from public.challenge_participants where challenge_id='10000000-0000-0000-0000-000000000002'),'active','shield prevents elimination');
select is((select strikes_used from public.challenge_participants where challenge_id='10000000-0000-0000-0000-000000000002'),0,'shield absorbs the strike');

insert into public.progress_entries(challenge_id,user_id,amount,period_start)
 select '10000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001',1,current_date from generate_series(1,1205);
set local role authenticated;
select is(public.get_my_period_totals()->'10000000-0000-0000-0000-000000000004'->>'progress','1205.00','server aggregate includes more than 1000 entries');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
set local role authenticated;
select is(public.get_my_period_totals(),'{}'::jsonb,'aggregate exposes only own memberships');
reset role;

-- LMS invitation remains pending while other two players start.
update public.challenges set mode='last_man_standing',lifecycle='active' where id='10000000-0000-0000-0000-000000000003';
insert into public.challenge_participants(challenge_id,user_id) values('10000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000002');
insert into public.invites(id,challenge_id,inviter_id,invitee_id) values
 ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
set local role authenticated;
select throws_ok($$select public.respond_to_invite('30000000-0000-0000-0000-000000000001',true)$$,'P0001',null,'late LMS invite cannot alter roster');
reset role;

-- Preserve another player's archive and refund their pending escrow.
update public.challenges set mode='solo',is_endless=false where id='10000000-0000-0000-0000-000000000003';
update public.challenge_participants set status='completed',challenge_aura=500 where challenge_id='10000000-0000-0000-0000-000000000003';
insert into public.duels(challenge_id,challenger_id,opponent_id,stake) values
 ('10000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001',50);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select lives_ok('select public.delete_my_account()','creator account deletion succeeds');
reset role;
select is((select creator_id::text from public.challenges where id='10000000-0000-0000-0000-000000000003'),'00000000-0000-0000-0000-000000000002','archive ownership handed over');
select is((select challenge_aura from public.challenge_participants where challenge_id='10000000-0000-0000-0000-000000000003'),550,'other trophy retained and escrow refunded once');
select * from finish();
rollback;
