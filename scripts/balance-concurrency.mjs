// Concurrent transactions against the isolated NAS test container only.
import {spawn,spawnSync} from 'node:child_process';
import {homedir} from 'node:os';
const ssh=['-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-i',homedir()+'/.ssh/auraquest_nas','denzel@192.168.178.123'];
const container='aura100-balance-test';
const guard=spawnSync('ssh',[...ssh,`docker inspect --format '{{index .Config.Labels "aura100.test"}}' ${container}`],{encoding:'utf8'});
if(guard.status!==0||guard.stdout.trim()!=='balance')throw Error('Unexpected test target');
function sql(input){return new Promise(resolve=>{
  const p=spawn('ssh',[...ssh,`docker exec -i ${container} psql -XAt -U postgres -d postgres -v ON_ERROR_STOP=1`]);
  let out='',err='';p.stdout.on('data',x=>out+=x);p.stderr.on('data',x=>err+=x);p.on('close',code=>resolve({code,out,err}));p.stdin.end(input);
});}
const a='00000000-0000-0000-0000-000000000091',b='00000000-0000-0000-0000-000000000092';
const q=n=>'10000000-0000-0000-0000-'+String(9100+n).padStart(12,'0');
const setup=await sql(`begin;
insert into auth.users(id,email,raw_user_meta_data) values('${a}','race-a@example.invalid','{"username":"balance_race_a"}'),('${b}','race-b@example.invalid','{"username":"balance_race_b"}');
insert into public.challenges(id,creator_id,title,starts_on,duration_days,aura_gain,aura_penalty,max_strikes)
values('${q(1)}','${a}','Balance race',current_date,30,100,25,3),('${q(2)}','${a}','Balance race',current_date,30,100,25,3);
insert into public.challenge_participants(challenge_id,user_id,challenge_aura) select id,u,1000 from public.challenges cross join(values('${a}'::uuid),('${b}'::uuid))users(u) where id in('${q(1)}','${q(2)}');
insert into public.player_xp_events(user_id,challenge_id,unit_on,xp) select '${a}',gen_random_uuid(),current_date,100 from generate_series(1,4);
insert into public.targeted_roasts(challenge_id,sender_id,target_id,roast_text,duration_seconds) select '${q(1)}','${a}','${b}','Test',3 from generate_series(1,2);
commit;`);
if(setup.code)throw Error(setup.err);
try {
  const results=await Promise.all([1,2].map(n=>sql(`begin;select set_config('request.jwt.claim.sub','${a}',true);set local role authenticated; select public.log_check_in('${q(n)}');commit;`)));
  if(results.some(r=>r.code))throw Error(JSON.stringify(results));
  const xp=await sql(`select sum(xp) from public.player_xp_events where user_id='${a}';`);
  if(xp.out.trim()!=='500')throw Error('Concurrent XP exceeded cap: '+xp.out);
  console.log('PASS: simultaneous confirmed units retain the 500 XP/day cap.');
  const attacks=await Promise.all([1,2].map(n=>sql(`begin;select set_config('request.jwt.claim.sub','${a}',true);set local role authenticated;select public.send_targeted_roast('${q(n)}','${b}','Test',3);commit;`)));
  if(attacks.filter(r=>r.code===0).length!==1||!attacks.some(r=>r.err.includes('Daily attack limit reached')))throw Error(JSON.stringify(attacks));
  const counts=await sql(`select count(*) from public.targeted_roasts where sender_id='${a}';select sum(challenge_aura) from public.challenge_participants where user_id='${a}';`);
  if(counts.out.trim()!=='3\n2150')throw Error('Incorrect race count or charge: '+counts.out);
  console.log('PASS: simultaneous attacks use the final daily slot once and charge once.');
} finally {
  const clean=await sql(`begin;delete from public.challenges where id in('${q(1)}','${q(2)}') and title='Balance race';delete from auth.users where id in('${a}','${b}') and email in('race-a@example.invalid','race-b@example.invalid');commit;`);
  if(clean.code)throw Error(clean.err);
}
