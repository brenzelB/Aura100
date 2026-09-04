-- =================================================================
--  AURA QUEST - Negative ("avoid") challenges
--
--  A third goal type where the win condition is INACTION: don't smoke,
--  don't drink soda, don't bite your nails. Doing nothing all period is
--  the perfect run; the creator may allow a per-period budget of slips
--  so a habit can be tapered instead of quit cold turkey.
--
--    * every slip is logged with a button press -> `slips`
--    * count <= allowance  -> the period still succeeds
--    * count >  allowance  -> the period is lost the instant it happens:
--                             penalty + strike right there (Half Damage
--                             and Streak Shield still apply)
--    * reward scales: a spotless period pays full aura, scaling down to
--      half when the whole allowance was spent
--
--  Settlement inverts its usual test for these quests: a clean period is
--  auto-completed (a real check_in row, so streaks/stats/timeline work
--  untouched); a blown period is skipped because it was already paid for.
-- =================================================================

-- ── 1. Schema ────────────────────────────────────────────────────
alter table public.challenges
  add column if not exists daily_allowance integer not null default 0;

alter table public.challenges drop constraint if exists challenges_daily_allowance_check;
alter table public.challenges add constraint challenges_daily_allowance_check
  check (daily_allowance >= 0 and daily_allowance <= 100);

alter table public.challenges drop constraint if exists challenges_goal_type_check;
alter table public.challenges add constraint challenges_goal_type_check
  check (goal_type = any (array['check'::text, 'progress'::text, 'avoid'::text]));

-- The target/unit pair is required for PROGRESS only. The old wording
-- ("goal_type = 'check' OR ...") would have demanded it from avoid too.
alter table public.challenges drop constraint if exists challenges_progress_fields;
alter table public.challenges add constraint challenges_progress_fields
  check (
    goal_type <> 'progress'
    or (target_value is not null and target_value > 0
        and unit is not null
        and length(trim(both from unit)) between 1 and 24)
  );

create table if not exists public.slips (
  id           uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  -- Which period this slip counts against (same anchoring as everywhere).
  period_start date not null,
  created_at   timestamptz not null default now()
);

create index if not exists slips_period_idx
  on public.slips (challenge_id, user_id, period_start);

alter table public.slips enable row level security;
grant select on public.slips to authenticated;

-- Slips only enter through the RPC, so there is no insert/update policy.
drop policy if exists "slips: quest members read each other" on public.slips;
create policy "slips: quest members read each other"
  on public.slips for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1 from public.challenge_participants me
      where me.challenge_id = slips.challenge_id
        and me.user_id = (select auth.uid())
    )
  );

alter table public.settlement_events drop constraint settlement_events_kind_check;
alter table public.settlement_events add constraint settlement_events_kind_check
  check (kind = any (array[
    'penalty','strike','shield_saved','half_damage','failed','completed',
    'bonus','duel_won','duel_lost','versus_won','versus_lost','milestone',
    'strike_repaired','eliminated','lms_finished','heist_robbed','heist_hit',
    'slip_over','avoided'
  ]));

-- ── 2. Shared aura multiplier (emblems, highest one wins) ────────
create or replace function public.aura_multiplier(
  p_challenge_id uuid,
  p_user_id uuid
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when exists (
      select 1 from public.benefit_purchases bp
      join public.benefits b on b.id = bp.benefit_id
      where bp.challenge_id = p_challenge_id and bp.user_id = p_user_id
        and b.title = 'Aura Lord') then 2.0
    when exists (
      select 1 from public.benefit_purchases bp
      join public.benefits b on b.id = bp.benefit_id
      where bp.challenge_id = p_challenge_id and bp.user_id = p_user_id
        and b.title = 'Title Badge') then 1.2
    else 1.0
  end;
$$;

-- ── 3. Log one slip ─────────────────────────────────────────────
create or replace function public.log_slip(p_challenge_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id      uuid := (select auth.uid());
  v_challenge    public.challenges%rowtype;
  v_participant  public.challenge_participants%rowtype;
  v_today        date := (now() at time zone 'utc')::date;
  v_period_len   integer;
  v_period_start date;
  v_count        integer;
  v_already_over boolean;
  v_penalty      integer;
  v_consumable   uuid;
  v_struck       boolean := false;
  v_shielded     boolean := false;
  v_now_over     boolean := false;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  select * into v_challenge
  from public.challenges where id = p_challenge_id;
  if not found then
    raise exception 'Quest not found.';
  end if;
  if v_challenge.goal_type <> 'avoid' then
    raise exception 'This quest is not an avoid quest.';
  end if;
  if v_challenge.lifecycle = 'lobby' then
    raise exception 'This quest has not started yet.';
  end if;
  if v_challenge.lifecycle = 'finished' then
    raise exception 'This quest is over.';
  end if;
  if v_today < v_challenge.starts_on then
    raise exception 'This quest has not started yet.';
  end if;
  if not v_challenge.is_endless
     and v_today >= v_challenge.starts_on + v_challenge.duration_days then
    raise exception 'This quest has already ended.';
  end if;

  select * into v_participant
  from public.challenge_participants
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and status = 'active'
  for update;
  if not found then
    raise exception 'You are not an active participant of this quest.';
  end if;

  v_period_len := case v_challenge.checkin_period
                    when 'daily' then 1 when 'weekly' then 7 else 30 end;
  v_period_start := v_challenge.starts_on
    + ((v_today - v_challenge.starts_on) / v_period_len) * v_period_len;

  -- Was this period already blown? Then the damage is done; further
  -- slips are still recorded (honest history) but cost nothing extra.
  select exists (
    select 1 from public.settlement_events
    where user_id = v_user_id and challenge_id = p_challenge_id
      and kind = 'slip_over' and period_start = v_period_start
  ) into v_already_over;

  insert into public.slips (challenge_id, user_id, period_start)
  values (p_challenge_id, v_user_id, v_period_start);

  select count(*)::int into v_count
  from public.slips
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and period_start = v_period_start;

  if not v_already_over and v_count > v_challenge.daily_allowance then
    -- The limit just broke. Settle the consequence immediately so the
    -- feedback lands with the action, mirroring the engine's own rules.
    v_now_over := true;

    v_penalty := v_challenge.aura_penalty;
    select bp.id into v_consumable
    from public.benefit_purchases bp
    join public.benefits b on b.id = bp.benefit_id
    where bp.challenge_id = p_challenge_id and bp.user_id = v_user_id
      and bp.consumed_at is null and b.title = 'Half Damage'
    order by bp.created_at limit 1;
    if found then
      v_penalty := ceil(v_penalty / 2.0)::int;
      update public.benefit_purchases
        set consumed_at = now() where id = v_consumable;
      insert into public.settlement_events
        (user_id, challenge_id, kind, amount, period_start)
      values (v_user_id, p_challenge_id, 'half_damage', null, v_period_start);
    end if;

    update public.challenge_participants
    set challenge_aura = greatest(0, challenge_aura - v_penalty),
        periods_missed = periods_missed + 1
    where id = v_participant.id;
    insert into public.settlement_events
      (user_id, challenge_id, kind, amount, period_start)
    values (v_user_id, p_challenge_id, 'penalty', -v_penalty, v_period_start);

    select bp.id into v_consumable
    from public.benefit_purchases bp
    join public.benefits b on b.id = bp.benefit_id
    where bp.challenge_id = p_challenge_id and bp.user_id = v_user_id
      and bp.consumed_at is null and b.title = 'Streak Shield'
    order by bp.created_at limit 1;
    if found then
      v_shielded := true;
      update public.benefit_purchases
        set consumed_at = now() where id = v_consumable;
      insert into public.settlement_events
        (user_id, challenge_id, kind, amount, period_start)
      values (v_user_id, p_challenge_id, 'shield_saved', null, v_period_start);
    else
      v_struck := true;
      update public.challenge_participants
      set strikes_used = strikes_used + 1
      where id = v_participant.id;
      insert into public.settlement_events
        (user_id, challenge_id, kind, amount, period_start)
      values (v_user_id, p_challenge_id, 'strike',
              v_participant.strikes_used + 1, v_period_start);
    end if;

    -- Marker: settlement must not charge for this period again.
    insert into public.settlement_events
      (user_id, challenge_id, kind, amount, period_start)
    values (v_user_id, p_challenge_id, 'slip_over', v_count, v_period_start);

    -- Out of strikes? Let the canonical engine end the quest properly
    -- (failure, elimination, LMS crowning).
    if v_struck and v_participant.strikes_used + 1 > v_challenge.max_strikes then
      perform public.settle_periods();
    end if;
  end if;

  select challenge_aura into v_penalty
  from public.challenge_participants where id = v_participant.id;

  return jsonb_build_object(
    'count', v_count,
    'allowance', v_challenge.daily_allowance,
    'over', v_already_over or v_now_over,
    'just_failed', v_now_over,
    'struck', v_struck,
    'shielded', v_shielded,
    'aura', v_penalty
  );
end;
$$;

revoke execute on function public.log_slip(uuid) from public, anon;
grant  execute on function public.log_slip(uuid) to authenticated;

-- ── 4. Undo a mis-tap ───────────────────────────────────────────
create or replace function public.undo_last_slip(p_challenge_id uuid)
returns jsonb
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

revoke execute on function public.undo_last_slip(uuid) from public, anon;
grant  execute on function public.undo_last_slip(uuid) to authenticated;
