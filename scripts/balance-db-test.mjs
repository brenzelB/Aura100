// Isolated, synthetic database on NAS-BRA. Never addresses auraquest-db.
import {spawnSync} from 'node:child_process';
import {homedir} from 'node:os';
import {readFileSync,readdirSync} from 'node:fs';
const name='aura100-balance-test';
function remote(command,input='') {
  const r=spawnSync('ssh',['-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8','-i',homedir()+'/.ssh/auraquest_nas','denzel@192.168.178.123',command],{input,encoding:'utf8',maxBuffer:20000000});
  if(r.status!==0) throw Error(r.stderr||r.stdout);
  return r.stdout;
}
if(process.argv.includes('--setup')) {
  const exists=remote(`docker ps -a --filter name=^/${name}$ --format '{{.Names}}'`).trim();
  if(exists) {
    if(remote(`docker inspect --format '{{index .Config.Labels "aura100.test"}}' ${name}`).trim()!=='balance') throw Error('Unexpected container owner');
    remote(`docker start ${name}`);
  } else {
    remote(`docker run -d --name ${name} --label aura100.test=balance --network none --cpus=1 --memory=768m -e POSTGRES_PASSWORD=synthetic-balance-only supabase/postgres:17.6.1.136 postgres -c shared_preload_libraries=pg_cron,pg_net -c cron.database_name=postgres -c cron.launch_active_jobs=off`);
  }
  // The image starts a socket-only bootstrap server, then restarts. TCP
  // readiness waits for the final server instead of that temporary process.
  remote(`docker exec ${name} sh -c 'for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do pg_isready -h 127.0.0.1 -U postgres && exit 0; sleep 1; done; exit 1'`);
  console.log('Isolated test container started.');
}
// Every invocation verifies its target; no local Docker fallback exists.
if(remote(`docker inspect --format '{{index .Config.Labels "aura100.test"}}' ${name}`).trim()!=='balance') throw Error('Unexpected container owner');
function sql(s){return remote(`docker exec -i ${name} psql -XAt -U postgres -d postgres -v ON_ERROR_STOP=1`,s);}
if(process.argv.includes('--replay')) {
  remote(`docker exec ${name} psql -X -U supabase_admin -d postgres -c 'alter role postgres superuser'`);
  sql('create table if not exists public.audit_migrations(name text primary key); create extension if not exists pg_net; create extension if not exists pgtap;');
  const applied=new Set(sql('select name from public.audit_migrations').trim().split('\n'));
  for(const file of readdirSync('supabase/migrations').filter(n=>n.endsWith('.sql')).sort()) {
    if(applied.has(file)) continue;
    sql('begin;\n'+readFileSync('supabase/migrations/'+file,'utf8').replace(/^\uFEFF/,'')+`\ninsert into public.audit_migrations values('${file}'); commit;`);
  }
  sql('update cron.job set active=false; create extension if not exists plpgsql_check;');
  console.log('Baseline replayed.');
}
const file=process.argv.find(x=>x.endsWith('.sql'));
if(file) {
  const result=sql(readFileSync(file,'utf8'));
  console.log(result);
  if(/^not ok /m.test(result)) process.exitCode=1;
}
if(process.argv.includes('--check')) {
  const result=sql(`select p.oid::regprocedure,c.level,c.message,c.lineno from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang cross join lateral public.plpgsql_check_function_tb(p.oid,fatal_errors:=false) c where n.nspname='public' and l.lanname='plpgsql' and p.prorettype<>'trigger'::regtype and not exists(select 1 from pg_depend d where d.classid='pg_proc'::regclass and d.objid=p.oid and d.deptype='e') and c.level='error';`);
  console.log(result||'No PL/pgSQL schema errors.');
  if(result.trim()) process.exitCode=1;
}
if(process.argv.includes('--stop')) {remote(`docker stop ${name}`); console.log('Test container stopped.');}
