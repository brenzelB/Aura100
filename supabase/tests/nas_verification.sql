select count(*) as applied_migrations from aura_admin.applied_migrations;
select has_table_privilege('authenticated','public.challenge_participants','UPDATE') as direct_aura_write,
 has_table_privilege('authenticated','public.challenges','UPDATE') as direct_quest_write,
 has_function_privilege('authenticated','public.settle_periods()','EXECUTE') as global_settlement,
 has_function_privilege('authenticated','public.get_my_period_totals()','EXECUTE') as own_totals;
select has_table_privilege('anon','public.challenge_participants','TRUNCATE') as anon_truncate,
 has_table_privilege('authenticated','public.profiles','TRUNCATE') as user_truncate,
 has_table_privilege('authenticated','public.challenges','TRIGGER') as user_create_trigger;
select unifiedpush_allowed_hosts from public.push_config;
select j.jobname,d.status,d.start_time from cron.job_run_details d join cron.job j using(jobid)
 where d.start_time>=(select min(applied_at) from aura_admin.applied_migrations)
 order by d.start_time desc limit 12;
select count(*) as profiles from public.profiles;
select count(*) as quests from public.challenges;
select count(*) as checkins from public.check_ins;
select count(*) as participants,sum(challenge_aura) as total_aura from public.challenge_participants;
select count(*) as outstanding_delivery from public.notification_outbox where finished_at is null;
