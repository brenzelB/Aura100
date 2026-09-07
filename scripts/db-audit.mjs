// Runs only against the explicitly named, disposable Docker test database.
import { readdirSync, readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
const nasCopy = process.argv.includes('--nas-copy');
const container = nasCopy ? 'aura100-nas-restore' : 'aura100-audit-db';
if (process.argv.includes('--setup')) {
  if (nasCopy) throw new Error('Restore the NAS copy explicitly; --setup is for synthetic data only.');
  const inspect=spawnSync('docker',['inspect','-f','{{.State.Running}}',container],{encoding:'utf8'});
  const args=inspect.status===0 ? ['start',container] : ['run','-d','--name',container,
    '--network','none','-e','POSTGRES_PASSWORD=local-audit-only',
    'public.ecr.aws/supabase/postgres:17.6.1.143','postgres',
    '-c','shared_preload_libraries=pg_cron,pg_net','-c','cron.database_name=postgres',
    '-c','cron.launch_active_jobs=off'];
  if(inspect.stdout.trim()!=='true') {
    const started=spawnSync('docker',args,{encoding:'utf8'});
    if(started.status!==0) throw new Error(started.stderr);
  }
  let ready=false;
  for(let attempt=0;attempt<30;attempt++) {
    ready=spawnSync('docker',['exec',container,'pg_isready','-U','postgres'],{stdio:'ignore'}).status===0;
    if(ready) break;
    await new Promise(resolve=>setTimeout(resolve,500));
  }
  if(!ready) throw new Error('Test Postgres did not become ready.');
  const elevated=spawnSync('docker',['exec',container,'psql','-X','-U','supabase_admin','-d','postgres',
    '-v','ON_ERROR_STOP=1','-c','alter role postgres superuser'],{encoding:'utf8'});
  if(elevated.status!==0) throw new Error(elevated.stderr);
}
function sql(input) {
  const r = spawnSync('docker', ['exec', '-i', container, 'psql', '-X', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-At'], {input, encoding: 'utf8', maxBuffer: 20_000_000});
  if (r.status !== 0) throw new Error(r.stderr || r.stdout);
  return r.stdout;
}
if (process.argv.includes('--replay')) {
  sql('create table if not exists public.audit_migrations (name text primary key);');
  sql('create extension if not exists pg_net; create extension if not exists pgtap;');
  const applied = new Set(sql('select name from public.audit_migrations').trim().split('\n'));
  for (const name of readdirSync('supabase/migrations').filter(x => x.endsWith('.sql')).sort()) {
    // The NAS snapshot was inspected and contains the migrations through August.
    if (nasCopy && name < '20260904') continue;
    if (applied.has(name)) continue;
    sql('begin;\n' + readFileSync('supabase/migrations/' + name, 'utf8').replace(/^\uFEFF/, '') + `\ninsert into public.audit_migrations values ('${name}');\ncommit;`);
    console.log('Applied ' + name);
  }
  // No scheduled work and no outbound network in this test container.
  sql('update cron.job set active = false; create extension if not exists plpgsql_check;');
}
if (process.argv.includes('--check')) {
  const result = sql(`select p.oid::regprocedure, c.level, c.message, c.lineno
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    join pg_language l on l.oid=p.prolang
    cross join lateral public.plpgsql_check_function_tb(p.oid, fatal_errors := false) c
    where n.nspname='public' and l.lanname='plpgsql' and p.prorettype <> 'trigger'::regtype
    and not exists (select 1 from pg_depend dep where dep.classid='pg_proc'::regclass
      and dep.objid=p.oid and dep.deptype='e')
    and c.level='error';`);
  mkdirSync('build/audit', {recursive:true});
  writeFileSync('build/audit/sql-check.txt', result);
  console.log(result || 'No PL/pgSQL schema errors.');
  if (result.trim()) process.exitCode = 1;
}
const file = process.argv.find(a => a.endsWith('.sql'));
if (file) {
  const result = sql(readFileSync(file, 'utf8'));
  console.log(result);
  if (/^not ok /m.test(result)) process.exitCode = 1;
}
