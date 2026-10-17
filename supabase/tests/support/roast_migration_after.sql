do $$ begin
 if (select challenge_aura from public.challenge_participants where challenge_id='72000000-0000-0000-0000-000000000003' and user_id='72000000-0000-0000-0000-000000000001')<>500
 or (select challenge_aura from public.challenge_participants where challenge_id='72000000-0000-0000-0000-000000000003' and user_id='72000000-0000-0000-0000-000000000002')<>500
 or (select status from public.duels where id='72000000-0000-0000-0000-000000000004')<>'expired'
 or exists(select 1 from public.aura_heists where id='72000000-0000-0000-0000-000000000005' and (resolved_at is null or stolen_amount<>0 or acknowledged_at is null)) then
   raise exception 'Legacy escrow/heist migration refund failed';
 end if;
end $$;
select set_config('request.jwt.claim.sub','72000000-0000-0000-0000-000000000002',true);
select public.respond_to_duel('72000000-0000-0000-0000-000000000004',true);
select public.expire_duels();
do $$ begin
 if (select challenge_aura from public.challenge_participants where challenge_id='72000000-0000-0000-0000-000000000003' and user_id='72000000-0000-0000-0000-000000000001')<>500 then
   raise exception 'Legacy game refunded twice';
 end if;
end $$;
select set_config('request.jwt.claim.sub','',true);
delete from public.challenges where id='72000000-0000-0000-0000-000000000003';
delete from auth.users where id in('72000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000002');
