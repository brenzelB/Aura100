// Deploys this public static page through SSH, with an on-NAS rollback copy.
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
import { createHash } from 'node:crypto';
const html = readFileSync('legal/aura-quest/index.html');
const hash = createHash('sha256').update(html).digest('hex');
const stamp = new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 14);
const base = '/volume2/Datenbanken/AuraQuest/volumes/legal';
const target = `${base}/aura-quest/index.html`;
const backup = `/volume2/Datenbanken/AuraQuest/backups/legal-before-${stamp}.html`;
const command = `set -eu; umask 077;
test "$(readlink -f '${target}')" = '${target}';
test "$(/usr/bin/docker inspect auraquest-legal --format '{{range .Mounts}}{{if eq .Destination "/seed"}}{{.Source}}{{end}}{{end}}')" = '${base}';
cp '${target}' '${backup}';
base64 -d > '${target}.upload-${stamp}';
test "$(sha256sum '${target}.upload-${stamp}' | cut -d ' ' -f 1)" = '${hash}';
mv '${target}.upload-${stamp}' '${target}';
/usr/bin/docker exec auraquest-legal cp /seed/aura-quest/index.html /usr/share/nginx/html/aura-quest/index.html;
test "$(/usr/bin/docker exec auraquest-legal sha256sum /usr/share/nginx/html/aura-quest/index.html | cut -d ' ' -f 1)" = '${hash}';
echo 'Legal page deployed; rollback copy: ${backup}';`;
if (!process.argv.includes('--apply')) {
  console.log(`Will back up and atomically deploy ${target} (${hash}).`);
  process.exit(0);
}
const result = spawnSync('ssh', ['-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
  '-o', 'ConnectTimeout=8', '-i', homedir() + '/.ssh/auraquest_nas',
  'denzel@192.168.178.123', command], { input: html.toString('base64'), encoding: 'utf8' });
if (result.status !== 0) throw new Error(result.stderr || result.stdout);
console.log(result.stdout.trim());
const response = await fetch('https://legal.brenzel.uk/aura-quest/?release=' + stamp);
const served = await response.text();
// Cloudflare's email-address protection rewrites mailto links and injects a
// script, so public HTML bytes legitimately differ from the verified origin.
const markers = ['<h2 id="community">Community-Regeln</h2>', 'Sign in with Apple',
  'Schriftdateien', 'Meldungen werden regelmäßig geprüft'];
if (!response.ok || !markers.every(marker => served.includes(marker))) {
  throw new Error('Public response is missing the updated page sections; check routing/caching.');
}
console.log('Origin hash matches; public HTTPS serves the updated legal/community sections.');
