-- Replace wagering with consensual, free rock-paper-scissors. Existing dice
-- records stay historical; unresolved escrow is returned once. No new game RPC
-- changes Aura, lifetime XP, purchases, check-ins or quest progress.
select public.lock_game_state();
alter table public.settlement_events add column game_roast_key smallint
 check(game_roast_key between 0 and 39);

create table public.roast_duels (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  challenger_id uuid not null references public.profiles(id) on delete cascade,
  opponent_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check(status in ('pending','active','resolved','declined','expired')),
  round_number integer not null default 1 check(round_number>0),
  challenger_score integer not null default 0 check(challenger_score between 0 and 3),
  opponent_score integer not null default 0 check(opponent_score between 0 and 3),
  last_challenger_move text check(last_challenger_move in ('rock','paper','scissors')),
  last_opponent_move text check(last_opponent_move in ('rock','paper','scissors')),
  winner_id uuid references public.profiles(id) on delete set null,
  roast_key integer not null check(roast_key between 0 and 39),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now()+interval '48 hours',
  resolved_at timestamptz,
  check(challenger_id<>opponent_id)
);
create unique index roast_duels_open_pair on public.roast_duels(
  challenge_id,least(challenger_id,opponent_id),greatest(challenger_id,opponent_id)
) where status in ('pending','active');
create index roast_duels_inbox on public.roast_duels(opponent_id,status);
create index roast_duels_outbox on public.roast_duels(challenger_id,status);
alter table public.roast_duels enable row level security;
revoke all on public.roast_duels from public,anon,authenticated;
grant select on public.roast_duels to authenticated;
create policy "roast duels: participants only" on public.roast_duels for select
  to authenticated using(auth.uid() in(challenger_id,opponent_id));

-- Never publish hidden choices to PostgREST, Realtime or the opponent. The
-- public duel row contains only the previous, fully revealed round.
create schema if not exists aura_private;
revoke all on schema aura_private from public,anon,authenticated;
create table aura_private.roast_duel_moves (
  duel_id uuid not null references public.roast_duels(id) on delete cascade,
  round_number integer not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  move text not null check(move in ('rock','paper','scissors')),
  primary key(duel_id,round_number,user_id)
);
revoke all on aura_private.roast_duel_moves from public,anon,authenticated;

create function public.roast_duel_allowed(p_quest uuid,p_a uuid,p_b uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select not public.is_blocked_pair(p_a,p_b)
 and exists(select 1 from public.challenges c where c.id=p_quest
   and c.lifecycle='active' and c.attacks_enabled
   and c.starts_on<=(now() at time zone 'utc')::date
   and (c.is_endless or c.starts_on+c.duration_days>(now() at time zone 'utc')::date))
 and (select count(*) from public.challenge_participants where challenge_id=p_quest
   and user_id in(p_a,p_b) and status='active')=2;
$$;
revoke all on function public.roast_duel_allowed(uuid,uuid,uuid) from public,anon,authenticated;

create function public.get_roast_duel(p_duel_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d public.roast_duels%rowtype; u uuid:=auth.uid();
begin
  if u is null then raise exception 'Not signed in.'; end if;
  select * into d from public.roast_duels where id=p_duel_id and u in(challenger_id,opponent_id);
  if not found then raise exception 'Duel not found.'; end if;
  if d.status in('pending','active') and
    (d.expires_at<=now() or not public.roast_duel_allowed(d.challenge_id,d.challenger_id,d.opponent_id)) then
    -- Fetch is read-only. Mutating RPCs/cron persist this terminal state.
    d.status:=case when d.expires_at<=now() then 'expired' else 'declined' end;
  end if;
  return to_jsonb(d)||jsonb_build_object('my_move',
    (select move from aura_private.roast_duel_moves where duel_id=d.id
      and round_number=d.round_number and user_id=u));
end $$;

create function public.create_roast_duel(p_challenge_id uuid,p_opponent_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); duel uuid:=gen_random_uuid();
begin
  perform public.lock_game_state();
  if u is null then raise exception 'Not signed in.'; end if;
  if p_opponent_id is null or p_opponent_id=u then raise exception 'Choose another player.'; end if;
  if not public.roast_duel_allowed(p_challenge_id,u,p_opponent_id) then
    raise exception 'Both players must be active in a running quest with duels enabled and must not be blocked.';
  end if;
  update public.roast_duels set status=case when expires_at<=now() then 'expired' else 'declined' end,resolved_at=now()
    where challenge_id=p_challenge_id and status in('pending','active')
      and (expires_at<=now() or not public.roast_duel_allowed(challenge_id,challenger_id,opponent_id));
  if (select count(*) from public.roast_duels where challenger_id=u
    and created_at>=date_trunc('day',now() at time zone 'utc') at time zone 'utc')>=10 then
    raise exception 'Ten invitations per day is enough. Let your ego recharge.';
  end if;
  insert into public.roast_duels(id,challenge_id,challenger_id,opponent_id,roast_key)
    values(duel,p_challenge_id,u,p_opponent_id,get_byte(decode(replace(duel::text,'-',''),'hex'),0)%40);
  return duel;
exception when unique_violation then raise exception 'There is already an open duel between you two here.';
end $$;

create function public.respond_roast_duel(p_duel_id uuid,p_accept boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d public.roast_duels%rowtype; u uuid:=auth.uid();
begin
  perform public.lock_game_state();
  if u is null then raise exception 'Not signed in.'; end if;
  if p_accept is null then raise exception 'Choose accept or decline.'; end if;
  select * into d from public.roast_duels where id=p_duel_id and opponent_id=u for update;
  if not found then raise exception 'Duel not found.'; end if;
  if d.status='pending' then
    update public.roast_duels set status=case
      when d.expires_at<=now() then 'expired'
      when not p_accept or not public.roast_duel_allowed(d.challenge_id,d.challenger_id,d.opponent_id) then 'declined'
      else 'active' end,
      resolved_at=case when d.expires_at<=now() or not p_accept
        or not public.roast_duel_allowed(d.challenge_id,d.challenger_id,d.opponent_id) then now() end
      where id=d.id;
  end if;
  return public.get_roast_duel(d.id);
end $$;

create function public.play_roast_duel(p_duel_id uuid,p_round integer,p_move text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d public.roast_duels%rowtype; u uuid:=auth.uid(); a text; b text;
  a_score integer; b_score integer; winner uuid;
begin
  perform public.lock_game_state();
  if u is null then raise exception 'Not signed in.'; end if;
  if p_move is null or p_move not in('rock','paper','scissors') then raise exception 'Choose rock, paper or scissors.'; end if;
  select * into d from public.roast_duels where id=p_duel_id and u in(challenger_id,opponent_id) for update;
  if not found then raise exception 'Duel not found.'; end if;
  if d.status<>'active' then return public.get_roast_duel(d.id); end if;
  if d.expires_at<=now() or not public.roast_duel_allowed(d.challenge_id,d.challenger_id,d.opponent_id) then
    update public.roast_duels set status=case when d.expires_at<=now() then 'expired' else 'declined' end,
      resolved_at=now() where id=d.id;
    return public.get_roast_duel(d.id);
  end if;
  -- Retries cannot submit into the next round or replace a locked choice.
  if p_round is null or p_round<>d.round_number then return public.get_roast_duel(d.id); end if;
  insert into aura_private.roast_duel_moves(duel_id,round_number,user_id,move)
    values(d.id,p_round,u,p_move) on conflict do nothing;
  select move into a from aura_private.roast_duel_moves where duel_id=d.id and round_number=p_round and user_id=d.challenger_id;
  select move into b from aura_private.roast_duel_moves where duel_id=d.id and round_number=p_round and user_id=d.opponent_id;
  if a is null or b is null then
    -- Publish only a harmless round UPDATE so the other device can refresh.
    update public.roast_duels set round_number=round_number where id=d.id;
    return public.get_roast_duel(d.id);
  end if;
  a_score:=d.challenger_score; b_score:=d.opponent_score;
  if a<>b then
    if (a='rock' and b='scissors') or (a='scissors' and b='paper') or (a='paper' and b='rock') then
      a_score:=a_score+1;
    else b_score:=b_score+1; end if;
  end if;
  winner:=case when a_score=3 then d.challenger_id when b_score=3 then d.opponent_id end;
  update public.roast_duels set last_challenger_move=a,last_opponent_move=b,
    challenger_score=a_score,opponent_score=b_score,round_number=p_round+1,
    status=case when winner is null then 'active' else 'resolved' end,
    winner_id=winner,resolved_at=case when winner is not null then now() end where id=d.id;
  -- Historical choices are unnecessary personal data once the round is revealed.
  delete from aura_private.roast_duel_moves where duel_id=d.id and round_number=p_round;
  if winner is not null then
    insert into public.settlement_events(user_id,challenge_id,kind,amount,game_roast_key) values
      (winner,d.challenge_id,'duel_won',0,null),
      (case when winner=d.challenger_id then d.opponent_id else d.challenger_id end,d.challenge_id,'duel_lost',0,d.roast_key);
  end if;
  return public.get_roast_duel(d.id);
end $$;

create function public.notify_roast_duel() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid;
begin
  if tg_op='INSERT' then
    perform public.enqueue_notification(new.opponent_id,'duel',new.id,'Ego duel!',
      public.push_username(new.challenger_id)||' challenges you. Rock, paper, scissors. Free to play; the loser gets roasted.');
  elsif new.status='resolved' and old.status<>'resolved' then
    perform public.enqueue_notification(new.challenger_id,'duel',new.id,
      case when new.winner_id=new.challenger_id then 'Ego intact.' else 'Ego: lightly toasted.' end,
      'Your duel is over. Open Aura Quest for the score and the roast. Aura and XP stay unchanged.');
    perform public.enqueue_notification(new.opponent_id,'duel',new.id,
      case when new.winner_id=new.opponent_id then 'Ego intact.' else 'Ego: lightly toasted.' end,
      'Your duel is over. Open Aura Quest for the score and the roast. Aura and XP stay unchanged.');
  elsif new.status='active' and old.status='pending' then
    perform public.enqueue_notification(new.challenger_id,'duel',new.id,'Challenge accepted.',
      'Both players choose in secret. First to three wins.');
  elsif new.status='active' and new.round_number<>old.round_number then
    recipient:=case when auth.uid()=new.challenger_id then new.opponent_id else new.challenger_id end;
    perform public.enqueue_notification(recipient,'duel',new.id,'Next round. Same ego.',
      'The last round is revealed. Make your next move in Aura Quest.');
  end if;
  return new;
end $$;
create trigger notify_roast_duel_trg after insert or update on public.roast_duels
  for each row execute function public.notify_roast_duel();

create function public.expire_roast_duels() returns void
language plpgsql security definer set search_path='' as $$
begin
  perform public.lock_game_state();
  update public.roast_duels set status=case when expires_at<=now() then 'expired' else 'declined' end,resolved_at=now()
    where status in('pending','active')
      and (expires_at<=now() or not public.roast_duel_allowed(challenge_id,challenger_id,opponent_id));
  delete from aura_private.roast_duel_moves m using public.roast_duels d
    where m.duel_id=d.id and d.status not in('pending','active');
end $$;

revoke all on function public.get_roast_duel(uuid),public.create_roast_duel(uuid,uuid),
 public.respond_roast_duel(uuid,boolean),public.play_roast_duel(uuid,integer,text),
 public.notify_roast_duel(),public.expire_roast_duels() from public,anon,authenticated;
grant execute on function public.get_roast_duel(uuid),public.create_roast_duel(uuid,uuid),
 public.respond_roast_duel(uuid,boolean),public.play_roast_duel(uuid,integer,text) to authenticated;
select cron.schedule('expire-roast-duels','17 * * * *','select public.expire_roast_duels();');
alter publication supabase_realtime add table public.roast_duels;

create function public.close_blocked_roast_duels() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 perform public.lock_game_state();
 update public.roast_duels set status='declined',resolved_at=now()
   where status in('pending','active') and
     ((challenger_id=new.blocker_id and opponent_id=new.blocked_id)
       or (opponent_id=new.blocker_id and challenger_id=new.blocked_id));
 delete from aura_private.roast_duel_moves m using public.roast_duels d
   where m.duel_id=d.id and d.status='declined';
 return new;
end $$;
revoke all on function public.close_blocked_roast_duels() from public,anon,authenticated;
create trigger close_blocked_roast_duels_trg after insert on public.user_blocks
 for each row execute function public.close_blocked_roast_duels();

-- Retire monetary game mechanics on the server as well as in the new UI.
-- Disable old push copy before closing old escrow offers.
drop trigger if exists notify_duel_created_trg on public.duels;
drop trigger if exists notify_duel_resolved_trg on public.duels;
with closed as (
 update public.duels set status='expired',resolved_at=now() where status='pending'
 returning challenge_id,challenger_id,stake
), refunds as(select challenge_id,challenger_id,sum(stake)::integer amount from closed group by 1,2)
update public.challenge_participants p set challenge_aura=p.challenge_aura+r.amount from refunds r
 where p.challenge_id=r.challenge_id and p.user_id=r.challenger_id;

create or replace function public.create_duel(p_challenge_id uuid,p_opponent_id uuid,p_stake integer)
returns uuid language plpgsql security definer set search_path='' as $$
begin raise exception 'Dice wagers have retired. Update Aura Quest for free Ego Duels.'; end $$;
create or replace function public.respond_to_duel(p_duel_id uuid,p_accept boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d public.duels%rowtype; result text;
begin
 perform public.lock_game_state();
 if auth.uid() is null then raise exception 'Not signed in.'; end if;
 if p_accept is null then raise exception 'Choose accept or decline.'; end if;
 select * into d from public.duels where id=p_duel_id and opponent_id=auth.uid() for update;
 if not found then raise exception 'Duel not found.'; end if;
 if d.status='pending' then
   result:=case when d.expires_at<=now() then 'expired' else 'declined' end;
   update public.duels set status=result,resolved_at=now() where id=d.id;
   update public.challenge_participants set challenge_aura=challenge_aura+d.stake
     where challenge_id=d.challenge_id and user_id=d.challenger_id;
 else result:=d.status; end if;
 return jsonb_build_object('status',result);
end $$;

with closed as (
 update public.aura_heists set resolved_at=now(),stolen_amount=0,acknowledged_at=now()
 where resolved_at is null returning challenge_id,attacker_id,cost
), refunds as(select challenge_id,attacker_id,sum(cost)::integer amount from closed group by 1,2)
update public.challenge_participants p set challenge_aura=p.challenge_aura+r.amount from refunds r
 where p.challenge_id=r.challenge_id and p.user_id=r.attacker_id;
-- Historic transfers remain recorded, but must not trigger a retired game's
-- animated reveal after a new, ordinary check-in.
update public.aura_heists set acknowledged_at=now() where acknowledged_at is null;
create or replace function public.attempt_aura_heist(p_challenge_id uuid,p_target_id uuid,p_tier integer)
returns jsonb language plpgsql security definer set search_path='' as $$
begin raise exception 'Random Aura Heists have retired. Update Aura Quest for free Ego Duels.'; end $$;
create or replace function public.resolve_checkin_heist(p_quest uuid,p_user uuid,p_gain integer,p_base integer)
returns integer language sql security definer set search_path='' as $$ select p_gain; $$;

-- Old perk IDs remain in history, but cannot be bought from an old app either.
create function public.guard_retired_game_perks() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.benefits where id=new.benefit_id and title in('Aura Heist','Aura Ward')) then
   raise exception 'This perk has retired. Update Aura Quest for free Ego Duels.';
 end if;
 return new;
end $$;
revoke all on function public.guard_retired_game_perks() from public,anon,authenticated;
create trigger guard_retired_game_perks_trg before insert on public.benefit_purchases
 for each row execute function public.guard_retired_game_perks();

-- A life-stat reset also clears the player's free-game records, including their
-- private pending choices. Existing active-quest reset guards remain intact.
do $$ declare definition text; begin
 definition:=pg_get_functiondef('public.reset_my_stats()'::regprocedure);
 definition:=replace(definition,'delete from public.player_xp_events where user_id = v_user_id;',
   'delete from public.roast_duels where v_user_id in(challenger_id,opponent_id); delete from public.player_xp_events where user_id = v_user_id;');
 execute definition;
end $$;
