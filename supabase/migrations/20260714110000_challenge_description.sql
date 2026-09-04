-- ═════════════════════════════════════════════════════════════════
--  AURA QUEST - challenge descriptions (for the detail view)
--  Adds challenges.description and create_challenge v3 that accepts it.
-- ═════════════════════════════════════════════════════════════════

alter table public.challenges
  add column description text not null default ''
  check (char_length(description) <= 500);

-- Signature changes again -> drop v2, create v3 (keeping ONE overload
-- avoids PostgREST ambiguity when the client omits defaulted params).
drop function public.create_challenge(text, integer, integer, integer, integer, date);

create or replace function public.create_challenge(
  p_title text,
  p_duration_days integer,
  p_aura_gain integer,
  p_aura_penalty integer,
  p_max_strikes integer default 1,
  p_starts_on date default null,
  p_description text default ''
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_challenge_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;
  if p_title is null or length(trim(p_title)) between 1 and 80 is not true then
    raise exception 'Title must be 1-80 characters.';
  end if;
  if char_length(coalesce(p_description, '')) > 500 then
    raise exception 'Description must be at most 500 characters.';
  end if;
  if p_duration_days not between 1 and 365 then
    raise exception 'Duration must be 1-365 days.';
  end if;
  if p_aura_gain not between 0 and 10000 or p_aura_penalty not between 0 and 10000 then
    raise exception 'Aura values must be 0-10000.';
  end if;
  if p_max_strikes not between 0 and 10 then
    raise exception 'Strikes must be 0-10.';
  end if;

  insert into public.challenges
    (creator_id, title, description, duration_days, aura_gain, aura_penalty,
     max_strikes, starts_on)
  values
    (v_user_id, trim(p_title), coalesce(trim(p_description), ''),
     p_duration_days, p_aura_gain, p_aura_penalty, p_max_strikes,
     coalesce(p_starts_on, (now() at time zone 'utc')::date))
  returning id into v_challenge_id;

  insert into public.challenge_participants (challenge_id, user_id)
  values (v_challenge_id, v_user_id);

  insert into public.benefits (challenge_id, title, description, cost) values
    (v_challenge_id, 'Title Badge',
     'A golden badge on this quest - pure flex.', 50),
    (v_challenge_id, 'Half Damage',
     'Your next missed day costs only half the penalty.', 150),
    (v_challenge_id, 'Streak Shield',
     'One missed day is forgiven - no strike.', 300);

  return v_challenge_id;
end;
$$;

revoke execute on function
  public.create_challenge(text, integer, integer, integer, integer, date, text)
  from public, anon;
grant execute on function
  public.create_challenge(text, integer, integer, integer, integer, date, text)
  to authenticated;
