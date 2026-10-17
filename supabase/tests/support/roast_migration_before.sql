-- Isolated restore ONLY, before applying the replacement migration.
insert into auth.users(id,email,raw_user_meta_data) values
 ('72000000-0000-0000-0000-000000000001','migration-a@example.invalid','{"username":"migration_alice"}'),
 ('72000000-0000-0000-0000-000000000002','migration-b@example.invalid','{"username":"migration_bob"}');
insert into public.challenges(id,creator_id,title,starts_on,duration_days,aura_gain,aura_penalty,max_strikes)
 values('72000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','Migration refund fixture',current_date,30,100,25,3);
insert into public.challenge_participants(challenge_id,user_id,challenge_aura) values
 ('72000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001',430),
 ('72000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000002',500);
insert into public.duels(id,challenge_id,challenger_id,opponent_id,stake)
 values('72000000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000003',
 '72000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000002',50);
insert into public.aura_heists(id,challenge_id,attacker_id,target_id,cost,chance,succeeded)
 values('72000000-0000-0000-0000-000000000005','72000000-0000-0000-0000-000000000003',
 '72000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000002',20,.25,true);
