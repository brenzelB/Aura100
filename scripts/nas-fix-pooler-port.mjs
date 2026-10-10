// Repair the inspected NAS-only port conflict, without touching the NAS service
// already listening on 127.0.0.1:5433 or changing the database's files.
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
const base = '/volume2/Datenbanken/AuraQuest';
const stamp = new Date().toISOString().replace(/\D/g, '').slice(0, 14);
function remote(command, input = '') {
  const result = spawnSync('ssh', ['-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
    '-o', 'ConnectTimeout=8', '-i', homedir() + '/.ssh/auraquest_nas',
    'denzel@192.168.178.123', command], { input, encoding: 'utf8', maxBuffer: 1_000_000 });
  if (result.status !== 0) throw Error(result.stderr || 'NAS command failed');
  return result.stdout.trim();
}
if (!process.argv.includes('--apply')) {
  console.log('Will back up compose and bind only the pooler session port to NAS LAN IP 192.168.178.123:5433 (same port, narrower address).');
  process.exit(0);
}
const backup = `${base}/backups/compose-before-pooler-${stamp}.yaml`;
const script = `const fs=require('fs');
const file='/stack/docker-compose.yaml';
if(fs.realpathSync(file)!==file)throw Error('Unexpected compose symlink');
const original=fs.readFileSync(file,'utf8');
const lines=original.split(/\\r?\\n/); const start=lines.findIndex(x=>/^  supavisor:/.test(x));
if(start<0)throw Error('Pooler not found');
let end=start+1;while(end<lines.length&&!/^  [a-zA-Z0-9_-]+:/.test(lines[end]))end++;
const block=lines.slice(start,end);
const variable='$'+'{POSTGRES_PORT}';
const old='      - '+variable+':5432';
const replacement='      - 192.168.178.123:'+variable+':5432';
if(block.includes(replacement)){console.log('unchanged');process.exit(0);}
if(block.filter(x=>x===old).length!==1)throw Error('Unexpected session-port mapping');
const env=fs.readFileSync('/stack/.env','utf8');
if(!/^POSTGRES_PORT=5433\\r?$/m.test(env))throw Error('Inspected NAS port changed');
fs.writeFileSync('/stack/backups/compose-before-pooler-${stamp}.yaml',original,{flag:'wx',mode:0o600});
lines[start+block.indexOf(old)]=replacement;
const temp=file+'.pooler-${stamp}';fs.writeFileSync(temp,lines.join('\\n'),{flag:'wx',mode:0o600});fs.renameSync(temp,file);console.log('changed');`;
const changed = remote(`/usr/bin/docker run --rm -i --network none --user 1000:10 -v '${base}:/stack' node:20-alpine node`, script) === 'changed';
try {
  remote(`cd '${base}' && /usr/bin/docker compose -f docker-compose.yaml config --quiet && /usr/bin/docker compose -f docker-compose.yaml up -d --no-deps supavisor`);
  remote(`set -eu; for attempt in $(seq 1 40); do test "$(/usr/bin/docker inspect auraquest-pooler --format '{{.State.Health.Status}}')" = healthy && exit 0; sleep 1; done; exit 1`);
  console.log('NAS pooler healthy, bound to NAS LAN IP.' + (changed ? ' Backup: ' + backup : ' Configuration was already correct.'));
} catch (error) {
  if (changed) remote(`test -f '${backup}' && cp '${backup}' '${base}/docker-compose.yaml'`);
  throw Error('Pooler did not become healthy. Previous compose restored; inspect the service before retrying.', { cause: error });
}
