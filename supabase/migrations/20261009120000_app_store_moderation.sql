-- App Store moderation baseline for player names and quest copy.
-- The application provides an immediate client-side hint; this server-side
-- trigger remains authoritative for direct API/RPC writes.

create table public.content_filter_terms (
  term text primary key check (term = lower(term) and term ~ '^[a-z0-9]+$'),
  created_at timestamptz not null default now()
);

insert into public.content_filter_terms (term) values
  ('arschloch'), ('bastard'), ('bitch'), ('cunt'), ('dick'), ('fag'),
  ('faggot'), ('fuck'), ('fucker'), ('fucking'), ('hure'), ('huerensohn'), ('hurensohn'),
  ('motherfucker'), ('nigger'), ('nutte'), ('piss'), ('porn'), ('pussy'),
  ('scheisse'), ('schlampe'), ('schwanz'), ('schwuchtel'), ('shit'),
  ('slut'), ('whore'), ('wichser')
on conflict (term) do nothing;

alter table public.content_filter_terms enable row level security;
revoke all on public.content_filter_terms from public, anon, authenticated;
grant select on public.content_filter_terms to service_role;

create or replace function public.is_user_content_allowed(p_content text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_normalized text;
begin
  v_normalized := pg_catalog.lower(coalesce(p_content, ''));
  v_normalized := pg_catalog.replace(v_normalized, 'ä', 'ae');
  v_normalized := pg_catalog.replace(v_normalized, 'ö', 'oe');
  v_normalized := pg_catalog.replace(v_normalized, 'ü', 'ue');
  v_normalized := pg_catalog.replace(v_normalized, 'ß', 'ss');
  v_normalized := pg_catalog.regexp_replace(v_normalized, '[^a-z0-9]+', ' ', 'g');

  return not exists (
    select 1
    from public.content_filter_terms as blocked
    where v_normalized ~ (
      '(^|[^a-z0-9])'
      || pg_catalog.regexp_replace(
        blocked.term,
        '(.)',
        E'\\1[^a-z0-9]*',
        'g'
      )
      || '([^a-z0-9]|$)'
    )
  );
end;
$$;

revoke all on function public.is_user_content_allowed(text)
  from public, anon, authenticated;
grant execute on function public.is_user_content_allowed(text) to service_role;

create or replace function public.reject_objectionable_user_content()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_content text;
begin
  if tg_table_name = 'profiles' then
    v_content := new.username;
  else
    v_content := coalesce(new.title, '') || ' ' || coalesce(new.description, '');
  end if;

  if not public.is_user_content_allowed(v_content) then
    raise exception using
      errcode = 'P0001',
      message = 'Text blocked by community content rules.';
  end if;

  return new;
end;
$$;

revoke all on function public.reject_objectionable_user_content()
  from public, anon, authenticated;

create trigger profiles_content_filter
  before insert or update of username on public.profiles
  for each row execute function public.reject_objectionable_user_content();

create trigger challenges_content_filter
  before insert or update of title, description on public.challenges
  for each row execute function public.reject_objectionable_user_content();

-- Federated providers derive the initial username from auth metadata or the
-- email local-part. Use a neutral generated handle when either is blocked so
-- an offensive address can never prevent an otherwise valid account signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  base_name text;
  fallback_name text;
begin
  base_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'username'), ''),
    split_part(new.email, '@', 1)
  );
  base_name := left(base_name, 24);
  if char_length(base_name) < 3 then
    base_name := base_name || left(replace(new.id::text, '-', ''), 4);
  end if;

  if not public.is_user_content_allowed(base_name) then
    fallback_name := 'player_' || left(replace(new.id::text, '-', ''), 8);
    base_name := fallback_name;
  end if;

  begin
    insert into public.profiles (id, username) values (new.id, base_name);
  exception when unique_violation then
    begin
      insert into public.profiles (id, username)
      values (new.id, left(base_name, 19) || '_' || left(replace(new.id::text, '-', ''), 4));
    exception when unique_violation then
      insert into public.profiles (id, username)
      values (new.id, left(base_name, 14) || '_' || substr(replace(new.id::text, '-', ''), 1, 9));
    end;
  end;
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

-- Reports already enter this table through report_user(). These fields give
-- the operator a minimal, auditable triage queue in Supabase Studio.
alter table public.user_reports
  add column moderation_status text not null default 'new'
    check (moderation_status in ('new', 'reviewed', 'action_taken', 'no_action')),
  add column moderation_reviewed_at timestamptz,
  add column moderation_action text,
  add column moderation_notes text
    check (moderation_notes is null or char_length(moderation_notes) <= 2000);

create index user_reports_moderation_queue_idx
  on public.user_reports (moderation_status, created_at asc);

grant select, update on public.user_reports to service_role;
