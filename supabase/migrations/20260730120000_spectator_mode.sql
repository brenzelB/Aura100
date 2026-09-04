-- =================================================================
--  AURA QUEST - Zuschauer-Modus, Serverseite
--
--  Wer eine Quest verliert, bleibt Mitglied und darf zusehen, aber
--  nicht mehr mitspielen. Die Zeile in challenge_participants wird
--  ohnehin nie geloescht - nur der Status wechselt auf 'failed'
--  (normale Modi) oder 'eliminated' (Last Man Standing).
--
--  Acht Aktions-RPCs pruefen bereits selbst auf status = 'active':
--  log_check_in, add_progress, log_slip, purchase_benefit,
--  create_duel, nudge_participant, send_targeted_roast und
--  attempt_aura_heist. Drei taten es NICHT, weil sie ueber die
--  Eintrags-ID statt ueber die Teilnahme einsteigen:
--
--      edit_progress_entry, delete_progress_entry, undo_last_slip
--
--  Ein ausgeschiedener Spieler konnte darueber weiterhin seine
--  Zahlen im laufenden Zeitraum veraendern. Das schliesst diese
--  Migration.
--
--  Bewusst NICHT gesperrt:
--    * leave_challenge - freiwilliges Verlassen muss gerade auch
--      Ausgeschiedenen offenstehen. Die Funktion sucht die Teilnahme
--      ohne Status-Bedingung; das bleibt so.
--    * dismiss_quest_pokes / react_to_quest_pokes / ack_poke_backs -
--      das sind Benachrichtigungen, kein Eingriff in den Wettbewerb.
-- =================================================================

-- Gemeinsamer Wächter. SECURITY DEFINER, damit er auch dann liest,
-- wenn RLS dem Aufrufer die Zeile verwehren wuerde.
create or replace function public.assert_active_participant(
  p_challenge_id uuid
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  if not exists (
    select 1 from public.challenge_participants
    where challenge_id = p_challenge_id
      and user_id = v_user_id
      and status = 'active'
  ) then
    raise exception
      'You are out of this quest - you can follow along, but not play.';
  end if;
end;
$$;

-- Interner Helfer, kein API-Endpunkt. Die aufrufenden Funktionen sind
-- SECURITY DEFINER und laufen als Eigentuemer - ihnen fehlt nichts.
revoke all on function public.assert_active_participant(uuid)
  from public, anon, authenticated;


-- ── edit_progress_entry ──────────────────────────────────────────
create or replace function public.edit_progress_entry(
  p_entry_id uuid, p_amount numeric
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id      uuid := (select auth.uid());
  v_entry        public.progress_entries%rowtype;
  v_challenge    public.challenges%rowtype;
  v_today        date := (now() at time zone 'utc')::date;
  v_period_len   integer;
  v_cur_start    date;
  v_period_end   date;
  v_done         integer;
  v_old_total    numeric;
  v_new_total    numeric;
  v_completed    boolean := false;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Enter an amount greater than 0.';
  end if;
  if p_amount > 1000000 then
    raise exception 'That is a bit much - keep it under 1000000.';
  end if;

  select * into v_entry
  from public.progress_entries
  where id = p_entry_id and user_id = v_user_id
  for update;
  if not found then
    raise exception 'That entry is not yours or no longer exists.';
  end if;

  -- NEU: wer raus ist, korrigiert nichts mehr.
  perform public.assert_active_participant(v_entry.challenge_id);

  select * into v_challenge
  from public.challenges where id = v_entry.challenge_id;
  if v_challenge.lifecycle <> 'active' then
    raise exception 'This quest is not active right now.';
  end if;

  -- Current period bounds, anchored to starts_on.
  v_period_len := case v_challenge.checkin_period
                    when 'daily' then 1 when 'weekly' then 7 else 30 end;
  v_cur_start := v_challenge.starts_on
    + ((v_today - v_challenge.starts_on) / v_period_len) * v_period_len;
  if v_entry.period_start <> v_cur_start then
    raise exception 'You can only correct entries from the current period.';
  end if;
  v_period_end := v_cur_start + v_period_len;
  if not v_challenge.is_endless then
    v_period_end := least(v_period_end,
      v_challenge.starts_on + v_challenge.duration_days);
  end if;

  select count(*)::int into v_done
  from public.check_ins
  where challenge_id = v_entry.challenge_id
    and user_id = v_user_id
    and checked_on >= v_cur_start
    and checked_on < v_period_end;

  select coalesce(sum(amount), 0) into v_old_total
  from public.progress_entries
  where challenge_id = v_entry.challenge_id
    and user_id = v_user_id
    and period_start = v_cur_start;
  v_new_total := v_old_total - v_entry.amount + p_amount;

  if v_done > 0 and v_new_total < v_challenge.target_value then
    raise exception
      'Can''t drop below a goal you already completed - the reward '
      'already paid out. Log a bonus rep or start the next period instead.';
  end if;

  update public.progress_entries
  set amount = p_amount where id = p_entry_id;

  if v_done = 0 and v_new_total >= v_challenge.target_value then
    perform public.log_check_in(v_entry.challenge_id);
    v_completed := true;
  else
    v_completed := v_done > 0;
  end if;

  return jsonb_build_object(
    'total', v_new_total,
    'target', v_challenge.target_value,
    'completed', v_completed
  );
end;
$$;


-- ── delete_progress_entry ────────────────────────────────────────
create or replace function public.delete_progress_entry(
  p_entry_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id      uuid := (select auth.uid());
  v_entry        public.progress_entries%rowtype;
  v_challenge    public.challenges%rowtype;
  v_today        date := (now() at time zone 'utc')::date;
  v_period_len   integer;
  v_cur_start    date;
  v_period_end   date;
  v_done         integer;
  v_new_total    numeric;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_entry
  from public.progress_entries
  where id = p_entry_id and user_id = v_user_id
  for update;
  if not found then
    raise exception 'That entry is not yours or no longer exists.';
  end if;

  -- NEU: wer raus ist, loescht nichts mehr.
  perform public.assert_active_participant(v_entry.challenge_id);

  select * into v_challenge
  from public.challenges where id = v_entry.challenge_id;
  if v_challenge.lifecycle <> 'active' then
    raise exception 'This quest is not active right now.';
  end if;

  v_period_len := case v_challenge.checkin_period
                    when 'daily' then 1 when 'weekly' then 7 else 30 end;
  v_cur_start := v_challenge.starts_on
    + ((v_today - v_challenge.starts_on) / v_period_len) * v_period_len;
  if v_entry.period_start <> v_cur_start then
    raise exception 'You can only correct entries from the current period.';
  end if;
  v_period_end := v_cur_start + v_period_len;
  if not v_challenge.is_endless then
    v_period_end := least(v_period_end,
      v_challenge.starts_on + v_challenge.duration_days);
  end if;

  select count(*)::int into v_done
  from public.check_ins
  where challenge_id = v_entry.challenge_id
    and user_id = v_user_id
    and checked_on >= v_cur_start
    and checked_on < v_period_end;

  select coalesce(sum(amount), 0) - v_entry.amount into v_new_total
  from public.progress_entries
  where challenge_id = v_entry.challenge_id
    and user_id = v_user_id
    and period_start = v_cur_start;

  if v_done > 0 and v_new_total < v_challenge.target_value then
    raise exception
      'Can''t drop below a goal you already completed - the reward '
      'already paid out. Log a bonus rep or start the next period instead.';
  end if;

  delete from public.progress_entries where id = p_entry_id;

  return jsonb_build_object(
    'total', v_new_total,
    'target', v_challenge.target_value,
    'completed', v_done > 0
  );
end;
$$;


-- ── undo_last_slip ───────────────────────────────────────────────
create or replace function public.undo_last_slip(
  p_challenge_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id      uuid := (select auth.uid());
  v_challenge    public.challenges%rowtype;
  v_today        date := (now() at time zone 'utc')::date;
  v_period_len   integer;
  v_period_start date;
  v_slip_id      uuid;
  v_count        integer;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  -- NEU: wer raus ist, nimmt keinen Ausrutscher mehr zurueck.
  perform public.assert_active_participant(p_challenge_id);

  select * into v_challenge
  from public.challenges where id = p_challenge_id;
  if not found or v_challenge.goal_type <> 'avoid' then
    raise exception 'This quest is not an avoid quest.';
  end if;

  v_period_len := case v_challenge.checkin_period
                    when 'daily' then 1 when 'weekly' then 7 else 30 end;
  v_period_start := v_challenge.starts_on
    + ((v_today - v_challenge.starts_on) / v_period_len) * v_period_len;

  -- Once the limit broke, the penalty and strike are on the books. A
  -- mistap can be taken back; a consequence cannot.
  if exists (
    select 1 from public.settlement_events
    where user_id = v_user_id and challenge_id = p_challenge_id
      and kind = 'slip_over' and period_start = v_period_start
  ) then
    raise exception
      'This period already went over the limit - that cannot be undone.';
  end if;

  select id into v_slip_id
  from public.slips
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and period_start = v_period_start
  order by created_at desc
  limit 1;
  if not found then
    raise exception 'Nothing to undo in this period.';
  end if;

  delete from public.slips where id = v_slip_id;

  select count(*)::int into v_count
  from public.slips
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and period_start = v_period_start;

  return jsonb_build_object(
    'count', v_count,
    'allowance', v_challenge.daily_allowance,
    'over', false
  );
end;
$$;
