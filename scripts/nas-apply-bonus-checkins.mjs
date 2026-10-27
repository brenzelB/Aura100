// --verify: backup and test a disposable, isolated NAS database copy.
// --apply: after verification, apply only this migration to the exact baseline.
// Never access live PostgreSQL data files over SMB or run Docker on this PC.
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
import { createHash } from 'node:crypto';

const name = '20261027120000_optional_bonus_checkins.sql';
const previous = '20261017120000_roast_duels_without_wagers.sql';
const migration = readFileSync(`supabase/migrations/${name}`, 'utf8').replace(/^\uFEFF/, '');
const digest = createHash('sha256').update(migration).digest('hex');
const docker = '/usr/bin/docker';
function remote(command, input = '') {
  const result = spawnSync('ssh', ['-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
    '-o', 'ConnectTimeout=8', '-i', homedir() + '/.ssh/auraquest_nas',
    'denzel@192.168.178.123', command], { input, encoding: 'utf8', maxBuffer: 20_000_000 });
  if (result.status !== 0) throw new Error(result.stderr || result.stdout || 'SSH failed');
  return result.stdout;
}
function sql(container, input) {
  if (!/^(auraquest-db|auraquest-bonus-test-[0-9]+)$/.test(container)) throw new Error('Unexpected target');
  return remote(`${docker} exec -i ${container} psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -At`, input);
}
const current = sql('auraquest-db', `begin read only;
select name || ':' || sha256 from aura_admin.applied_migrations order by name; rollback;`);
if (current.includes(`${name}:${digest}`)) {
  console.log('Bonus migration already applied with matching digest.');
  process.exit(0);
}
const rows = current.trim().split('\n').filter(row => row.includes('.sql:'));
if (rows.length !== 14 || !rows.at(-1).startsWith(`${previous}:`)) {
  throw new Error('Unexpected migration baseline. Inspect before deployment.');
}
for (const row of rows) {
  const [file, expected] = row.split(':');
  const contents = readFileSync(`supabase/migrations/${file}`, 'utf8').replace(/^\uFEFF/, '');
  if (createHash('sha256').update(contents).digest('hex') !== expected) {
    throw new Error(`Baseline digest mismatch: ${file}`);
  }
}
const apply = process.argv.includes('--apply');
if (!apply && !process.argv.includes('--verify')) {
  console.log('Verified 14-migration baseline. Use --verify for isolated restore/tests, or --apply to deploy after them.');
  process.exit(0);
}
const stamp = new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 14);
const backup = `/volume2/Datenbanken/AuraQuest/backups/bonus-before-${stamp}.dump`;
const test = `auraquest-bonus-test-${stamp}`;
const suites = ['community_content_filter', 'balance_regressions', 'audit_regressions',
  'push_delivery_regressions', 'lifecycle_regressions', 'duel_regressions',
  'privilege_regressions', 'apple_account_revocation', 'roast_duel_regressions', 'bonus_checkin_regressions'];
remote(`set -eu; umask 077; ${docker} exec auraquest-db pg_dump -U postgres -d postgres -Fc > '${backup}'; ${docker} exec -i auraquest-db pg_restore -l < '${backup}' > /dev/null`);
console.log('Archive validated: ' + backup);
let created = false;
try {
  remote(`${docker} run -d --rm --name ${test} --network none --label org.auraquest.workflow=bonus-checkins-test -e POSTGRES_PASSWORD=isolated-test-only supabase/postgres:17.6.1.136 postgres -c shared_preload_libraries=pg_cron,pg_net -c cron.database_name=postgres -c cron.launch_active_jobs=off`);
  created = true;
  remote(`set -eu; for attempt in $(seq 1 40); do ${docker} exec ${test} pg_isready -h 127.0.0.1 -U postgres > /dev/null 2>&1 && exit 0; sleep 1; done; exit 1`);
  remote(`${docker} exec ${test} psql -X -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -c 'alter role postgres superuser'`);
  sql(test, `do $$ begin
    if not exists(select 1 from pg_roles where rolname='supabase_realtime_admin') then create role supabase_realtime_admin; end if;
    if not exists(select 1 from pg_roles where rolname='supabase_functions_admin') then create role supabase_functions_admin; end if;
  end $$;`);
  remote(`${docker} exec ${test} psql -X -U supabase_admin -d template1 -v ON_ERROR_STOP=1 -c 'drop database postgres with (force)'`);
  remote(`${docker} exec ${test} psql -X -U supabase_admin -d template1 -v ON_ERROR_STOP=1 -c 'create database postgres owner postgres template template0'`);
  remote(`${docker} exec -i ${test} pg_restore -U postgres -d postgres --exit-on-error < '${backup}'`);
  sql(test, `update cron.job set active=false; create extension if not exists pgtap; begin;
${migration}
commit;`);
  const results = [];
  for (const suite of suites) {
    const output = sql(test, readFileSync(`supabase/tests/${suite}.sql`, 'utf8'));
    if (/^not ok\b|Looks like you (failed|planned)/m.test(output)) throw new Error(`Regression failed: ${suite}\n${output}`);
    results.push(`Passed: ${suite}\n${output}`);
    console.log('Passed: ' + suite);
  }
  mkdirSync('build/audit', { recursive: true });
  writeFileSync('build/audit/bonus-isolated-tests.txt',
    `Fresh NAS backup restored with network none: ${backup}\nMigration SHA256: ${digest}\n${results.join('\n')}`);
  if (!apply) {
    console.log('All suites passed in the isolated restore. Active database unchanged.');
  } else {
    const deploy = `begin; set local lock_timeout='15s'; set local statement_timeout='120s';
      select pg_advisory_xact_lock(104857601::bigint);
      do $$ begin
        if (select count(*) from aura_admin.applied_migrations)<>14
          or not exists(select 1 from aura_admin.applied_migrations where name='${previous}')
          or exists(select 1 from information_schema.columns where table_schema='public' and table_name='check_ins' and column_name='is_bonus') then
          raise exception 'Migration baseline changed; rolling back';
        end if;
      end $$;
      create temporary table bonus_before as select
        (select md5(string_agg(row_to_json(p)::text,',' order by id)) from public.challenge_participants p) as participants,
        (select md5(string_agg(row_to_json(c)::text,',' order by id)) from public.challenges c) as quests,
        (select count(*) from public.check_ins) as checkins,
        (select coalesce(sum(xp),0) from public.player_xp_events) as xp,
        (select count(*) from auth.users) as accounts;
      ${migration}
      do $$ begin
        if exists(select 1 from bonus_before where
          participants is distinct from (select md5(string_agg(row_to_json(p)::text,',' order by id)) from public.challenge_participants p)
          or quests is distinct from (select md5(string_agg(row_to_json(c)::text,',' order by id)) from public.challenges c)
          or checkins<>(select count(*) from public.check_ins)
          or xp<>(select coalesce(sum(xp),0) from public.player_xp_events)
          or accounts<>(select count(*) from auth.users))
          or exists(select 1 from public.check_ins where is_bonus) then
          raise exception 'Unexpected player data change';
        end if;
      end $$;
      insert into aura_admin.applied_migrations(name,sha256) values('${name}','${digest}');
      notify pgrst,'reload schema'; commit;
      select name,sha256 from aura_admin.applied_migrations where name='${name}';`;
    const output = sql('auraquest-db', deploy);
    writeFileSync('build/audit/bonus-deployment.txt', `Backup restored and all suites passed: ${backup}\n${output}`);
    console.log(output);
  }
} finally {
  if (created) remote(`${docker} stop ${test}`);
}
