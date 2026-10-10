begin;
select no_plan();
insert into auth.users(id,email,raw_user_meta_data) values
 ('71000000-0000-0000-0000-000000000001','apple-test@example.invalid','{"username":"apple_revocation"}'),
 ('71000000-0000-0000-0000-000000000002','email-test@example.invalid','{"username":"email_revocation"}');
insert into auth.identities(id,user_id,provider_id,provider,identity_data) values
 ('71000000-0000-0000-0000-000000000003','71000000-0000-0000-0000-000000000001','apple-subject-test','apple','{"sub":"apple-subject-test"}');
select ok(not has_table_privilege('anon','public.apple_revoke_tokens','select'),'anonymous cannot read provider tokens');
select ok(not has_table_privilege('authenticated','public.apple_revoke_tokens','select'),'users cannot read provider tokens');
select ok(not has_table_privilege('authenticated','public.apple_revoke_tokens','update'),'users cannot forge a revocation');
select ok(has_table_privilege('service_role','public.apple_revoke_tokens','select,insert,update,delete'),'worker can maintain encrypted tokens');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
set local role authenticated;
select throws_ok('select public.delete_my_account()','P0001',null,'legacy Apple deletion blocked before revocation');
reset role;
insert into public.apple_revoke_tokens(user_id,apple_sub,encrypted_token,revoked_at) values
 ('71000000-0000-0000-0000-000000000001','another-apple-subject','v1.iv.encrypted',now());
set local role authenticated;
select throws_ok('select public.delete_my_account()','P0001',null,'a different Apple subject cannot unlock deletion');
reset role;
update public.apple_revoke_tokens set apple_sub='apple-subject-test',revoked_at=null;
set local role authenticated;
select throws_ok('select public.delete_my_account()','P0001',null,'retained but unrevoked Apple token blocks deletion');
reset role;
delete from auth.identities where user_id='71000000-0000-0000-0000-000000000001';
set local role authenticated;
select throws_ok('select public.delete_my_account()','P0001',null,'unlinking Apple does not bypass outstanding revocation');
reset role;
update public.apple_revoke_tokens set revoked_at=now();
set local role authenticated;
select lives_ok('select public.delete_my_account()','revoked Apple account can be deleted');
reset role;
select is((select count(*) from auth.users where id='71000000-0000-0000-0000-000000000001'),0::bigint,'Apple account removed');
select is((select count(*) from public.apple_revoke_tokens),0::bigint,'provider token removed with the account');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
set local role authenticated;
select lives_ok('select public.delete_my_account()','email-only deletion stays available');
reset role;
select * from finish();
rollback;
