begin;
select no_plan();
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-0000-0000-000000000001','duel-a@example.invalid','{"username":"duel_alice"}'),
 ('00000000-0000-0000-0000-000000000002','duel-b@example.invalid','{"username":"duel_bob"}');
insert into public.challenges(id,creator_id,title,starts_on,duration_days,aura_gain,aura_penalty,max_strikes)
 values('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Duel test',current_date,30,100,50,3);
insert into public.challenge_participants(challenge_id,user_id,challenge_aura) values
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',450),
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002',500);
insert into public.duels(id,challenge_id,challenger_id,opponent_id,stake,expires_at) values
 ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002',50,now()-interval '1 minute');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
set local role authenticated;
select is(public.respond_to_duel('20000000-0000-0000-0000-000000000001',true)->>'status','expired','expiry returns without rolling back refund');
reset role;
select is((select challenge_aura from public.challenge_participants where user_id='00000000-0000-0000-0000-000000000001'),500,'expired escrow refunded');
select public.expire_duels();
select is((select challenge_aura from public.challenge_participants where user_id='00000000-0000-0000-0000-000000000001'),500,'cron cannot refund twice');
update public.duels set status='pending',expires_at=now()+interval '1 day'
 where id='20000000-0000-0000-0000-000000000001';
update public.challenge_participants set challenge_aura=450 where user_id='00000000-0000-0000-0000-000000000001';
insert into public.user_blocks(blocker_id,blocked_id) values('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001');
set local role authenticated;
select is(public.respond_to_duel('20000000-0000-0000-0000-000000000001',true)->>'status','declined','old duel cannot bypass a later block');
reset role;
select is((select challenge_aura from public.challenge_participants where user_id='00000000-0000-0000-0000-000000000001'),500,'blocked duel returns escrow');
select is((select challenge_aura from public.challenge_participants where user_id='00000000-0000-0000-0000-000000000002'),500,'blocked opponent loses no aura');
select * from finish();
rollback;
