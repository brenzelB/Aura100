// XP-reset deployment: NAS only, verified migration ledger, backup, atomic guards.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {homedir} from 'node:os';
import {createHash} from 'node:crypto';
const name='20260909075449_reset_lifetime_xp.sql';
const migration=readFileSync('supabase/migrations/'+name,'utf8').replace(/^\uFEFF/,'');
const hash=s=>createHash('sha256').update(s).digest('hex');
function remote(command,input='') {
  const r=spawnSync('ssh',['-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8','-i',homedir()+'/.ssh/auraquest_nas','denzel@192.168.178.123',command],{input,encoding:'utf8',maxBuffer:20_000_000});
  if(r.status!==0)throw Error(r.stderr||r.stdout);return r.stdout;
}
const sql=s=>remote('docker exec -i auraquest-db psql -XAt -U postgres -d postgres -v ON_ERROR_STOP=1',s);
const ledger=JSON.parse(sql('select coalesce(json_agg(t order by name),\'[]\'::json) from aura_admin.applied_migrations t;'));
for(const item of ledger) {
  const local=readFileSync('supabase/migrations/'+item.name,'utf8').replace(/^\uFEFF/,'');
  if(![hash(local),hash(local.replaceAll('\r\n','\n'))].includes(item.sha256))throw Error('Migration hash changed: '+item.name);
}
if(ledger.some(m=>m.name===name)){console.log('XP reset migration already applied with matching hash.');process.exit(0);}
if(ledger.length!==10)throw Error('Expected ten verified baseline migrations.');
console.log('NAS baseline: ten matching migration hashes.');
const before=JSON.parse(sql(`select json_build_object('profiles',(select count(*) from public.profiles),'quests',(select count(*) from public.challenges),'checkins',(select count(*) from public.check_ins),'participants',(select count(*) from public.challenge_participants),'aura',(select coalesce(sum(challenge_aura),0) from public.challenge_participants));`));
console.log(before);
if(!process.argv.includes('--apply')){console.log('Ready: backup + atomic balance migration. Run --apply after verification.');process.exit(0);}
const stamp=new Date().toISOString().replace(/[^0-9]/g,'').slice(0,14);
const backup='/volume2/Datenbanken/AuraQuest/backups/xp-reset-before-'+stamp+'.dump';
remote(`set -eu; umask 077; docker exec auraquest-db pg_dump -U postgres -d postgres -Fc > '${backup}'; docker exec -i auraquest-db pg_restore -l < '${backup}' > /dev/null`);
console.log('Validated backup: '+backup);
const guards=`
create temporary table reset_before_xp as select * from public.player_xp_events;
create temporary table balance_before_participants as select id,challenge_id,user_id,challenge_aura,strikes_used,periods_missed,status from public.challenge_participants;
create temporary table balance_before_quests as select id,aura_gain,aura_penalty,max_strikes from public.challenges;
create temporary table balance_before_counts as select (select count(*) from public.profiles) profiles,(select count(*) from public.check_ins) checkins,(select count(*) from public.benefit_purchases) purchases;
`;
const verify=`
do $$ begin
 if exists((select * from balance_before_participants except select id,challenge_id,user_id,challenge_aura,strikes_used,periods_missed,status from public.challenge_participants)
   union all (select id,challenge_id,user_id,challenge_aura,strikes_used,periods_missed,status from public.challenge_participants except select * from balance_before_participants)) then raise exception 'Unexpected participant change'; end if;
 if exists((select * from balance_before_quests except select id,aura_gain,aura_penalty,max_strikes from public.challenges)
   union all (select id,aura_gain,aura_penalty,max_strikes from public.challenges except select * from balance_before_quests)) then raise exception 'Unexpected existing quest balance change'; end if;
 if exists(select 1 from balance_before_counts where profiles<>(select count(*) from public.profiles) or checkins<>(select count(*) from public.check_ins) or purchases<>(select count(*) from public.benefit_purchases)) then raise exception 'Unexpected history change'; end if;
 if exists(select 1 from public.player_xp_events group by user_id,unit_on having sum(xp)>500) then raise exception 'XP backfill exceeds cap'; end if;

end $$;
`;
const result=sql(`begin;set local lock_timeout='15s';set local statement_timeout='120s';select public.lock_game_state();
do $$ begin if (select count(*) from aura_admin.applied_migrations)<>10 then raise exception 'Baseline changed'; end if;end $$;
${guards}\n${migration}\n${verify}
insert into aura_admin.applied_migrations(name,sha256) values('${name}','${hash(migration)}');
notify pgrst,'reload schema';commit;
select json_build_object('xp_events',(select count(*) from public.player_xp_events),'total_xp',(select sum(xp) from public.player_xp_events),'wards',(select count(*) from public.benefits where title='Aura Ward'));`);
mkdirSync('build/balance',{recursive:true});
writeFileSync('build/balance/nas-deployment.txt','Backup: '+backup+'\n'+result);
console.log(result);

