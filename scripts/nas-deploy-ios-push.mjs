// Back up and deploy only the inspected FCM worker files on NAS-BRA.
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
const base = '/volume2/Datenbanken/AuraQuest';
const stamp = new Date().toISOString().replace(/\D/g, '').slice(0, 14);
const files = ['payload.ts', 'index.ts'];
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const source = files.map(name => ({ name, data: readFileSync(`supabase/functions/push-fcm/${name}`).toString('base64') }));
const previous = spawnSync('git', ['show', '9c0d4fd:supabase/functions/push-fcm/index.ts'], { maxBuffer: 1_000_000 });
if (previous.status !== 0) throw Error('Expected deployment baseline is missing');
const baselineHash = digest(previous.stdout);
function remote(command, input = '') {
  const result = spawnSync('ssh', ['-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
    '-o', 'ConnectTimeout=8', '-i', homedir() + '/.ssh/auraquest_nas',
    'denzel@192.168.178.123', command], { input, encoding: 'utf8', maxBuffer: 1_000_000 });
  if (result.status !== 0) throw Error(result.stderr || 'NAS command failed');
  return result.stdout.trim();
}
if (!process.argv.includes('--apply')) {
  console.log('Will back up/deploy index.ts and payload.ts, restart only functions, and verify its existing authentication guard.');
  process.exit(0);
}
const backup = `${base}/backups/push-fcm-before-${stamp}`;
const script = `const fs=require('fs'),crypto=require('crypto');
const target='/functions/push-fcm';
if(fs.realpathSync(target)!==target)throw Error('Unexpected worker symlink');
const files=${JSON.stringify(source)};
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
const existing=hash(fs.readFileSync(target+'/index.ts'));
if(![${JSON.stringify(baselineHash)},hash(Buffer.from(files[1].data,'base64'))].includes(existing))throw Error('Worker differs from inspected baseline');
const backup='/backups/push-fcm-before-${stamp}';fs.mkdirSync(backup,{mode:0o700});
for(const file of files){if(fs.existsSync(target+'/'+file.name))fs.copyFileSync(target+'/'+file.name,backup+'/'+file.name);}
for(const file of files){const temp=target+'/'+file.name+'.${stamp}';fs.writeFileSync(temp,Buffer.from(file.data,'base64'),{flag:'wx',mode:0o644});fs.renameSync(temp,target+'/'+file.name);}
console.log('FCM worker files deployed with on-NAS backup.');`;
console.log(remote(`/usr/bin/docker run --rm -i --network none --user 1000:10 -v '${base}/volumes/functions:/functions' -v '${base}/backups:/backups' node:20-alpine node`, script));
try {
  remote(`cd '${base}' && /usr/bin/docker compose -f docker-compose.yaml up -d --no-deps --force-recreate functions`);
  // Empty authenticated body must reach worker validation (400); unauthenticated
  // body must be rejected (403). Neither sends any real-device notification.
  const probes = remote(`/usr/bin/docker exec -i auraquest-db psql -XAt -U postgres -d postgres -v ON_ERROR_STOP=1`,
    `select net.http_post(url:=fcm_function_url,headers:=jsonb_build_object('Content-Type','application/json','x-push-secret',fcm_shared_secret),body:='{}'::jsonb,timeout_milliseconds:=10000) from public.push_config where id;
select net.http_post(url:='http://functions:9000/push-fcm',headers:='{"Content-Type":"application/json"}'::jsonb,body:='{}'::jsonb,timeout_milliseconds:=10000);`).split('\n');
  if (probes.length !== 2 || !probes.every(x => /^\d+$/.test(x))) throw Error('Unexpected probe IDs');
  let outcomes = '';
  for (let attempt = 0; attempt < 20; attempt++) {
    outcomes = remote(`/usr/bin/docker exec -i auraquest-db psql -XAt -U postgres -d postgres -v ON_ERROR_STOP=1`,
      `select id||':'||status_code from net._http_response where id in (${probes.join(',')}) order by id;`);
    if (outcomes.split('\n').length === 2) break;
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  if (outcomes !== probes[0] + ':400\n' + probes[1] + ':403') throw Error('Worker authentication/load probe failed: ' + outcomes);
  console.log('Worker loaded; authenticated empty body=400; missing secret=403. Backup: ' + backup);
} catch (error) {
  const rollback = `const fs=require('fs');const root='/backups/push-fcm-before-${stamp}';for(const name of ${JSON.stringify(files)}){const file='/functions/push-fcm/'+name;if(fs.existsSync(root+'/'+name))fs.copyFileSync(root+'/'+name,file);else if(fs.existsSync(file))fs.unlinkSync(file);}`;
  remote(`/usr/bin/docker run --rm -i --network none --user 1000:10 -v '${base}/volumes/functions:/functions' -v '${base}/backups:/backups' node:20-alpine node`, rollback);
  remote(`cd '${base}' && /usr/bin/docker compose -f docker-compose.yaml up -d --no-deps --force-recreate functions`);
  throw Error('Push verification failed; worker files restored.', { cause: error });
}
