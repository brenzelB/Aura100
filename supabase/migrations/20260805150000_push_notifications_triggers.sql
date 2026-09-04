-- =================================================================
--  AURA QUEST - Push-Benachrichtigungen, Stufe 2: Ausloeser
--
--  Legt fest, WANN eine Nachricht entsteht. Der Versand selbst kommt
--  in Stufe 3; hier faellt nur eine Zeile in die Warteschlange.
--
--  Alle Trigger sind AFTER-Trigger: Die Nachricht entsteht erst, wenn
--  das Ereignis feststeht. Ein spaeteres Rollback nimmt die Zeile
--  automatisch mit, weil sie in derselben Transaktion liegt.
--
--  GRUNDSATZ FUER DIE TEXTE: Sie beschreiben, was passiert ist, ohne
--  dass man die App oeffnen muss, um es zu verstehen. "Du wurdest
--  angegriffen" zwingt zum Nachsehen; "@bra hat dich fuer zwei Stunden
--  gesperrt" sagt es gleich. Der Ton bleibt der der App.
--
--  WAS ABSICHTLICH NICHT BENACHRICHTIGT:
--
--    * 'penalty' aus dem Abrechnungsmotor - kommt IMMER zusammen mit
--      'strike' oder 'failed'. Zwei Meldungen fuer einen Vorgang.
--    * Fehlgeschlagene Aura Heists - das Opfer merkt nichts davon, und
--      der Angreifer soll nicht durch eine Stille verraten werden.
--    * Eigene Handlungen - faengt enqueue_notification bereits ab.
-- =================================================================

-- ── Kleine Helfer ────────────────────────────────────────────────

create or replace function public.push_username(p_user_id uuid)
returns text
language sql
security definer
set search_path = ''
stable
as $$
  select coalesce('@' || username, 'Someone')
  from public.profiles where id = p_user_id;
$$;

create or replace function public.push_quest_title(p_challenge_id uuid)
returns text
language sql
security definer
set search_path = ''
stable
as $$
  select coalesce(title, 'a quest')
  from public.challenges where id = p_challenge_id;
$$;

-- ── Angriffe ─────────────────────────────────────────────────────

create or replace function public.notify_blackout()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.enqueue_notification(
    new.target_id,
    'attack',
    new.id,
    'You are blacked out',
    public.push_username(new.attacker_id) || ' locked you out of "' ||
    public.push_quest_title(new.challenge_id) ||
    '" for two hours. Nothing you log will count.'
  );
  return new;
end;
$$;

drop trigger if exists notify_blackout_trg on public.blackouts;
create trigger notify_blackout_trg
  after insert on public.blackouts
  for each row execute function public.notify_blackout();

create or replace function public.notify_aura_heist()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Nur der geglueckte Raub ist eine Nachricht wert.
  if not new.succeeded then
    return new;
  end if;
  perform public.enqueue_notification(
    new.target_id,
    'attack',
    new.id,
    'You have been robbed',
    public.push_username(new.attacker_id) || ' stole ' ||
    coalesce(new.stolen_amount, 0)::text || ' aura from you in "' ||
    public.push_quest_title(new.challenge_id) || '".'
  );
  return new;
end;
$$;

drop trigger if exists notify_aura_heist_trg on public.aura_heists;
create trigger notify_aura_heist_trg
  after insert on public.aura_heists
  for each row execute function public.notify_aura_heist();

create or replace function public.notify_targeted_roast()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.enqueue_notification(
    new.target_id,
    'attack',
    new.id,
    'You have been roasted',
    public.push_username(new.sender_id) || ' left you something in "' ||
    public.push_quest_title(new.challenge_id) || '". Brace yourself.'
  );
  return new;
end;
$$;

drop trigger if exists notify_targeted_roast_trg on public.targeted_roasts;
create trigger notify_targeted_roast_trg
  after insert on public.targeted_roasts
  for each row execute function public.notify_targeted_roast();

-- ── Duelle ───────────────────────────────────────────────────────

create or replace function public.notify_duel_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.enqueue_notification(
    new.opponent_id,
    'duel',
    new.id,
    'Duel!',
    public.push_username(new.challenger_id) || ' staked ' ||
    new.stake::text || ' aura against you in "' ||
    public.push_quest_title(new.challenge_id) ||
    '". You have 48 hours.'
  );
  return new;
end;
$$;

drop trigger if exists notify_duel_created_trg on public.duels;
create trigger notify_duel_created_trg
  after insert on public.duels
  for each row execute function public.notify_duel_created();

create or replace function public.notify_duel_resolved()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_quest text := public.push_quest_title(new.challenge_id);
begin
  if old.status = new.status then
    return new;
  end if;

  if new.status = 'resolved' then
    -- Beide erfahren den Ausgang. Wer gerade selbst gewuerfelt hat, sieht
    -- ihn schon auf dem Bildschirm - enqueue_notification filtert den
    -- Aufrufer heraus, also bleibt genau der andere uebrig.
    perform public.enqueue_notification(
      new.challenger_id, 'duel', new.id,
      case when new.winner_id = new.challenger_id
           then 'You won the duel' else 'You lost the duel' end,
      case when new.winner_id = new.challenger_id
           then 'You took ' || (new.stake * 2)::text || ' aura off ' ||
                public.push_username(new.opponent_id) || ' in "' || v_quest || '".'
           else public.push_username(new.opponent_id) || ' took your ' ||
                new.stake::text || ' aura in "' || v_quest || '".' end);
    perform public.enqueue_notification(
      new.opponent_id, 'duel', new.id,
      case when new.winner_id = new.opponent_id
           then 'You won the duel' else 'You lost the duel' end,
      case when new.winner_id = new.opponent_id
           then 'You took ' || (new.stake * 2)::text || ' aura off ' ||
                public.push_username(new.challenger_id) || ' in "' || v_quest || '".'
           else public.push_username(new.challenger_id) || ' took your ' ||
                new.stake::text || ' aura in "' || v_quest || '".' end);

  elsif new.status = 'declined' then
    perform public.enqueue_notification(
      new.challenger_id, 'duel', new.id,
      'Duel declined',
      public.push_username(new.opponent_id) ||
      ' turned your duel down. Your ' || new.stake::text ||
      ' aura is back.');

  elsif new.status = 'expired' then
    -- Der Cron laesst das Duell verfallen; auth.uid() ist dabei null,
    -- also bekommen beide Bescheid.
    perform public.enqueue_notification(
      new.challenger_id, 'duel', new.id,
      'Duel expired',
      'Nobody answered in 48 hours. Your ' || new.stake::text ||
      ' aura is back.');
  end if;

  return new;
end;
$$;

drop trigger if exists notify_duel_resolved_trg on public.duels;
create trigger notify_duel_resolved_trg
  after update of status on public.duels
  for each row execute function public.notify_duel_resolved();

-- ── Soziales ─────────────────────────────────────────────────────

create or replace function public.notify_invite()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status <> 'pending' then
    return new;
  end if;
  perform public.enqueue_notification(
    new.invitee_id,
    'social',
    new.challenge_id,
    'Quest invite',
    public.push_username(new.inviter_id) || ' wants you in "' ||
    public.push_quest_title(new.challenge_id) || '".'
  );
  return new;
end;
$$;

drop trigger if exists notify_invite_trg on public.invites;
create trigger notify_invite_trg
  after insert on public.invites
  for each row execute function public.notify_invite();

create or replace function public.notify_friend_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'pending' then
    perform public.enqueue_notification(
      new.addressee_id, 'social', new.id,
      'Friend request',
      public.push_username(new.requester_id) || ' wants to be quest mates.');
  end if;
  return new;
end;
$$;

drop trigger if exists notify_friend_request_trg on public.friendships;
create trigger notify_friend_request_trg
  after insert on public.friendships
  for each row execute function public.notify_friend_request();

create or replace function public.notify_friend_accepted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status = 'pending' and new.status = 'accepted' then
    perform public.enqueue_notification(
      new.requester_id, 'social', new.id,
      'Friend request accepted',
      public.push_username(new.addressee_id) || ' is in. Go start a quest.');
  end if;
  return new;
end;
$$;

drop trigger if exists notify_friend_accepted_trg on public.friendships;
create trigger notify_friend_accepted_trg
  after update of status on public.friendships
  for each row execute function public.notify_friend_accepted();

create or replace function public.notify_nudge()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.enqueue_notification(
    new.to_user,
    'social',
    new.challenge_id,
    'You got poked',
    public.push_username(new.from_user) || ' noticed you have not logged "' ||
    public.push_quest_title(new.challenge_id) || '" today.'
  );
  return new;
end;
$$;

drop trigger if exists notify_nudge_trg on public.nudges;
create trigger notify_nudge_trg
  after insert on public.nudges
  for each row execute function public.notify_nudge();

-- ── Quest-Verlauf ────────────────────────────────────────────────
--
--  Diese Zeilen entstehen im stuendlichen Abrechnungsmotor, also
--  ausserhalb jeder Nutzersitzung. Genau dafuer ist Push da: Der
--  Spieler haette es sonst erst beim naechsten Oeffnen erfahren.

create or replace function public.notify_settlement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_quest text;
begin
  -- 'penalty' bleibt bewusst aussen vor: Es begleitet immer 'strike'
  -- oder 'failed' und wuerde die Meldung verdoppeln.
  if new.kind not in ('strike', 'failed', 'completed') then
    return new;
  end if;

  v_quest := public.push_quest_title(new.challenge_id);

  perform public.enqueue_notification(
    new.user_id,
    'quest',
    new.challenge_id,
    case new.kind
      when 'strike'    then 'Strike'
      when 'failed'    then 'Quest lost'
      else                  'Quest complete'
    end,
    case new.kind
      when 'strike' then 'You missed a period in "' || v_quest ||
                         '". One strike against you.'
      when 'failed' then '"' || v_quest ||
                         '" is over for you. You are out of strikes.'
      else               'You finished "' || v_quest || '". Take a bow.'
    end
  );
  return new;
end;
$$;

drop trigger if exists notify_settlement_trg on public.settlement_events;
create trigger notify_settlement_trg
  after insert on public.settlement_events
  for each row execute function public.notify_settlement();
