// Targeted deployment for the NAS baseline inspected on 2026-09-07.
// Run only after db-audit.mjs --nas-copy and the regression suites pass.
import { readFileSync,readdirSync,mkdirSync,writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
import { createHash } from 'node:crypto';
const privilegesOnly=process.argv.includes('--privileges-only');
const files=readdirSync('supabase/migrations').filter(n=>privilegesOnly
  ? n==='20260907200000_remove_client_ddl_privileges.sql'
  : /^2026090[47].*\.sql$/.test(n)).sort();
const digest=s=>createHash('sha256').update(s).digest('hex');
const patches=files.map(name=>({name,sql:readFileSync('supabase/migrations/'+name,'utf8').replace(/^\uFEFF/, '')}));
if (!process.argv.includes('--apply')) {
  console.log('Will back up NAS, then apply atomically: '+files.join(', '));
  process.exit(0);
}
function remote(command,input='') {
  const r=spawnSync('ssh',['-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8',
    '-i',homedir()+'/.ssh/auraquest_nas','denzel@192.168.178.123',command],
    {input,encoding:'utf8',maxBuffer:20_000_000});
  if(r.status!==0) throw new Error(r.stderr||r.stdout);
  return r.stdout;
}
const stamp=new Date().toISOString().replace(/[^0-9]/g,'').slice(0,14);
const backup='/volume2/Datenbanken/AuraQuest/backups/audit-before-'+stamp+'.dump';
remote(`set -eu; umask 077; docker exec auraquest-db pg_dump -U postgres -d postgres -Fc > '${backup}'; docker exec -i auraquest-db pg_restore -l < '${backup}' > /dev/null`);
console.log('Validated backup: '+backup);
const sql=`begin; set local lock_timeout='15s'; set local statement_timeout='120s';
select pg_advisory_xact_lock(104857601::bigint);
do $$ begin
 ${privilegesOnly ? "if (select count(*) from aura_admin.applied_migrations)<>8 then raise exception 'Expected the eight verified NAS migrations.'; end if;" : "if to_regclass('public.push_deliveries') is not null then raise exception 'NAS no longer matches inspected baseline; inspect migration ledger first.'; end if;"}
end $$;
create schema if not exists aura_admin;
revoke all on schema aura_admin from public,anon,authenticated;
create table if not exists aura_admin.applied_migrations(name text primary key,sha256 text not null,applied_at timestamptz default now());
create temporary table audit_before as select
 (select count(*) from public.profiles) as profiles,
 (select count(*) from public.challenges) as challenges,
 (select count(*) from public.check_ins) as checkins,
 (select coalesce(sum(challenge_aura),0) from public.challenge_participants) as aura;
${patches.map(p=>p.sql+`\ninsert into aura_admin.applied_migrations(name,sha256) values('${p.name}','${digest(p.sql)}');`).join('\n')}
update public.push_config set unifiedpush_allowed_hosts=array['push.brenzel.uk'] where id;
do $$ begin
 if exists(select 1 from audit_before where profiles<>(select count(*) from public.profiles)
 or challenges<>(select count(*) from public.challenges) or checkins<>(select count(*) from public.check_ins)
 or aura<>(select coalesce(sum(challenge_aura),0) from public.challenge_participants)) then
 raise exception 'Unexpected game data change; rolling back all migrations'; end if;
end $$;
notify pgrst,'reload schema';
commit;
select name,applied_at from aura_admin.applied_migrations order by name;`;
const result=remote('docker exec -i auraquest-db psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -P pager=off',sql);
mkdirSync('build/audit',{recursive:true});
writeFileSync('build/audit/nas-deployment.txt','Backup: '+backup+'\n'+result);
console.log(result);
