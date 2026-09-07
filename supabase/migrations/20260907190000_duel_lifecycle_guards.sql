-- Preserve refunds on expiry and recheck the relationship at acceptance time.
do $migration$
declare definition text;
begin
 select pg_get_functiondef('public.respond_to_duel(uuid,boolean)'::regprocedure) into definition;
 definition := replace(definition,
   'update public.duels set status = ''expired'' where id = v_duel.id;',
   'update public.duels set status = ''expired'', resolved_at = now() where id = v_duel.id;');
 definition := replace(definition,
   'raise exception ''This duel has expired.'';',
   'return jsonb_build_object(''status'', ''expired'');');
 definition := replace(definition, '  if not p_accept then', $guard$
  if p_accept is null then raise exception 'Accept decision is required.'; end if;
  if p_accept and (
    public.is_blocked_pair(v_duel.challenger_id, v_duel.opponent_id)
    or not exists(select 1 from public.challenge_participants
      where challenge_id=v_duel.challenge_id and user_id=v_duel.challenger_id and status='active')
    or not exists(select 1 from public.challenges where id=v_duel.challenge_id
      and lifecycle='active' and (is_endless or starts_on+duration_days > (now() at time zone 'utc')::date))
  ) then
    update public.duels set status='declined',resolved_at=now() where id=v_duel.id;
    update public.challenge_participants set challenge_aura=challenge_aura+v_duel.stake
      where challenge_id=v_duel.challenge_id and user_id=v_duel.challenger_id;
    return jsonb_build_object('status','declined');
  end if;
  if not p_accept then$guard$);
 execute definition;
end $migration$;

-- Public EXECUTE defaults are unnecessary even when auth.uid() is checked.
revoke execute on function public.get_notification(bigint),
 public.get_notification_settings(),public.set_quest_reminder(uuid,time),
 public.clear_quest_reminder(uuid) from public,anon;
