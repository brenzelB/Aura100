// Runs the deployed backup routine once; preserves all existing rotation copies.
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {homedir} from 'node:os';
const script=readFileSync('deploy/nas/backup-loop.sh','utf8');
const marker='melde "Sicherungsdienst gestartet';
if(!script.includes(marker)) throw new Error('Backup script layout changed');
const input=script.slice(0,script.indexOf(marker))+'\nBEHALTEN=1000\nsichern\n';
const r=spawnSync('ssh',['-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-i',homedir()+'/.ssh/auraquest_nas',
 'denzel@192.168.178.123','docker exec -i auraquest-backup /bin/sh'],{input,encoding:'utf8'});
console.log(r.stdout); if(r.status!==0) throw new Error(r.stderr);
