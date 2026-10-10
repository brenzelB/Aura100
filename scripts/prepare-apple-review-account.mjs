// Prepare a normal, confirmed test user and small review fixtures on NAS-BRA.
// Password never appears in logs/Git; the local copy is Windows-DPAPI protected.
// No invitation, email, push or third-party credential upload is performed.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { homedir } from 'node:os';
const path = 'build/apple-private/review-account.json';
if (!process.argv.includes('--apply')) {
  console.log('Will create/verify the dedicated aurareview test account and three solo review quests on the NAS, without email or invitations.');
  process.exit(0);
}
mkdirSync('build/apple-private', { recursive: true });
function protect(value, decrypt = false) {
  const command = decrypt
    ? '$s = ConvertTo-SecureString ([Console]::In.ReadToEnd()); $p = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s); try { [Console]::Write([Runtime.InteropServices.Marshal]::PtrToStringBSTR($p)) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($p) }'
    : '$s = ConvertTo-SecureString ([Console]::In.ReadToEnd()) -AsPlainText -Force; [Console]::Write((ConvertFrom-SecureString $s))';
  const result = spawnSync(process.env.AURAQUEST_PWSH || 'pwsh.exe', ['-NoProfile', '-NonInteractive', '-Command', command], { input: value, encoding: 'utf8' });
  if (result.status !== 0) throw Error('Windows credential protection failed (process status ' + result.status + ', code ' + (result.error?.code ?? 'none') + ')');
  return result.stdout;
}
const record = existsSync(path) ? JSON.parse(readFileSync(path, 'utf8')) : {
  email: 'auraquest-review@brenzel.uk', username: 'aurareview',
  protectedPassword: protect(randomBytes(32).toString('base64url')),
};
writeFileSync(path, JSON.stringify(record, null, 2));
const privateInput = { email: record.email, username: record.username, userId: record.userId,
  password: protect(record.protectedPassword, true) };
// The helper reads the existing NAS service key in-container. Neither that key
// nor the returned user session leaves the NAS or is printed.
const helper = `const fs=require('fs');
const input=${JSON.stringify(privateInput)};
const env=fs.readFileSync('/stack/.env','utf8');
function setting(name){const line=env.split(/\\r?\\n/).find(x=>x.startsWith(name+'='));if(!line)throw Error('NAS setting missing');return line.slice(name.length+1).replace(/^['\"]|['\"]$/g,'');}
const service=setting('SERVICE_ROLE_KEY');
async function request(url,token,body){const response=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+token},body:JSON.stringify(body)});if(!response.ok)throw Error('Review API returned '+response.status);return response.json();}
async function main(){
let userId=input.userId;
if(!userId){const creation=await fetch('http://auth:9999/admin/users',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+service},body:JSON.stringify({email:input.email,password:input.password,email_confirm:true,user_metadata:{username:input.username}})});
if(creation.ok)userId=(await creation.json()).id;else if(creation.status!==422)throw Error('Review account creation failed');}
const session=await request('http://auth:9999/token?grant_type=password','',{email:input.email,password:input.password});
if(userId&&session.user.id!==userId)throw Error('Unexpected review account');userId=session.user.id;
const token=session.access_token;
const response=await fetch('http://rest:3000/challenges?select=id,title&creator_id=eq.'+userId,{headers:{Authorization:'Bearer '+token}});
if(!response.ok)throw Error('Review quest read failed');const existing=await response.json();
const today=new Date().toISOString().slice(0,10);
const quests=[{title:'10 Seiten lesen',description:'App Review demo: Track ten pages a day. Add progress in small steps.',goal:'progress',target:10,unit:'Pages',period:'daily',count:1,preset:'classic'},
{title:'Drei Trainings pro Woche',description:'App Review demo: Three sessions per week with room for missed days.',goal:'check',period:'weekly',count:3,preset:'classic'},
{title:'10 Minuten Fokus',description:'App Review demo: A relaxed daily focus habit. Chill keeps attacks disabled.',goal:'check',period:'daily',count:1,preset:'chill'}];
for(const quest of quests){if(existing.some(x=>x.title===quest.title))continue;
await request('http://rest:3000/rpc/create_challenge',token,{p_title:quest.title,p_description:quest.description,p_duration_days:56,p_starts_on:today,p_aura_gain:100,p_aura_penalty:25,p_max_strikes:3,p_checkin_period:quest.period,p_checkins_per_period:quest.count,p_mode:'solo',p_goal_type:quest.goal,p_target_value:quest.target??null,p_unit:quest.unit??null,p_is_endless:false,p_daily_allowance:0,p_active_weekdays:[1,2,3,4,5,6,7],p_balance_preset:quest.preset,p_attacks_enabled:quest.preset!=='chill'});}
const verification=await fetch('http://rest:3000/challenges?select=id,title&creator_id=eq.'+userId,{headers:{Authorization:'Bearer '+token}});
const rows=await verification.json();if(!verification.ok||!quests.every(q=>rows.some(x=>x.title===q.title)))throw Error('Review fixture verification failed');
console.log(JSON.stringify({userId,questCount:rows.length,loginVerified:true}));
}
main().catch(()=>{console.error('Review setup failed; no credentials logged.');process.exitCode=1;});`;
const result = spawnSync('ssh', ['-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
  '-o', 'ConnectTimeout=8', '-i', homedir() + '/.ssh/auraquest_nas', 'denzel@192.168.178.123',
  '/usr/bin/docker run --rm -i --network auraquest_default --user 1000:10 -v /volume2/Datenbanken/AuraQuest:/stack:ro node:20-alpine node'],
  { input: helper, encoding: 'utf8', maxBuffer: 1_000_000 });
if (result.status !== 0) throw Error('Review account setup failed; password is retained locally for recovery. No credentials logged.');
const verified = JSON.parse(result.stdout);
record.userId = verified.userId;
record.questCount = verified.questCount;
record.loginVerified = verified.loginVerified;
writeFileSync(path, JSON.stringify(record, null, 2));
// Exercise the exact HTTPS auth endpoint used by the published app too.
const config = readFileSync('lib/core/config/supabase_config.dart', 'utf8');
const anon = config.match(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/)?.[0];
if (!anon || JSON.parse(Buffer.from(anon.split('.')[1], 'base64url')).role !== 'anon') throw Error('Public app key was not found');
const response = await fetch('https://api.brenzel.uk/auth/v1/token?grant_type=password', {
  method: 'POST', headers: { 'Content-Type': 'application/json', apikey: anon },
  body: JSON.stringify({ email: record.email, password: privateInput.password }),
});
if (!response.ok) throw Error('Public review sign-in failed; status ' + response.status);
const session = await response.json();
if (session.user?.id !== record.userId) throw Error('Public sign-in returned an unexpected user');
record.publicLoginVerified = true;
writeFileSync(path, JSON.stringify(record, null, 2));
console.log('Internal and public HTTPS review login verified; ' + verified.questCount + ' solo quests prepared. Password is protected locally; no credentials uploaded to Apple/GitHub.');
