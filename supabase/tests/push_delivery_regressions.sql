begin;
select no_plan();
-- Isolate from pre-existing snapshot rows; every change rolls back.
delete from public.notification_outbox;
delete from public.device_tokens;
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-0000-0000-000000000001','push-a@example.invalid','{"username":"push_alice"}'),
 ('00000000-0000-0000-0000-000000000002','push-b@example.invalid','{"username":"push_bob"}');
update public.push_config set unifiedpush_allowed_hosts=array['push.example.org'],fcm_function_url='http://audit-sender.invalid';
insert into public.device_tokens(id,user_id,provider,platform,token) values
 ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','unifiedpush','android','https://push.example.org/a'),
 ('20000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','fcm','android','fake-local-token');
insert into public.notification_outbox(user_id,category,title,body) values
 ('00000000-0000-0000-0000-000000000001','quest','fixture','test');
select is(public.deliver_notifications(),2,'queues one delivery per device');
select ok((select sent_at is null from public.notification_outbox limit 1),'enqueue is not confirmed delivery');
select is(public.deliver_notifications(),0,'does not resend in-flight deliveries');
insert into net._http_response(id,status_code,timed_out,content)
 select request_id,case when device_token_id='20000000-0000-0000-0000-000000000001' then 200 else 503 end,false,'{}'
 from public.push_deliveries;
select lives_ok('select public.reap_push_failures()','reaper joins actual pg_net response schema');
select is((select count(*) from public.push_deliveries where status='delivered'),1::bigint,'one device confirmed');
select is((select count(*) from public.push_deliveries where status='queued'),1::bigint,'temporary failure is queued');
select is(public.deliver_notifications(),0,'backoff delays retry');
update public.push_deliveries set next_attempt_at=now() where status='queued';
select is(public.deliver_notifications(),1,'retry goes only to the failed device');
insert into net._http_response(id,status_code,timed_out,content)
 select request_id,200,false,'{}' from public.push_deliveries where status='in_flight';
select public.reap_push_failures();
select is((select count(*) from public.push_deliveries where status='delivered'),2::bigint,'503 then 200 succeeds');
select ok((select sent_at is not null and finished_at is not null from public.notification_outbox limit 1),'outbox completes after response');

-- Lost responses after pg_net restart must not stick forever.
insert into public.notification_outbox(user_id,category,title,body) values
 ('00000000-0000-0000-0000-000000000001','quest','timeout','test');
select public.deliver_notifications();
update public.push_deliveries set requested_at=now()-interval '6 minutes' where status='in_flight';
select public.reap_push_failures();
select is((select count(*) from public.push_deliveries where status='queued'),2::bigint,'missing responses become retries');
update public.push_deliveries set next_attempt_at=now() where status='queued';
select public.deliver_notifications();
insert into net._http_response(id,status_code,timed_out,content)
 select request_id,404,false,'{"error":"gateway route missing"}' from public.push_deliveries where status='in_flight';
select public.reap_push_failures();
select is((select count(*) from public.device_tokens where provider='fcm'),1::bigint,'generic FCM 404 preserves valid token');
select is((select count(*) from public.device_tokens where provider='unifiedpush'),0::bigint,'UnifiedPush 404 removes dead endpoint');

insert into public.notification_outbox(user_id,category,title,body) values
 ('00000000-0000-0000-0000-000000000001','quest','fcm-dead','test');
select public.deliver_notifications();
insert into net._http_response(id,status_code,timed_out,content)
 select request_id,404,false,'{"error":{"details":[{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"UNREGISTERED"}]}}'
 from public.push_deliveries where status='in_flight';
-- A stale response must not delete the new owner's registration.
update public.device_tokens set user_id='00000000-0000-0000-0000-000000000002';
select public.reap_push_failures();
select is((select count(*) from public.device_tokens),1::bigint,'account rebind survives old delivery failure');
select ok(public.allowed_push_endpoint('https://push.example.org/a'),'explicit trusted provider allowed');
select ok(not public.allowed_push_endpoint('https://push.example.org:8443/a'),'nonstandard ports rejected');
select ok(not public.allowed_push_endpoint('https://push.example.org.evil.invalid/a'),'hostname suffix trick rejected');
select ok(not public.allowed_push_endpoint('https://push.example.org@127.0.0.1/a'),'userinfo trick rejected');
select * from finish();
rollback;
