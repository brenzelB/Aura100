// Native Apple identity-token verification needs only the exact bundle audience.
// This does not set up browser OAuth or token revocation (separate signing key).
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
const base = '/volume2/Datenbanken/AuraQuest';
const stamp = new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 14);
const backup = `${base}/backups/compose-before-apple-${stamp}.yaml`;
function remote(command, input = '') {
  const result = spawnSync('ssh', ['-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
    '-o', 'ConnectTimeout=8', '-i', homedir() + '/.ssh/auraquest_nas',
    'denzel@192.168.178.123', command], { input, encoding: 'utf8', maxBuffer: 2_000_000 });
  if (result.status !== 0) throw new Error(result.stderr || result.stdout);
  return result.stdout;
}
if (!process.argv.includes('--apply')) {
  console.log('Will back up compose, enable native Apple auth for com.auraquest.auraQuest, and recreate only auth.');
  process.exit(0);
}
const script = `const fs=require('fs');
const path='/stack/docker-compose.yaml';
if(fs.realpathSync(path)!==path) throw Error('Unexpected compose symlink');
const original=fs.readFileSync(path,'utf8');
if(original.includes('GOTRUE_EXTERNAL_APPLE_')) throw Error('Apple settings already exist; inspect before changing');
const lines=original.split(/\\r?\\n/);
const start=lines.findIndex(x=>/^  auth:/.test(x));
if(start<0) throw Error('Auth service not found');
let end=start+1; while(end<lines.length&&!/^  [a-zA-Z0-9_-]+:/.test(lines[end])) end++;
const offset=lines.slice(start,end).findIndex(x=>/^    environment:/.test(x));
if(offset<0) throw Error('Auth environment map not found');
fs.writeFileSync('/stack/backups/compose-before-apple-${stamp}.yaml',original,{flag:'wx',mode:0o600});
lines.splice(start+offset+1,0,'      GOTRUE_EXTERNAL_APPLE_ENABLED: "true"','      GOTRUE_EXTERNAL_APPLE_CLIENT_ID: "com.auraquest.auraQuest"');
const temporary=path+'.apple-${stamp}';
fs.writeFileSync(temporary,lines.join('\\n'),{flag:'wx',mode:0o600});
fs.renameSync(temporary,path);
console.log('Compose backup prepared; native Apple audience configured.');`;
console.log(remote(`/usr/bin/docker run --rm -i --network none --user 1000:10 -v '${base}:/stack' node:20-alpine node`, script).trim());
try {
  remote(`cd '${base}' && /usr/bin/docker compose -f docker-compose.yaml config --quiet && /usr/bin/docker compose -f docker-compose.yaml up -d --no-deps auth`);
  remote(`set -eu; for attempt in $(seq 1 30); do test "$(/usr/bin/docker inspect auraquest-auth --format '{{.State.Health.Status}}')" = healthy && exit 0; sleep 1; done; exit 1`);
  console.log('AuraQuest auth is healthy with native Apple enabled. Backup: ' + backup);
} catch (error) {
  remote(`cp '${backup}' '${base}/docker-compose.yaml'; cd '${base}' && /usr/bin/docker compose -f docker-compose.yaml up -d --no-deps auth`);
  throw new Error('Apple configuration failed and the previous compose was restored.', { cause: error });
}
