-- Synthetic NAS test container only. Every fixture rolls back.
begin;
select no_plan();
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-0000-0000-000000000011','balance-a@example.invalid','{"username":"balance_alice"}'),
 ('00000000-0000-0000-0000-000000000012','balance-b@example.invalid','{"username":"balance_bob"}'),
 ('00000000-0000-0000-0000-000000000013','balance-c@example.invalid','{"username":"balance_carol"}');
create table public.balance_test_quests(n integer,q uuid);
grant select on public.balance_test_quests to authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000011',true);
insert into public.balance_test_quests select 1,public.create_challenge('Classic test',30,999,999,p_balance_preset=>'classic');
insert into public.balance_test_quests select 2,public.create_challenge('Chill test',30,999,999,p_balance_preset=>'chill');
insert into public.balance_test_quests select 3,public.create_challenge('Chaos test',30,999,999,p_balance_preset=>'chaos');
insert into public.balance_test_quests select n,public.create_challenge('Custom test '||n,30,case when n=7 then 10000 else 100 end,25,p_max_strikes=>3) from generate_series(4,8)n;
create function pg_temp.q(i integer) returns uuid language sql as $$ select q from public.balance_test_quests where n=i $$;
select is((select aura_gain from public.challenges where id=pg_temp.q(1)),100,'Classic reward canonical, client cannot override preset');
select is((select aura_penalty from public.challenges where id=pg_temp.q(1)),25,'Classic penalty 25');
select is((select max_strikes from public.challenges where id=pg_temp.q(1)),3,'Classic allows three misses');
select is((select max_strikes from public.challenges where id=pg_temp.q(2)),5,'Chill allows five misses');
select ok(not (select attacks_enabled from public.challenges where id=pg_temp.q(2)),'Chill disables attacks');
select is((select aura_penalty from public.challenges where id=pg_temp.q(3)),50,'Chaos penalty 50');
select is((select cost from public.benefits where challenge_id=pg_temp.q(1) and title='Aura Heist'),20,'Classic heist entry price 20');
select is((select cost from public.benefits where challenge_id=pg_temp.q(7) and title='Aura Ward'),2500,'Custom reward scales ward price');
select is(public.balance_price(1,'Aura Heist',1),1,'Low prices round up, never free');
select is(public.balance_price(100,'Aura Heist',3),60,'75% tier costs 60');
select is(public.balance_price(100,'Streak Shield'),100,'Shield costs one base reward');
set local role authenticated;
select throws_ok($$select public.create_challenge('Backdate',30,100,25,p_starts_on=>current_date-1)$$,'P0001',null,'New quests cannot backdate XP');
select throws_ok($$insert into public.player_xp_events values(auth.uid(),pg_temp.q(1),current_date,100,now())$$,'42501',null,'Client cannot mint XP');
select throws_ok($$select public.balance_price(100,'Aura Heist',1)$$,'42501',null,'Internal helper not client executable');
select lives_ok($$select public.log_check_in(pg_temp.q(1))$$,'Confirmed Classic unit');
select is((select lifetime_xp from public.get_my_stats()),100::bigint,'One unit awards 100 permanent XP');
select throws_ok($$select public.log_check_in(pg_temp.q(1))$$,'P0001',null,'Duplicate unit rejected');
select lives_ok($$select public.log_check_in(pg_temp.q(n)) from generate_series(2,7)n$$,'Six further confirmations');
select is((select lifetime_xp from public.get_my_stats()),500::bigint,'Daily XP cap independent of high custom reward');
select lives_ok($$select public.purchase_benefit((select id from public.benefits where challenge_id=pg_temp.q(7) and title='Aura Ward'))$$,'Ward purchase uses Aura');
select is((select lifetime_xp from public.get_my_stats()),500::bigint,'Purchase does not lower XP');
reset role;
delete from public.check_ins where challenge_id=pg_temp.q(7);
insert into public.check_ins(challenge_id,user_id) values(pg_temp.q(7),'00000000-0000-0000-0000-000000000011');
select is((select sum(xp) from public.player_xp_events where user_id='00000000-0000-0000-0000-000000000011'),500::bigint,'Deleted and reinserted confirmation cannot farm XP');
delete from public.challenges where id=pg_temp.q(7);
select is((select sum(xp) from public.player_xp_events where user_id='00000000-0000-0000-0000-000000000011'),500::bigint,'Quest deletion retains permanent XP');

insert into public.challenge_participants(challenge_id,user_id,challenge_aura)
select q,u,2000 from public.balance_test_quests cross join (values('00000000-0000-0000-0000-000000000012'::uuid),('00000000-0000-0000-0000-000000000013'::uuid)) users(u) where n<>7;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000012',true);
set local role authenticated;
select is((select count(*) from public.player_xp_events),0::bigint,'RLS hides another player XP ledger');
select throws_ok($$select public.attempt_aura_heist(pg_temp.q(2),'00000000-0000-0000-0000-000000000013',1)$$,'P0001',null,'Chill rejects attacks on server');
select lives_ok($$select public.purchase_benefit((select id from public.benefits where challenge_id=pg_temp.q(1) and title='Aura Ward'))$$,'Defender equips a ward');
reset role;
insert into public.aura_heists(challenge_id,attacker_id,target_id,cost,chance,succeeded)
values(pg_temp.q(1),'00000000-0000-0000-0000-000000000013','00000000-0000-0000-0000-000000000012',20,0.25,true);
set local role authenticated;
select is(public.log_check_in(pg_temp.q(1)),100,'Ward preserves complete Aura reward');
select is((select lifetime_xp from public.get_my_stats()),100::bigint,'Defended unit still grants XP');
reset role;
select is((select count(*) from public.benefit_purchases bp join public.benefits b on b.id=bp.benefit_id where bp.user_id='00000000-0000-0000-0000-000000000012' and b.title='Aura Ward' and bp.consumed_at is not null),1::bigint,'Exactly one ward consumed');
select is((select stolen_amount from public.aura_heists where challenge_id=pg_temp.q(1)),0,'Blocked heist transfers no Aura');
-- Legacy pending hits across quests cannot bypass the daily payout ceiling.
insert into public.aura_heists(challenge_id,attacker_id,target_id,cost,chance,succeeded,created_at)
select pg_temp.q(n),'00000000-0000-0000-0000-000000000013','00000000-0000-0000-0000-000000000012',20,0.25,true,now()-interval '1 hour' from generate_series(3,4)n;
insert into public.benefit_purchases(challenge_id,user_id,benefit_id)
select pg_temp.q(3),'00000000-0000-0000-0000-000000000012',id from public.benefits where challenge_id=pg_temp.q(3) and title='Aura Lord';
set local role authenticated;
select is(public.log_check_in(pg_temp.q(3)),100,'Heist steals only base 100; defender keeps multiplier bonus 100');
select is(public.log_check_in(pg_temp.q(4)),100,'Second legacy pending hit cannot steal again today');
select is((select lifetime_xp from public.get_my_stats()),300::bigint,'Heists never remove or scale earned XP');
reset role;
select is((select count(*) from public.aura_heists where target_id='00000000-0000-0000-0000-000000000012' and stolen_amount>0),1::bigint,'Global one paid incoming heist per day');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000011',true);
update public.challenge_participants set challenge_aura=2000 where user_id='00000000-0000-0000-0000-000000000011';
set local role authenticated;
select throws_ok($$select public.attempt_aura_heist(pg_temp.q(5),'00000000-0000-0000-0000-000000000012',1)$$,'P0001',null,'Incoming protection applies across quests');
select lives_ok($$select public.send_targeted_roast(pg_temp.q(1),'00000000-0000-0000-0000-000000000013','Test roast',3)$$,'First outgoing attack');
select lives_ok($$select public.send_targeted_roast(pg_temp.q(3),'00000000-0000-0000-0000-000000000013','Test roast',5)$$,'Second outgoing attack in another quest');
select lives_ok($$select public.cast_blackout(pg_temp.q(4),'00000000-0000-0000-0000-000000000013','evening')$$,'Third outgoing attack with another type');
select throws_ok($$select public.send_targeted_roast(pg_temp.q(5),'00000000-0000-0000-0000-000000000013','Test roast',3)$$,'P0001',null,'Fourth attack rejected across quest and type');
reset role;
select is((select challenge_aura from public.challenge_participants where challenge_id=pg_temp.q(1) and user_id='00000000-0000-0000-0000-000000000011'),1950,'Roast costs half a base reward');
insert into public.settlement_events(user_id,challenge_id,kind,amount,period_start)
values('00000000-0000-0000-0000-000000000011',pg_temp.q(8),'penalty',-25,current_date-1);
select ok((select comeback_needed from public.challenge_participants where challenge_id=pg_temp.q(8) and user_id='00000000-0000-0000-0000-000000000011'),'Miss creates comeback goal');
set local role authenticated;
select lives_ok($$select public.log_check_in(pg_temp.q(8))$$,'Next unit completes comeback');
reset role;
select ok(not (select comeback_needed from public.challenge_participants where challenge_id=pg_temp.q(8) and user_id='00000000-0000-0000-0000-000000000011'),'Comeback clears even when XP daily cap reached');
-- Actual tier RPC, expiry and zero-reward guards.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000012',true);
set local role authenticated;
select is((public.attempt_aura_heist(pg_temp.q(5),'00000000-0000-0000-0000-000000000011',1)->>'cost')::int,20,'Actual heist RPC derives price from tier');
select throws_ok($$select public.attempt_aura_heist(pg_temp.q(5),'00000000-0000-0000-0000-000000000011',150)$$,'P0001',null,'Old client cost is not accepted as a tier');
reset role;
insert into public.aura_heists(challenge_id,attacker_id,target_id,cost,chance,succeeded,created_at)
values(pg_temp.q(6),'00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000012',20,0.25,true,now()-interval '25 hours');
set local role authenticated;
select is(public.log_check_in(pg_temp.q(6)),100,'Expired pending heist cannot steal a later unit');
reset role;
update public.challenges set aura_gain=0 where id=pg_temp.q(8);
set local role authenticated;
select throws_ok($$select public.purchase_benefit((select id from public.benefits where challenge_id=pg_temp.q(8) and title='Aura Ward'))$$,'P0001',null,'Zero-reward shop rejects purchases');
select throws_ok($$select public.send_targeted_roast(pg_temp.q(8),'00000000-0000-0000-0000-000000000013','Test',3)$$,'P0001',null,'Zero-reward quest rejects attacks');
reset role;
-- Real settlement verifies that allowed misses means failure on the NEXT miss.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000011',true);
insert into public.balance_test_quests select n,public.create_challenge('Miss boundary '||n,30,100,25,p_balance_preset=>'classic') from generate_series(9,10)n;
update public.challenges c set starts_on=current_date-(n-6),created_at=(current_date-(n-6))::timestamptz from public.balance_test_quests q where c.id=q.q and n in(9,10);
update public.challenge_participants cp set created_at=c.created_at,challenge_aura=500 from public.challenges c where cp.challenge_id=c.id and c.id in(pg_temp.q(9),pg_temp.q(10));
select public.settle_periods();
select is((select strikes_used from public.challenge_participants where challenge_id=pg_temp.q(9)),3,'Three misses consume three allowed strikes');
select is((select status from public.challenge_participants where challenge_id=pg_temp.q(9)),'active','Classic survives three misses');
select is((select challenge_aura from public.challenge_participants where challenge_id=pg_temp.q(9)),425,'Three Classic penalties cost exactly 75 Aura');
select is((select status from public.challenge_participants where challenge_id=pg_temp.q(10)),'failed','Fourth miss ends Classic run');
-- Explicit life-stats reset also removes permanent XP.
update public.challenge_participants set status='completed' where user_id='00000000-0000-0000-0000-000000000012';
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000012',true);
set local role authenticated;
select lives_ok('select public.reset_my_stats()','Inactive player can reset ordinary stats');
select is((select lifetime_xp from public.get_my_stats()),0::bigint,'Stats reset clears lifetime XP');
reset role;
select * from finish();
rollback;

