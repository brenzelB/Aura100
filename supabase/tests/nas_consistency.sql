select return_message,count(*) from cron.job_run_details where status='failed'
 and start_time>now()-interval '7 days' group by 1;
select table_name,column_name,data_type from information_schema.columns
 where table_schema='public' and table_name in ('push_config','challenges','challenge_participants','duels') order by 1,ordinal_position;
select tablename,policyname,roles,cmd,qual,with_check from pg_policies where schemaname='public' order by 1,2;
select 'profiles without auth user' as check_name,count(*) from public.profiles p left join auth.users u on u.id=p.id where u.id is null
union all select 'auth users without profile',count(*) from auth.users u left join public.profiles p on p.id=u.id where p.id is null
union all select 'negative challenge aura',count(*) from public.challenge_participants where challenge_aura<0
union all select 'duplicate participant',count(*) from (select challenge_id,user_id from public.challenge_participants group by 1,2 having count(*)>1) s
union all select 'duplicate checkin',count(*) from (select challenge_id,user_id,checked_on from public.check_ins group by 1,2,3 having count(*)>1) s
union all select 'overdue pending duel',count(*) from public.duels where status='pending' and expires_at<now()
union all select 'orphan checkin membership',count(*) from public.check_ins c where not exists(select 1 from public.challenge_participants p where p.challenge_id=c.challenge_id and p.user_id=c.user_id);
select proname,md5(pg_get_functiondef(p.oid)) as definition_hash from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.prokind='f' and proname in ('log_check_in','settle_periods','reap_push_failures','register_device');
