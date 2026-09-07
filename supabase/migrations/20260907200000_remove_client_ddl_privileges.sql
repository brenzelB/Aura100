-- RLS does not protect TRUNCATE. Supabase's historical ALL grants also
-- included trigger/reference/maintenance rights unnecessary for REST clients.
revoke all on all tables in schema public from public,anon;
revoke truncate,references,trigger on all tables in schema public from authenticated;
revoke update(status) on public.challenge_participants from authenticated;
do $$ begin
 if current_setting('server_version_num')::integer >= 170000 then
   execute 'revoke maintain on all tables in schema public from authenticated';
 end if;
end $$;
-- Internal tracking has no client use, even if a future policy is added.
revoke all on public.push_delivery_attempts,public.push_deliveries,
 public.push_config,public.notification_outbox from authenticated;
