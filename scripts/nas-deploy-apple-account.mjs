// Run only after explicit approval for the new Sign in with Apple key.
// Private values travel over SSH stdin and are never printed or committed.
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
import { createPrivateKey } from 'node:crypto';

const base = '/volume2/Datenbanken/AuraQuest';
const stamp = new Date().toISOString().replace(/\D/g, '').slice(0, 14);
const files = ['index.ts', 'handler.ts'].map(name => ({
  name, data: readFileSync(`supabase/functions/apple-account/${name}`).toString('base64'),
}));
const apply = process.argv.includes('--apply');
if (!apply) {
  console.log('Prepared: encrypted Apple-token worker, four NAS environment values, private backup and rollback.');
  console.log('After key approval use --apply --key-id KEYID --key-file PRIVATE_P8_PATH. Then apply the verified database migration.');
  process.exit(0);
}
const argument = name => process.argv[process.argv.indexOf(name) + 1];
const keyId = argument('--key-id');
const keyFile = argument('--key-file');
if (!/^[A-Z0-9]{10}$/.test(keyId ?? '') || !process.argv.includes('--key-file')) throw Error('Expected key ID and private P8 file');
const pem = readFileSync(keyFile, 'utf8');
const key = createPrivateKey(pem);
if (key.asymmetricKeyType !== 'ec' || key.asymmetricKeyDetails.namedCurve !== 'prime256v1') throw Error('Expected Apple P-256 private key');
const values = {
  APPLE_SIGNIN_TEAM_ID: 'W558BUSST2',
  APPLE_SIGNIN_KEY_ID: keyId,
  APPLE_SIGNIN_PRIVATE_KEY_B64: Buffer.from(pem).toString('base64'),
};
function remote(command, input = '') {
  const result = spawnSync('ssh', ['-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
    '-o', 'ConnectTimeout=8', '-i', homedir() + '/.ssh/auraquest_nas',
    'denzel@192.168.178.123', command], { input, encoding: 'utf8', maxBuffer: 1_000_000 });
  if (result.status !== 0) throw Error('NAS deployment step failed. Private output suppressed.');
  return result.stdout.trim();
}
const container = `/usr/bin/docker run --rm -i --network none --user 1000:10 -v '${base}:/stack' node:20-alpine node`;
const backup = `/stack/backups/apple-account-before-${stamp}`;
const script = `const fs=require('fs'),crypto=require('crypto');
const root='/stack';
for(const path of [root+'/docker-compose.yaml',root+'/.env',root+'/volumes/functions',root+'/backups']){
  if(fs.realpathSync(path)!==path)throw Error('Unexpected deployment symlink');
}
const target=root+'/volumes/functions/apple-account';
const existed=fs.existsSync(target);
if(existed && fs.realpathSync(target)!==target)throw Error('Unexpected worker symlink');
const files=${JSON.stringify(files)};
if(existed){
  for(const file of files){
    const path=target+'/'+file.name;
    if(fs.existsSync(path) && fs.readFileSync(path).toString('base64')!==file.data)throw Error('Existing Apple worker differs; inspect before replacing');
  }
}
let compose=fs.readFileSync(root+'/docker-compose.yaml','utf8');
let env=fs.readFileSync(root+'/.env','utf8');
const lines=compose.split(/\\r?\\n/);
const start=lines.findIndex(x=>/^  functions:/.test(x));
if(start<0)throw Error('Expected functions service missing');
let end=start+1;while(end<lines.length&&!/^  [a-zA-Z0-9_-]+:/.test(lines[end]))end++;
const environment=lines.findIndex((x,i)=>i>start&&i<end&&/^    environment:/.test(x));
if(environment<0||!lines.slice(environment,end).some(x=>/^      SUPABASE_SERVICE_ROLE_KEY:/.test(x)))throw Error('Expected worker environment missing');
const values=${JSON.stringify(values)};
// Preserve this key on retries: rotating it would lose retained tokens.
const encryption=env.match(/^APPLE_TOKEN_ENCRYPTION_KEY=([A-Za-z0-9_-]+)$/m);
values.APPLE_TOKEN_ENCRYPTION_KEY=encryption?encryption[1]:crypto.randomBytes(32).toString('base64url');
if(Buffer.from(values.APPLE_TOKEN_ENCRYPTION_KEY,'base64url').length!==32)throw Error('Invalid existing encryption key');
for(const [name,value] of Object.entries(values)){
  const re=new RegExp('^'+name+'=.*$','m');
  const existing=env.match(re);
  if(existing&&existing[0]!==name+'='+value)throw Error('Existing Apple configuration differs; inspect before changing');
  if(!existing)env=env.trimEnd()+'\\n'+name+'='+value+'\\n';
  if(!lines.slice(start,end).some(x=>new RegExp('^      '+name+':').test(x))){
    lines.splice(environment+1,0,'      '+name+': '+String.fromCharCode(36)+'{'+name+'}');end++;
  }
}
fs.mkdirSync('${backup}',{mode:0o700});
fs.copyFileSync(root+'/.env','${backup}/env');fs.chmodSync('${backup}/env',0o600);
fs.copyFileSync(root+'/docker-compose.yaml','${backup}/docker-compose.yaml');
fs.writeFileSync('${backup}/worker-existed',String(existed),{mode:0o600});
if(!existed)fs.mkdirSync(target,{mode:0o755});
for(const file of files){
  if(fs.existsSync(target+'/'+file.name))fs.copyFileSync(target+'/'+file.name,'${backup}/'+file.name);
  const temp=target+'/'+file.name+'.${stamp}';
  fs.writeFileSync(temp,Buffer.from(file.data,'base64'),{flag:'wx',mode:0o644});fs.renameSync(temp,target+'/'+file.name);
}
for(const [path,data,mode] of [[root+'/.env',env,0o600],[root+'/docker-compose.yaml',lines.join('\\n'),0o644]]){
  const temp=path+'.${stamp}';fs.writeFileSync(temp,data,{flag:'wx',mode});fs.renameSync(temp,path);
}
console.log('Apple worker and protected NAS environment prepared.');`;
console.log(remote(container, script));
const restart = `cd '${base}' && /usr/bin/docker compose -f docker-compose.yaml up -d --no-deps --force-recreate functions`;
try {
  remote(restart);
  // Use the existing anonymous JWT only inside the NAS network. GET reaches
  // the new handler (405); POST cannot impersonate an authenticated user (401).
  const probes = `const fs=require('fs');
const env=fs.readFileSync('/stack/.env','utf8');const token=env.match(/^ANON_KEY=(.*)$/m)?.[1];
if(!token)throw Error('Expected public anon key missing');
async function main(){
  for(let i=0;i<20;i++){
    try{
      const headers={Authorization:'Bearer '+token,'Content-Type':'application/json'};
      const a=await fetch('http://functions:9000/apple-account',{headers});
      const b=await fetch('http://functions:9000/apple-account',{method:'POST',headers,body:'{"action":"delete"}'});
      if(a.status===405&&b.status===401){console.log('New handler loaded: GET 405, unauthenticated deletion 401');return;}
    }catch{}
    await new Promise(r=>setTimeout(r,500));
  }
  throw Error('Apple worker load/authentication probes failed');
}main().catch(()=>{process.exitCode=1;});`;
  console.log(remote(`/usr/bin/docker run --rm -i --network auraquest_default --user 1000:10 -v '${base}:/stack:ro' node:20-alpine node`, probes));
  console.log('Protected rollback backup: ' + backup.replace('/stack', base));
} catch (error) {
  const rollback = `const fs=require('fs');const root='/stack',backup='${backup}',target=root+'/volumes/functions/apple-account';
fs.copyFileSync(backup+'/env',root+'/.env');fs.chmodSync(root+'/.env',0o600);
fs.copyFileSync(backup+'/docker-compose.yaml',root+'/docker-compose.yaml');
for(const name of ['index.ts','handler.ts']){
  if(fs.existsSync(backup+'/'+name))fs.copyFileSync(backup+'/'+name,target+'/'+name);
  else if(fs.existsSync(target+'/'+name))fs.unlinkSync(target+'/'+name);
}
if(fs.readFileSync(backup+'/worker-existed','utf8')==='false'&&fs.readdirSync(target).length===0)fs.rmdirSync(target);`;
  remote(container, rollback);
  remote(restart);
  throw Error('Apple worker verification failed; prior environment and files restored.', { cause: error });
}
