-- =================================================================
--  AURA QUEST - Push, Stufe 4: Nachricht nachlesen
--
--  Ueber Firebase geht nur ein inhaltsleeres Wecksignal: Kategorie und
--  die ID der Warteschlangen-Zeile. Den Text holt sich die App danach
--  hier ab - von DIESEM Server, nicht von Google.
--
--  Die Funktion gibt ausschliesslich Zeilen des Aufrufers heraus. Wer
--  eine fremde ID errraet, bekommt nichts: Die Bedingung auf user_id
--  steht in der Abfrage selbst, nicht in einer Policy, die man mit
--  SECURITY DEFINER versehentlich umgeht.
-- =================================================================

create or replace function public.get_notification(p_id bigint)
returns table (
  category text,
  ref_id   uuid,
  title    text,
  body     text
)
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

  return query
  select o.category, o.ref_id, o.title, o.body
  from public.notification_outbox o
  where o.id = p_id
    and o.user_id = v_user_id;
end;
$$;

grant execute on function public.get_notification(bigint) to authenticated;
