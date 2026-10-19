# App Review notes — resubmitted, 19 October 2026

Latest status: Apple rejected build 16 on 19 October under Guideline 2.3.10 because
the English description mentioned another mobile platform. That sentence has
been replaced with a description of the app experience. Both de-DE and en-US
metadata were checked after saving. The same **1.0.2 (16)** was resubmitted on
**19 October 2026 at 16:21 Europe/Berlin**, and Apple confirmed **Waiting for Review**.
Release remains manual. The reviewer notes below and existing credentials were
preserved; no additional App Review message was sent. See
[the metadata correction and submission evidence](../../docs/2026-10-19-apple-metadata-correction.md).

Apple stopped the build 14 review because its accurate simulated-gambling rating
is incompatible with an individual developer submission. The replacement removes
the wagering mechanics themselves. The updated notes below are saved at Apple.
On **17 October 2026 at 11:28 Europe/Berlin**, build **1.0.2 (16)** was resubmitted
and Apple confirmed **Waiting for Review**. Apple reused submission
`eaa11e08-627f-4c8e-8e4c-3b67607eb19f`. See
[the resubmission evidence](../../docs/2026-10-17-apple-resubmission.md).

Replacement **1.0.2 (16)** has passed CI, signed-IPA inspection and Apple's upload
processing. Export answers are saved (standard encryption, no France). The
existing **Aura Quest iOS intern** group shows it as **Testing / Im Test** with
the existing single tester. The user explicitly requested the replacement's
resubmission; a real-device game acceptance test has not been confirmed.
Build 16 corrects the unnecessary locale switch introduced in build 15: all
Ego Duel roasts, like the rest of the app, are always in English.
See [the replacement-build checkpoint](../../docs/2026-10-17-ego-duels.md).

Candidate **1.0.2 (14)** was submitted to App Review on **16 October 2026 at
20:31 Europe/Berlin**. At submission Apple confirmed **Waiting for Review**, submission
`eaa11e08-627f-4c8e-8e4c-3b67607eb19f`. The dedicated Apple
revocation worker and database migration are active on the NAS; all eight SQL
suites passed before deployment. With explicit user approval, the normal review
credentials and existing contact details were saved only in Apple's App Review
fields. Privacy, age rating and content-rights declarations are saved at Apple.
The initial launch excludes France with explicit user approval; build 14's
standard-encryption/no-France answers are saved and the build is testing in the
existing internal group. The user confirmed the real-iPhone Google sign-in and
automatic window closing with build 14. Account deletion was also confirmed from
the user's perspective; its sign-in provider and server-side revocation details
were not specified. Other device checks remain open. The version has not been
approved or publicly released; release remains manual. Store images are recorded under
`assets/campaign-2026-10-14/`.
See [the current checkpoint](../../docs/2026-10-16-apple-launch-completion.md).

## Review notes

Aura Quest is a free social habit app. Aura and XP are virtual progress points.
There are no paid purchases, cash rewards, withdrawals or real-money stakes.
Ego Duels are free rock-paper-scissors matches between consenting quest members.
Both players choose in secret and the server reveals the choices together.
First to three wins. The loser receives a curated, lighthearted roast; the winner
gets a win in the duel statistics. Neither player stakes, gains, loses or transfers
Aura or XP. There are no currency prizes, paid retries or random Aura payouts.
Dice wagers and randomized Aura Heists have been retired, including their old
server endpoints. Outstanding old escrow and pending Heist costs are refunded.

Use the dedicated email/password supplied in the App Review sign-in fields.
The account is confirmed and does not require an email code or Google/Apple login.
It contains three sample quests:

- **10 Seiten lesen:** log page counts toward a daily target of ten pages.
- **Drei Trainings pro Woche:** complete three check-ins within a weekly period.
- **10 Minuten Fokus:** a relaxed Chill habit with attacks disabled.

Open a quest to inspect its schedule, progress, activity and Perks. The reviewer
can also create a quest with Chill, Classic or Chaos values and invite other users.
Perks spend Aura; permanent XP represents player progress.

Notification permission is optional. The app does not access the phone's address
book, HealthKit or fitness sensors; fitness goals are entered manually.
Public profile/quest text is filtered on the server. User reporting, blocking,
Community Guidelines and the public operator contact are available in the app.

Account deletion is initiated in **Profile → Danger Zone → Delete Account**,
then confirmed by typing the username. It removes the account and its associated
data; quests with other participants are preserved by transferring ownership.
If reviewers delete the demonstration account, the operator must recreate the
test access before further review.

Public support/privacy/community URL: https://legal.brenzel.uk/aura-quest/

## Remaining internal verification

Apple authorization revocation on a real-device deletion remains a separate open
check; automated worker/database tests passed and the user reported successful
account deletion without identifying the sign-in provider. The public demo login
and all three quests were rechecked immediately before submission (18:30:39 UTC).
The public review login, all three quests and the free-game API guards were
rechecked on **17 October at 09:19:30 UTC** before this resubmission. The approved
reviewer contact fields and existing demo credentials were preserved in App Store
Connect. Never paste the DPAPI ciphertext
as a password; decrypt only locally for the specifically approved Apple form.
