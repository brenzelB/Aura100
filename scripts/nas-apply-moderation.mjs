// Applies only the Apple moderation migration to the inspected NAS baseline.
// PostgreSQL data files are never accessed over SMB. Secrets stay on the NAS.
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
import { createHash } from 'node:crypto';

const name = '20261009120000_app_store_moderation.sql';
const migration = readFileSync(`supabase/migrations/${name}`, 'utf8').replace(/^\uFEFF/, '');
const digest = createHash('sha256').update(migration).digest('hex');
const host = 'denzel@192.168.178.123';
const docker = '/usr/bin/docker';
function remote(command, input = '') {
  const result = spawnSync('ssh', ['-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
    '-o', 'ConnectTimeout=8', '-i', homedir() + '/.ssh/auraquest_nas', host, command],
    { input, encoding: 'utf8', maxBuffer: 20_000_000 });
  if (result.status !== 0) throw new Error(result.stderr || result.stdout || 'SSH failed');
  return result.stdout;
}
function sql(container, input) {
  if (!/^(auraquest-db|auraquest-moderation-test-[0-9]+)$/.test(container)) throw new Error('Unexpected target');
  return remote(`${docker} exec -i ${container} psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -At`, input);
}
const current = sql('auraquest-db', `begin read only;
select name || ':' || sha256 from aura_admin.applied_migrations order by name; rollback;`);
if (current.includes(`${name}:${digest}`)) {
  console.log('Moderation migration is already applied with the matching digest.');
  process.exit(0);
}
const rows = current.trim().split('\n').filter(row => row.includes('.sql:'));
if (rows.length !== 11 || !rows.at(-1).startsWith('20260909075449_reset_lifetime_xp.sql:')) {
  throw new Error('Unexpected migration baseline. Inspect before deployment.');
}
for (const row of rows) {
  const [file, expected] = row.split(':');
  const contents = readFileSync(`supabase/migrations/${file}`, 'utf8').replace(/^\uFEFF/, '');
  const actual = createHash('sha256').update(contents).digest('hex');
  if (actual !== expected) throw new Error(`Baseline digest mismatch: ${file}`);
}
if (!process.argv.includes('--apply')) {
  console.log(`Verified 11-migration baseline. --apply backs up, restores and tests an isolated NAS copy before applying ${name}.`);
  process.exit(0);
}
const stamp = new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 14);
const backup = `/volume2/Datenbanken/AuraQuest/backups/apple-moderation-before-${stamp}.dump`;
const test = `auraquest-moderation-test-${stamp}`;
remote(`set -eu; umask 077; ${docker} exec auraquest-db pg_dump -U postgres -d postgres -Fc > '${backup}'; ${docker} exec -i auraquest-db pg_restore -l < '${backup}' > /dev/null`);
console.log('Archive validated: ' + backup);
let created = false;
try {
  remote(`${docker} run -d --rm --name ${test} --network none --label org.auraquest.workflow=apple-moderation-test -e POSTGRES_PASSWORD=isolated-test-only supabase/postgres:17.6.1.136 postgres -c shared_preload_libraries=pg_cron,pg_net -c cron.database_name=postgres -c cron.launch_active_jobs=off`);
  created = true;
  // TCP becomes ready only after the image's temporary initialization server
  // has exited, avoiding a restore racing that server's shutdown.
  remote(`set -eu; for attempt in $(seq 1 40); do ${docker} exec ${test} pg_isready -h 127.0.0.1 -U postgres > /dev/null 2>&1 && exit 0; sleep 1; done; exit 1`);
  // Supabase's postgres role is restricted by default; restore privileges are
  // granted only inside this disposable, network-isolated container.
  remote(`${docker} exec ${test} psql -X -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -c 'alter role postgres superuser'`);
  sql(test, `do $$ begin
    if not exists(select 1 from pg_roles where rolname='supabase_realtime_admin') then create role supabase_realtime_admin; end if;
    if not exists(select 1 from pg_roles where rolname='supabase_functions_admin') then create role supabase_functions_admin; end if;
  end $$;`);
  // Restore into template0: the image's seeded schemas/default grants would
  // otherwise survive --clean and silently add client function permissions.
  // Only this newly created, isolated container is ever reset.
  remote(`${docker} exec ${test} psql -X -U supabase_admin -d template1 -v ON_ERROR_STOP=1 -c 'drop database postgres with (force)'`);
  remote(`${docker} exec ${test} psql -X -U supabase_admin -d template1 -v ON_ERROR_STOP=1 -c 'create database postgres owner postgres template template0'`);
  remote(`${docker} exec -i ${test} pg_restore -U postgres -d postgres --exit-on-error < '${backup}'`);
  sql(test, `update cron.job set active=false; create extension if not exists pgtap;\nbegin;\n${migration}\ncommit;`);
  const tests = ['community_content_filter', 'balance_regressions', 'audit_regressions',
    'push_delivery_regressions', 'lifecycle_regressions', 'duel_regressions', 'privilege_regressions'];
  for (const suite of tests) {
    const output = sql(test, readFileSync(`supabase/tests/${suite}.sql`, 'utf8'));
    if (/^not ok\b|Looks like you (failed|planned)/m.test(output)) throw new Error(`Regression failed: ${suite}\n${output}`);
    console.log('Passed: ' + suite);
  }
  const deploy = `begin; set local lock_timeout='15s'; set local statement_timeout='120s';
    select pg_advisory_xact_lock(104857601::bigint);
    do $$ begin
      if (select count(*) from aura_admin.applied_migrations)<>11
        or not exists(select 1 from aura_admin.applied_migrations where name='20260909075449_reset_lifetime_xp.sql')
        or to_regclass('public.content_filter_terms') is not null then
        raise exception 'Migration baseline changed; rolling back';
      end if;
    end $$;
    create temporary table moderation_before as select
      (select count(*) from auth.users) as accounts,
      (select count(*) from public.profiles) as profiles,
      (select count(*) from public.challenges) as quests,
      (select count(*) from public.check_ins) as checkins,
      (select coalesce(sum(challenge_aura),0) from public.challenge_participants) as aura;
    ${migration}
    do $$ begin
      if exists(select 1 from moderation_before where accounts<>(select count(*) from auth.users)
        or profiles<>(select count(*) from public.profiles) or quests<>(select count(*) from public.challenges)
        or checkins<>(select count(*) from public.check_ins)
        or aura<>(select coalesce(sum(challenge_aura),0) from public.challenge_participants)) then
        raise exception 'Unexpected player data change';
      end if;
    end $$;
    insert into aura_admin.applied_migrations(name,sha256) values('${name}','${digest}');
    notify pgrst,'reload schema'; commit;
    select name,sha256 from aura_admin.applied_migrations where name='${name}';`;
  const output = sql('auraquest-db', deploy);
  mkdirSync('build/audit', { recursive: true });
  writeFileSync('build/audit/apple-moderation-deployment.txt', `Backup fully restored and seven suites passed: ${backup}\n${output}`);
  console.log(output);
} finally {
  if (created) remote(`${docker} stop ${test}`);
}
