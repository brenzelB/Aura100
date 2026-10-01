// NAS-only repair. Never prints shared secrets or device tokens.
// Usage: node scripts/nas-fix-push-route.mjs [--apply]
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';

function remote(command, input = '') {
  const r = spawnSync('ssh', ['-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
    '-o', 'ConnectTimeout=8', '-i', homedir() + '/.ssh/auraquest_nas',
    'denzel@192.168.178.123', command], { input, encoding: 'utf8', maxBuffer: 2_000_000 });
  if (r.status !== 0) throw Error(r.stderr || 'NAS command failed');
  return r.stdout.trim();
}
const sql = (s) => remote('docker exec -i auraquest-db psql -XAt -U postgres -d postgres -v ON_ERROR_STOP=1', s);
const target = 'http://functions:9000/push-fcm';
const original = sql('select fcm_function_url from public.push_config where id;');
if (!['http://kong:8000/functions/v1/push-fcm', target].includes(original)) {
  throw Error('Unexpected sender URL; inspect before changing it');
}
// This private worker already enforces x-push-secret. Keep that check and
// public gateway restrictions intact; no anonymous public route is opened.
if (remote('docker exec auraquest-functions printenv VERIFY_JWT') !== 'false') {
  throw Error('Worker requires JWT; this deployment needs a different route');
}
const probes = sql(`select net.http_post(url:='${target}', headers:=
  jsonb_build_object('Content-Type','application/json','x-push-secret',fcm_shared_secret),
  body:='{}'::jsonb,timeout_milliseconds:=10000) from public.push_config where id;
select net.http_post(url:='${target}',headers:='{"Content-Type":"application/json"}'::jsonb,
  body:='{}'::jsonb,timeout_milliseconds:=10000);`).split('\n');
if (probes.length !== 2 || !probes.every(x => /^\d+$/.test(x))) throw Error('Unexpected probe results');
let outcomes = '';
for (let i = 0; i < 15; i++) {
  outcomes = sql(`select id||':'||status_code from net._http_response where id in (${probes.join(',')}) order by id;`);
  if (outcomes.split('\n').length === 2) break;
  await new Promise(resolve => setTimeout(resolve, 1000));
}
if (outcomes !== `${probes[0]}:400\n${probes[1]}:403`) throw Error('Sender authentication probe failed: ' + outcomes);
console.log('Worker reachable: correct secret accepted (400 for empty payload); missing secret rejected (403).');
if (!process.argv.includes('--apply')) {
  console.log('Verified repair: ' + original + ' -> ' + target + '. Use --apply.');
  process.exit(0);
}
if (original === target) { console.log('Sender URL already repaired.'); process.exit(0); }
const stamp = new Date().toISOString().replace(/\D/g, '').slice(0, 14);
const backup = '/volume2/Datenbanken/AuraQuest/backups/before-push-route-' + stamp + '.dump';
remote(`set -eu; umask 077; docker exec auraquest-db pg_dump -U postgres -d postgres -Fc > '${backup}'; docker exec -i auraquest-db pg_restore -l < '${backup}' > /dev/null`);
console.log('Validated backup: ' + backup);
console.log(sql(`begin;
set local lock_timeout='10s';
do $$ begin
 if (select fcm_function_url from public.push_config where id) is distinct from '${original}' then
  raise exception 'Configuration changed during verification';
 end if;
end $$;
update public.push_config set fcm_function_url='${target}',updated_at=now() where id;
commit;
select fcm_function_url from public.push_config where id;`));
// Do not replay historical failures: that would flood users with stale alerts.
