import { spawn } from 'node:child_process';
import assert from 'node:assert/strict';
const user='00000000-0000-0000-0000-000000009999';
const check='10000000-0000-0000-0000-000000009998';
const progress='10000000-0000-0000-0000-000000009999';
function sql(input, allowError=false) {
  return new Promise((resolve,reject)=>{
    const p=spawn('docker',['exec','-i','aura100-audit-db','psql','-X','-U','postgres','-d','postgres','-At','-v','ON_ERROR_STOP=1']);
    let out='',err=''; p.stdout.on('data',b=>out+=b); p.stderr.on('data',b=>err+=b);
    p.on('error',reject); p.on('close',code=>code&&!allowError?reject(new Error(err)):resolve({code,out,err}));
    p.stdin.end(input);
  });
}
const auth=`begin; set local statement_timeout='15s'; select set_config('request.jwt.claim.sub','${user}',true); set local role authenticated; `;
await sql(`insert into auth.users(id,email,raw_user_meta_data) values('${user}','race@example.invalid','{"username":"concurrency_test"}');
 insert into public.challenges(id,creator_id,title,starts_on,duration_days,aura_gain,aura_penalty,max_strikes,goal_type,target_value,unit) values
 ('${check}','${user}','Concurrent check',current_date,30,100,50,3,'check',null,null),
 ('${progress}','${user}','Concurrent progress',current_date,30,100,50,3,'progress',10,'reps');
 insert into public.challenge_participants(challenge_id,user_id,challenge_aura) values('${check}','${user}',500),('${progress}','${user}',500);`);
try {
  const checks=await Promise.all(Array.from({length:12},()=>sql(auth+`select public.log_check_in('${check}');commit;`,true)));
  assert.equal(checks.filter(r=>r.code===0).length,1);
  assert.ok(checks.every(r=>!r.err.includes('deadlock')&&!r.err.includes('timeout')));
  await Promise.all(Array.from({length:20},()=>sql(auth+`select public.add_progress('${progress}',1);commit;`)));
  const result=await sql(`select count(*) from public.check_ins where user_id='${user}';
    select sum(amount) from public.progress_entries where user_id='${user}';
    select sum(challenge_aura) from public.challenge_participants where user_id='${user}';`);
  assert.deepEqual(result.out.trim().split('\n').map(Number),[2,20,1200]);
  console.log('PASS: 12 simultaneous check-ins pay once; 20 progress writes retain all amounts and pay once; no deadlocks.');
} finally {
  await sql(`delete from public.challenges where id in ('${check}','${progress}'); delete from auth.users where id='${user}';`);
}
