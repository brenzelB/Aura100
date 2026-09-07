// Runs a SQL inspection in a read-only transaction on the known NAS database.
// Never print configuration secrets, notification bodies or device tokens.
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
const file = process.argv[2];
if (!file?.endsWith('.sql')) throw new Error('Usage: node scripts/nas-audit.mjs inspection.sql');
const result = spawnSync('ssh', ['-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
  '-o', 'ConnectTimeout=8', '-i', homedir() + '/.ssh/auraquest_nas',
  'denzel@192.168.178.123', 'docker exec -i auraquest-db psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -P pager=off'], {
  input: 'begin read only;\nset local statement_timeout = \'30s\';\n' + readFileSync(file, 'utf8') + '\nrollback;\n',
  encoding: 'utf8', maxBuffer: 20_000_000,
});
mkdirSync('build/audit', {recursive: true});
writeFileSync('build/audit/nas-inspection.txt', result.stdout + result.stderr);
console.log(result.stdout);
if (result.status !== 0) throw new Error(result.stderr);
