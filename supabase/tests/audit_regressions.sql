-- Disposable database only. Every fixture and write is rolled back.
begin;
select no_plan();
insert into auth.users (id, email, raw_user_meta_data) values
 ('00000000-0000-0000-0000-000000000001','audit-a@example.invalid','{"username":"audit_alice"}'),
 ('00000000-0000-0000-0000-000000000002','audit-b@example.invalid','{"username":"audit_bob"}');
create function pg_temp.quest(n integer, goal text default 'check', mode_name text default 'solo', age integer default 0)
returns uuid language plpgsql as $$
declare q uuid := ('10000000-0000-0000-0000-' || lpad(n::text,12,'0'))::uuid;
begin
 insert into public.challenges(id,creator_id,title,starts_on,duration_days,aura_gain,aura_penalty,max_strikes,goal_type,target_value,unit,mode,is_endless)
 values(q,'00000000-0000-0000-0000-000000000001','Audit fixture',current_date-age,30,100,50,2,goal,
 case when goal='progress' then 100 end,case when goal='progress' then 'reps' end,mode_name,true);
 insert into public.challenge_participants(challenge_id,user_id,challenge_aura,created_at)
 values(q,'00000000-0000-0000-0000-000000000001',500,(current_date-age)::timestamptz);
 return q;
end $$;
select pg_temp.quest(1),pg_temp.quest(2,'progress'),pg_temp.quest(3,'avoid'),pg_temp.quest(4,'check','coop',1),pg_temp.quest(5,'avoid','solo',1);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select lives_ok($$select public.log_check_in('10000000-0000-0000-0000-000000000001')$$,'normal check-in works with actual schema');
select throws_ok($$select public.log_check_in('10000000-0000-0000-0000-000000000003')$$,'P0001',null,'direct avoid check-in rejected');
select throws_ok($$select public.log_check_in('10000000-0000-0000-0000-000000000002')$$,'P0001',null,'progress cannot be claimed at zero');
select lives_ok($$select public.add_progress('10000000-0000-0000-0000-000000000002',99)$$,'progress below goal works');
select throws_ok($$select public.log_check_in('10000000-0000-0000-0000-000000000002')$$,'P0001',null,'progress cannot be claimed at 99');
select lives_ok($$select public.add_progress('10000000-0000-0000-0000-000000000002',1)$$,'progress crossing the goal works');
select lives_ok($$select public.add_progress('10000000-0000-0000-0000-000000000002',20)$$,'overshoot remains allowed');
reset role;
select is((select challenge_aura from public.challenge_participants where challenge_id='10000000-0000-0000-0000-000000000002'),600,'progress pays exactly once');
select is((select sum(amount) from public.progress_entries where challenge_id='10000000-0000-0000-0000-000000000002'),120::numeric,'all progress preserved');
select ok(not has_function_privilege('authenticated','public.settle_periods()','EXECUTE'),'global settlement is internal');
update public.challenges set active_weekdays=array[extract(isodow from current_date-1)::smallint] where id='10000000-0000-0000-0000-000000000005';
select lives_ok('select public.settle_periods()','avoid settlement succeeds on a rest day');
select is((select count(*) from public.check_ins where challenge_id='10000000-0000-0000-0000-000000000005'),1::bigint,'avoid success actually recorded');
select is((select strikes_used from public.challenge_participants where challenge_id='10000000-0000-0000-0000-000000000004'),1,'first coop miss costs one strike');
select public.settle_periods();
select is((select strikes_used from public.challenge_participants where challenge_id='10000000-0000-0000-0000-000000000004'),1,'repeated settlement must not charge coop twice');
select ok(coalesce(current_setting('aura.internal_settlement',true),'') <> 'true','settlement does not leave a trigger bypass enabled');
-- Fail-closed registration and canonical URL parsing.
set local role authenticated;
select throws_ok($$select public.register_device('unifiedpush','android','https://2130706433/push')$$,'P0001',null,'integer loopback address rejected');
select throws_ok($$select public.register_device('unifiedpush','android','HTTPS://127.0.0.1/push')$$,'P0001',null,'uppercase scheme does not bypass host validation');
select throws_ok($$select public.register_device('unifiedpush','android','https://arbitrary.example/push')$$,'P0001',null,'unconfigured provider fails closed');
reset role;
select is(public.reminder_due_at('2026-09-07 23:00Z','23:00',0),'2026-09-07 23:00'::timestamp,'late reminder due at 23:00');
select is(public.reminder_due_at('2026-09-08 00:30Z','23:00',0),'2026-09-07 23:00'::timestamp,'catch-up window survives midnight');
select is(public.reminder_due_at('2026-09-07 21:00Z','23:00',120),'2026-09-07 23:00'::timestamp,'Berlin summer local reminder');
select is(public.reminder_due_at('2026-12-07 22:00Z','23:00',60),'2026-12-07 23:00'::timestamp,'Berlin winter local reminder');
select * from finish();
rollback;
