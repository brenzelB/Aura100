begin;

select plan(9);

select ok(
  public.is_user_content_allowed('Daily reading and a calm morning'),
  'ordinary quest text remains allowed'
);

select ok(
  not public.is_user_content_allowed('This name contains f.u.c.k.'),
  'punctuation cannot bypass the profanity filter'
);

select ok(
  not public.is_user_content_allowed('This name contains f u c k.'),
  'spaces cannot bypass the profanity filter'
);

select ok(
  not public.is_user_content_allowed('Hürensohn'),
  'German umlauts are normalized before matching'
);

select ok(
  public.is_user_content_allowed('classic fitness challenge'),
  'matching is by whole word, not an accidental substring'
);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000111', 'f.u.c.k@example.invalid',
   '{"username":"f.u.c.k"}');

select ok(
  (select username like 'player_%' from public.profiles
   where id = '00000000-0000-0000-0000-000000000111'),
  'blocked signup name is replaced with a neutral handle'
);

select throws_ok(
  $$update public.profiles set username = 'f.u.c.k'
    where id = '00000000-0000-0000-0000-000000000111'$$,
  'P0001', null, 'profile rename filter is enforced by the database'
);

select throws_ok(
  $$insert into public.challenges
    (id, creator_id, title, description, starts_on, duration_days,
     aura_gain, aura_penalty, max_strikes, goal_type, target_value, unit,
     mode, is_endless)
    values
    ('10000000-0000-0000-0000-000000000111',
     '00000000-0000-0000-0000-000000000111', 'f.u.c.k', 'A clean description',
     current_date, 7, 100, 25, 3, 'check', null, null, 'solo', true)$$,
  'P0001', null, 'challenge creation filter is enforced by the database'
);

insert into public.challenges
  (id, creator_id, title, description, starts_on, duration_days,
   aura_gain, aura_penalty, max_strikes, goal_type, target_value, unit,
   mode, is_endless)
values
  ('10000000-0000-0000-0000-000000000112',
   '00000000-0000-0000-0000-000000000111', 'Reading', 'Read a little',
   current_date, 7, 100, 25, 3, 'check', null, null, 'solo', true);

select throws_ok(
  $$update public.challenges set description = 'H.u.r.e.n.s.o.h.n'
    where id = '10000000-0000-0000-0000-000000000112'$$,
  'P0001', null, 'challenge edits are also filtered by the database'
);

select * from finish();
rollback;
