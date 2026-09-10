// Temporary, clearly named quests for the two existing emulator test accounts.
import {spawnSync} from 'node:child_process';
import {homedir} from 'node:os';
const mode=process.argv[2];
if(!['--create','--verify','--remove'].includes(mode)) throw new Error('Choose --create, --verify or --remove');
const ids="'10000000-0000-0000-0000-000000009991','10000000-0000-0000-0000-000000009992'";
const create=`begin;
 insert into public.challenges(id,creator_id,title,starts_on,duration_days,aura_gain,aura_penalty,max_strikes,goal_type,target_value,unit)
 select '10000000-0000-0000-0000-000000009991',id,'AUDIT Check-in 2026-09-07',current_date,7,100,50,3,'check',null,null
 from public.profiles where username='brenzel.ai';
 insert into public.challenges(id,creator_id,title,starts_on,duration_days,aura_gain,aura_penalty,max_strikes,goal_type,target_value,unit)
 select '10000000-0000-0000-0000-000000009992',id,'AUDIT Progress 2026-09-07',current_date,7,100,50,3,'progress',10,'reps'
 from public.profiles where username='bra_b';
 insert into public.challenge_participants(challenge_id,user_id,challenge_aura)
 select id,creator_id,500 from public.challenges where id in (${ids});
 do $$ begin if (select count(*) from public.challenges where id in (${ids}))<>2 then raise exception 'Missing fixture account'; end if; end $$;
 commit;`;
const verify=`select c.title,p.challenge_aura,(select count(*) from public.check_ins i where i.challenge_id=c.id) as checkins,
 (select sum(amount) from public.progress_entries e where e.challenge_id=c.id) as progress
 from public.challenges c join public.challenge_participants p on p.challenge_id=c.id where c.id in (${ids}) order by c.id;`;
const remove=`begin;
 delete from public.notification_outbox where ref_id in (${ids});
 delete from public.challenges where id in (${ids}) and title in ('AUDIT Check-in 2026-09-07','AUDIT Progress 2026-09-07');
 delete from public.player_xp_events e where challenge_id in (${ids})
   and not exists(select 1 from public.challenges c where c.id=e.challenge_id);
 commit;`;
const r=spawnSync('ssh',['-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-i',homedir()+'/.ssh/auraquest_nas',
 'denzel@192.168.178.123','docker exec -i auraquest-db psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -P pager=off'],
 {input:mode==='--create'?create:mode==='--remove'?remove:verify,encoding:'utf8'});
console.log(r.stdout); if(r.status!==0) throw new Error(r.stderr);
