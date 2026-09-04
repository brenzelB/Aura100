-- =================================================================
--  AURA QUEST - Blackout: laufendes Fenster greift sofort
--
--  Die erste Fassung suchte immer das naechste Fenster, das NOCH NICHT
--  begonnen hatte. Wer um 12:45 "Mittags" (12:00-14:00) kaufte, traf
--  damit den morgigen Mittag - die Sperre lag 23 Stunden in der Zukunft,
--  das Opfer merkte nichts und trug munter weiter ein.
--
--  Neue Regel:
--    * Steckt die aktuelle Ortszeit des Opfers IM gewaehlten Fenster,
--      beginnt die Sperre sofort und laeuft volle zwei Stunden.
--    * Sonst wie bisher: das naechste Vorkommen des Fensters.
--
--  Die zwei Stunden bleiben damit immer zwei Stunden. Eine Sperre, die
--  um 13:50 gekauft wird, reicht dann bis 15:50 und damit ueber das
--  Mittagsfenster hinaus - das ist gewollt, denn "genau zwei Stunden"
--  wiegt schwerer als die Fenstergrenze.
-- =================================================================

create or replace function public.cast_blackout(
  p_challenge_id uuid,
  p_target_id    uuid,
  p_daypart      text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id     uuid := (select auth.uid());
  v_cost        constant integer := 250;
  v_challenge   public.challenges%rowtype;
  v_offset      integer;
  v_hour        integer;
  v_local_now   timestamp;
  v_local_start timestamp;
  v_starts_at   timestamptz;
  v_ends_at     timestamptz;
  v_aura        integer;
  v_members     integer;
  v_target_name text;
  v_immediate   boolean := false;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if v_user_id = p_target_id then
    raise exception 'You cannot black out yourself.';
  end if;
  if p_daypart not in ('morning', 'noon', 'evening') then
    raise exception 'Pick morning, noon or evening.';
  end if;

  select * into v_challenge
  from public.challenges where id = p_challenge_id;
  if not found then
    raise exception 'Quest not found.';
  end if;
  if v_challenge.lifecycle <> 'active' then
    raise exception 'This quest is not running right now.';
  end if;
  if v_challenge.goal_type = 'avoid' then
    raise exception 'A blackout has nothing to block on an avoid quest.';
  end if;

  select count(*)::int into v_members
  from public.challenge_participants
  where challenge_id = p_challenge_id and status = 'active';
  if v_members < 2 then
    raise exception 'A blackout needs someone to aim at.';
  end if;

  if not exists (
    select 1 from public.challenge_participants
    where challenge_id = p_challenge_id
      and user_id = p_target_id
      and status = 'active'
  ) then
    raise exception 'Target is not an active member of this quest.';
  end if;

  if exists (
    select 1 from public.blackouts
    where challenge_id = p_challenge_id
      and target_id = p_target_id
      and ends_at > now()
  ) then
    raise exception 'They are already blacked out - wait your turn.';
  end if;

  select challenge_aura into v_aura
  from public.challenge_participants
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and status = 'active'
  for update;
  if not found then
    raise exception 'You are not an active member of this quest.';
  end if;
  if v_aura < v_cost then
    raise exception 'Not enough aura - a blackout costs %.', v_cost;
  end if;

  -- Alles in der ORTSZEIT DES OPFERS.
  select coalesce(utc_offset_minutes, 0) into v_offset
  from public.profiles where id = p_target_id;

  v_hour := case p_daypart
              when 'morning' then 7
              when 'noon'    then 12
              else                20
            end;

  v_local_now   := (now() at time zone 'utc') + make_interval(mins => v_offset);
  v_local_start := date_trunc('day', v_local_now) + make_interval(hours => v_hour);

  if v_local_now >= v_local_start
     and v_local_now < v_local_start + interval '2 hours' then
    -- Mitten im gewaehlten Fenster: ab sofort.
    v_starts_at := now();
    v_immediate := true;
  else
    if v_local_start <= v_local_now then
      v_local_start := v_local_start + interval '1 day';
    end if;
    v_starts_at := (v_local_start - make_interval(mins => v_offset))
                     at time zone 'utc';
  end if;

  v_ends_at := v_starts_at + interval '2 hours';

  update public.challenge_participants
  set challenge_aura = challenge_aura - v_cost
  where challenge_id = p_challenge_id and user_id = v_user_id;

  insert into public.blackouts
    (challenge_id, attacker_id, target_id, daypart,
     starts_at, ends_at, cost)
  values
    (p_challenge_id, v_user_id, p_target_id, p_daypart,
     v_starts_at, v_ends_at, v_cost);

  select username into v_target_name
  from public.profiles where id = p_target_id;

  return jsonb_build_object(
    'target',     v_target_name,
    'daypart',    p_daypart,
    'starts_at',  v_starts_at,
    'ends_at',    v_ends_at,
    'immediate',  v_immediate,
    'cost',       v_cost,
    'balance',    v_aura - v_cost
  );
end;
$$;

revoke all on function public.cast_blackout(uuid, uuid, text) from public, anon;
grant execute on function public.cast_blackout(uuid, uuid, text) to authenticated;
