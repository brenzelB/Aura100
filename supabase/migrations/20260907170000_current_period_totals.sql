-- One JSON result: totals cannot be truncated by PostgREST's raw-row limit.
-- Explicit ownership on BOTH the roster and activity rows, with an empty path.
create or replace function public.get_my_period_totals()
returns jsonb language sql stable security definer set search_path = '' as $$
 with periods as (
   select c.id,c.starts_on + (greatest(0,(now() at time zone 'utc')::date-c.starts_on)
     / case c.checkin_period when 'daily' then 1 when 'weekly' then 7 else 30 end)
     * case c.checkin_period when 'daily' then 1 when 'weekly' then 7 else 30 end as pstart
   from public.challenges c join public.challenge_participants cp on cp.challenge_id=c.id
   where cp.user_id=(select auth.uid()) and cp.status in ('active','failed','eliminated')
 )
 select coalesce(jsonb_object_agg(p.id,jsonb_build_object(
   'progress',coalesce((select sum(e.amount) from public.progress_entries e
     where e.challenge_id=p.id and e.user_id=(select auth.uid()) and e.period_start=p.pstart),0),
   'slips',(select count(*) from public.slips s
     where s.challenge_id=p.id and s.user_id=(select auth.uid()) and s.period_start=p.pstart))), '{}'::jsonb)
 from periods p;
$$;
revoke all on function public.get_my_period_totals() from public,anon;
grant execute on function public.get_my_period_totals() to authenticated;
