-- =================================================================
--  AURA QUEST - tidy up the trophy room
--
--  A finished quest can be removed from YOUR trophy list. It is a
--  soft hide on purpose: the participation row itself must stay, or
--  versus scoring (which counts participants) and the quest history
--  of the other players would silently change.
-- =================================================================

alter table public.challenge_participants
  add column trophy_hidden_at timestamptz;

create or replace function public.hide_trophy(p_challenge_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_updated integer;
begin
  if v_user_id is null then
    raise exception 'Not signed in.';
  end if;

  update public.challenge_participants
  set trophy_hidden_at = now()
  where challenge_id = p_challenge_id
    and user_id = v_user_id
    and status in ('completed', 'failed')
    and trophy_hidden_at is null;

  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    raise exception 'No finished quest to remove here.';
  end if;
end;
$$;

revoke execute on function public.hide_trophy(uuid) from public, anon;
grant  execute on function public.hide_trophy(uuid) to authenticated;
