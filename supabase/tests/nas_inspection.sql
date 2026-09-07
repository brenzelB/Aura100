-- Read-only operational inventory; deliberately excludes private row contents.
select version(), pg_size_pretty(pg_database_size(current_database())) as database_size;
select extname,extversion from pg_extension order by extname;
select table_schema,table_name from information_schema.tables
 where table_schema in ('public','supabase_migrations') order by 1,2;
select c.relname,c.relrowsecurity,c.relforcerowsecurity,s.n_live_tup
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 left join pg_stat_user_tables s on s.relid=c.oid
 where n.nspname='public' and c.relkind='r' order by 1;
select jobname,schedule,active from cron.job order by jobname;
select j.jobname,d.status,count(*),max(d.end_time) as last_run
 from cron.job_run_details d left join cron.job j using(jobid)
 where d.start_time>now()-interval '7 days' group by 1,2 order by 1,2;
select proname,prosecdef,proconfig,has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') as user_execute
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and not exists(select 1 from pg_depend d
 where d.classid='pg_proc'::regclass and d.objid=p.oid and d.deptype='e') order by 1;
select provider,platform,count(*),min(last_seen_at),max(last_seen_at) from public.device_tokens group by 1,2;
select substring(token from '^https?://([^/:]+)') as push_host,count(*)
 from public.device_tokens where provider='unifiedpush' group by 1;
select count(*) as total,count(*) filter(where sent_at is null) as unsent,
 min(created_at) filter(where sent_at is null) as oldest_unsent from public.notification_outbox;
select relname,n_dead_tup,last_autovacuum,last_autoanalyze from pg_stat_user_tables
 where schemaname='public' and n_dead_tup>0 order by n_dead_tup desc;
select conrelid::regclass,conname from pg_constraint where not convalidated;
select pid,state,wait_event_type,wait_event,now()-xact_start as transaction_age
 from pg_stat_activity where datname=current_database() and pid<>pg_backend_pid()
 and (state like 'idle in transaction%' or xact_start<now()-interval '1 minute');
