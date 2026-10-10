# Aura Quest — moderation operations

This is the operator procedure for user reports and filtered public quest text. Apple requires an objectionable-content filter, a report path with timely responses, user blocking, and published contact details. The app already has user report/block controls; the database migration adds server-side text filtering and a triage queue.

## Before the public build

1. **Deployed on 9 October 2026:** `20261009120000_app_store_moderation.sql` is now the twelfth NAS migration. `scripts/nas-apply-moderation.mjs --apply` made backup `backups/apple-moderation-before-20261009213815.dump`, restored it into an isolated empty database and passed all seven SQL regression suites before changing the app database.
2. **Published and verified on 9 October 2026:** the public legal/Community Guidelines page at `https://legal.brenzel.uk/aura-quest/` serves the updated sections. `scripts/nas-deploy-legal.mjs` checks the exact origin hash and public HTTPS markers; Cloudflare's email obfuscation means the public HTML has different bytes. Latest rollback copy: `backups/legal-before-20261009214051.html`.
3. Confirm report and block flows from two test accounts, and confirm the operator can see and act on a new report.

Do not use Windows Docker or edit the PostgreSQL data files over SMB. The project's database containers run on NAS-BRA; use the checked NAS/PostgreSQL tooling in `scripts/README.md`.

## Daily report review

In Supabase Studio's SQL Editor, use an administrator session and inspect the oldest open reports:

```sql
select id, created_at, reporter_id, reported_id, reason, details, challenge_id
from public.user_reports
where moderation_status = 'new'
order by created_at asc;
```

Review the reported username and related quest in the app/database. Target a response within 24 hours. If content violates the Community Guidelines, replace the offending username or quest text with neutral text, suspend the account in Supabase Auth when needed, and record the action. Do not copy credentials, push tokens, or unnecessary personal details into moderation notes.

Record a completed review:

```sql
update public.user_reports
set moderation_status = 'action_taken',
    moderation_reviewed_at = now(),
    moderation_action = 'username_reset; account suspended',
    moderation_notes = 'Short factual outcome; omit unnecessary personal data.'
where id = 'REPORT-UUID-HERE'
  and moderation_status = 'new';
```

For a report that does not need action, use `moderation_status = 'no_action'` and state the reason briefly. If it is reviewed but requires follow-up, use `reviewed` and keep it on the daily queue until resolved. The permitted states are `new`, `reviewed`, `action_taken`, and `no_action`.

The filter blocks a list of common profanities in usernames and quest titles/descriptions. It cannot identify every threat, hateful statement, or abusive pattern. Reports and operator review remain necessary. The public contact address is listed in the Community Guidelines and legal notice.
