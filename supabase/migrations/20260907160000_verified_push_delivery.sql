-- Fail closed unless an administrator has named trusted UnifiedPush hosts.
-- Host owners/DNS must be trusted; restrict NAS egress as an additional boundary.
create or replace function public.allowed_push_endpoint(p_url text)
returns boolean language sql stable security definer set search_path = '' as $$
 select coalesce(length(p_url) <= 2048
   and p_url ~ '^https://[a-z0-9]([a-z0-9.-]*[a-z0-9])?\.[a-z]{2,63}(:443)?/[^[:space:]\\#]*$'
   and substring(p_url from '^https://([^/:]+)') = any(
     (select unifiedpush_allowed_hosts from public.push_config where id)::text[]), false);
$$;
revoke all on function public.allowed_push_endpoint(text) from public,anon,authenticated;

create or replace function public.register_device(p_provider text,p_platform text,p_token text)
returns void language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); t text := trim(p_token);
begin
 if u is null then raise exception 'Not signed in.'; end if;
 if p_provider is null or p_provider not in ('fcm','unifiedpush')
    or p_platform is null or p_platform not in ('android','ios') then
   raise exception 'Invalid push transport.';
 end if;
 if t is null or length(t) not between 1 and 4096 then raise exception 'Invalid token.'; end if;
 if p_provider='unifiedpush' and not public.allowed_push_endpoint(t) then
   raise exception 'UnifiedPush endpoint is not configured as a trusted HTTPS provider.';
 end if;
 insert into public.device_tokens(user_id,provider,platform,token) values(u,p_provider,p_platform,t)
 on conflict(provider,token) do update set user_id=excluded.user_id,platform=excluded.platform,last_seen_at=now();
 insert into public.notification_settings(user_id) values(u) on conflict do nothing;
end $$;
revoke all on function public.register_device(text,text,text) from public,anon;
grant execute on function public.register_device(text,text,text) to authenticated;

alter table public.notification_outbox add column finished_at timestamptz;
create table public.push_deliveries (
 id bigint generated always as identity primary key,
 outbox_id bigint not null references public.notification_outbox(id) on delete cascade,
 device_token_id uuid references public.device_tokens(id) on delete set null,
 status text not null default 'queued' check(status in ('queued','in_flight','delivered','failed','cancelled')),
 attempts integer not null default 0,
 request_id bigint,
 requested_at timestamptz,
 next_attempt_at timestamptz not null default now(),
 last_error text,
 unique(outbox_id,device_token_id)
);
alter table public.push_deliveries enable row level security;
revoke all on public.push_deliveries from public,anon,authenticated;
create index push_deliveries_pending on public.push_deliveries(next_attempt_at) where status='queued';
create index push_deliveries_requests on public.push_deliveries(request_id) where status='in_flight';
-- Preserve outcomes already recorded by the previous implementation.
insert into public.push_deliveries(outbox_id,device_token_id,status,attempts,request_id,requested_at)
select distinct on (a.outbox_id,a.device_token_id) a.outbox_id,a.device_token_id,
 case a.status when 'delivered' then 'delivered' when 'in_flight' then 'in_flight'
   when 'retryable_error' then 'queued' else 'failed' end,
 (count(*) over(partition by a.outbox_id,a.device_token_id))::integer,a.request_id,a.created_at
from public.push_delivery_attempts a where a.device_token_id is not null
order by a.outbox_id,a.device_token_id,a.created_at desc,a.id desc;
update public.notification_outbox o set finished_at=sent_at
where sent_at is not null and not exists(select 1 from public.push_deliveries d where d.outbox_id=o.id);

create or replace function public.deliver_notifications(p_limit integer default 200)
returns integer language plpgsql security definer set search_path = '' as $$
declare o record; d record; cfg public.push_config%rowtype; req bigint; sent integer:=0;
begin
 select * into cfg from public.push_config where id;
 -- One state per recipient device: a successful device is never retried just
 -- because a different device timed out. SKIP LOCKED supports parallel workers.
 for o in select * from public.notification_outbox
   where finished_at is null order by created_at limit greatest(1,least(p_limit,1000))
   for update skip locked
 loop
   insert into public.push_deliveries(outbox_id,device_token_id)
     select o.id,t.id from public.device_tokens t where t.user_id=o.user_id
     on conflict do nothing;
   if not exists(select 1 from public.push_deliveries where outbox_id=o.id) then
     update public.notification_outbox set attempts=attempts+1,last_error='no reachable device',
       finished_at=case when attempts>=4 then now() end where id=o.id;
   end if;
   for d in select j.*,t.provider,t.token,t.platform,t.user_id as device_owner
     from public.push_deliveries j left join public.device_tokens t on t.id=j.device_token_id
     where j.outbox_id=o.id and j.status='queued' and j.next_attempt_at<=now()
     order by j.id for update of j skip locked
   loop
     if d.device_owner is distinct from o.user_id then
       update public.push_deliveries set status='cancelled',last_error='device owner changed' where id=d.id;
       continue;
     end if;
     if d.attempts>=5 then
       update public.push_deliveries set status='failed',last_error='retry limit' where id=d.id;
       continue;
     end if;
     begin
       if d.provider='unifiedpush' then
         -- Revalidate existing registrations too, including after config changes.
         if not public.allowed_push_endpoint(d.token) then
           update public.push_deliveries set status='failed',last_error='untrusted endpoint' where id=d.id;
           continue;
         end if;
         req := net.http_post(url:=d.token,headers:='{"Content-Type":"application/json"}'::jsonb,
           body:=jsonb_build_object('category',o.category,'refId',o.ref_id,'id',o.id));
       elsif cfg.fcm_function_url is not null then
         req := net.http_post(url:=cfg.fcm_function_url,
           headers:=jsonb_build_object('Content-Type','application/json','x-push-secret',coalesce(cfg.fcm_shared_secret,'')),
           body:=jsonb_build_object('token',d.token,'platform',d.platform,'category',o.category,'refId',o.ref_id,'id',o.id));
       else
         raise exception 'FCM sender not configured';
       end if;
       update public.push_deliveries set status='in_flight',attempts=attempts+1,
         request_id=req,requested_at=now(),last_error=null where id=d.id;
       sent:=sent+1;
     exception when others then
       update public.push_deliveries set attempts=attempts+1,
         status=case when attempts>=4 then 'failed' else 'queued' end,
         next_attempt_at=now()+make_interval(secs=>least(3600,60*(2^attempts)::integer)),
         last_error=left(sqlerrm,300) where id=d.id;
     end;
   end loop;
 end loop;
 return sent;
end $$;
revoke all on function public.deliver_notifications(integer) from public,anon,authenticated;

create or replace function public.reap_push_failures()
returns integer language plpgsql security definer set search_path = '' as $$
declare r record; dead integer:=0; state text; message text; invalid_token boolean;
begin
 for r in select j.*,o.user_id as owner,t.provider,t.user_id as device_owner,
   h.id as response_id,h.status_code,h.timed_out,h.error_msg,h.content
   from public.push_deliveries j join public.notification_outbox o on o.id=j.outbox_id
   left join public.device_tokens t on t.id=j.device_token_id
   left join net._http_response h on h.id=j.request_id
   where j.status='in_flight' and (h.id is not null or j.requested_at<now()-interval '5 minutes')
   order by j.id for update of j skip locked
 loop
   message:=coalesce(r.error_msg,'HTTP '||r.status_code,'response missing');
   invalid_token:=false;
   if r.device_owner is distinct from r.owner then state:='cancelled';
   elsif r.status_code between 200 and 299 then state:='delivered';
   elsif r.response_id is null or coalesce(r.timed_out,false) or r.error_msg is not null
     or r.status_code in (408,429) or r.status_code>=500 then
     state:=case when r.attempts>=5 then 'failed' else 'queued' end;
   else
     state:='failed';
     invalid_token := r.provider='unifiedpush' and r.status_code in (404,410);
     -- Only an explicit FCM UNREGISTERED response proves the token is dead.
     -- A 404 from Kong/function routing must not wipe every valid device.
     if r.provider='fcm' then
       begin
         invalid_token := exists(select 1 from jsonb_array_elements((r.content::jsonb)->'error'->'details') e
           where e->>'@type'='type.googleapis.com/google.firebase.fcm.v1.FcmError'
             and e->>'errorCode'='UNREGISTERED');
       exception when others then invalid_token:=false;
       end;
     end if;
   end if;
   update public.push_deliveries set status=state,
     next_attempt_at=now()+make_interval(secs=>least(3600,60*(2^greatest(0,r.attempts-1))::integer)),
     last_error=case when state='delivered' then null else left(message,300) end where id=r.id;
   if invalid_token then
     delete from public.device_tokens where id=r.device_token_id and user_id=r.owner;
     if found then dead:=dead+1; end if;
   end if;
 end loop;
 update public.notification_outbox o set finished_at=now(),
   sent_at=case when exists(select 1 from public.push_deliveries d where d.outbox_id=o.id and d.status='delivered') then now() end,
   last_error=(select d.last_error from public.push_deliveries d where d.outbox_id=o.id and d.last_error is not null order by d.id limit 1)
 where o.finished_at is null
   and exists(select 1 from public.push_deliveries d where d.outbox_id=o.id)
   and not exists(select 1 from public.push_deliveries d where d.outbox_id=o.id and d.status in ('queued','in_flight'));
 return dead;
end $$;
revoke all on function public.reap_push_failures() from public,anon,authenticated;
