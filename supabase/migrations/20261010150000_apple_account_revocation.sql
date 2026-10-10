-- Only the NAS worker can read encrypted provider tokens or mark revocation.
create table public.apple_revoke_tokens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  apple_sub text not null check (length(apple_sub) between 1 and 255),
  encrypted_token text not null check (encrypted_token like 'v1.%'),
  token_version uuid not null default gen_random_uuid(),
  revoked_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.apple_revoke_tokens enable row level security;
revoke all on public.apple_revoke_tokens from public, anon, authenticated;
grant select, insert, update, delete on public.apple_revoke_tokens to service_role;

-- Preserve the inspected, transactional deletion implementation, including its
-- game-state lock. Reject direct calls from older apps until Apple is revoked.
do $$
declare definition text;
begin
  definition := pg_get_functiondef('public.delete_my_account()'::regprocedure);
  if position('perform public.lock_game_state();' in definition)=0 then
    raise exception 'Expected transactional account-deletion baseline missing';
  end if;
  definition := replace(definition, '  perform public.lock_game_state();',
  $guard$  perform public.lock_game_state();
  if (exists(select 1 from auth.identities where user_id=auth.uid() and provider='apple')
      or exists(select 1 from public.apple_revoke_tokens where user_id=auth.uid()))
     and not exists(select 1 from public.apple_revoke_tokens t
       where t.user_id=auth.uid() and t.revoked_at is not null
         and (not exists(select 1 from auth.identities where user_id=t.user_id and provider='apple')
           or exists(select 1 from auth.identities i where i.user_id=t.user_id and i.provider='apple'
             and coalesce(i.identity_data->>'sub',i.provider_id)=t.apple_sub))) then
    raise exception 'Apple authorization must be revoked before deleting this account.';
  end if;
  $guard$);
  execute definition;
end $$;
