# App Review notes — draft

Do not submit yet. Distribution signing and production APNs configuration are
complete. Candidate **1.0.2 (10)** is signed and passed CI, but is not uploaded
to Apple. Apple revocation code and its isolated NAS database tests are complete;
the dedicated signing key and live deployment await confirmation. Real device
acceptance, screenshots and App Store privacy/age/export forms remain open.
Reviewer credentials have been prepared locally but not shared with Apple.
See [the current checkpoint](../../docs/2026-10-10-apple-launch-completion.md).

## Proposed review notes (after acceptance checks)

Aura Quest is a free social habit app. Aura and XP are virtual progress points.
There are no paid purchases, cash rewards, withdrawals or real-money stakes.
Randomized Heist/Dice outcomes affect virtual Aura only.

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

## Internal pre-submission reminder

Test Apple authorization revocation on deletion before submitting an Apple-login
build. Recheck the public demo login, refresh the demo quests, and add actual reviewer
contact name/email/phone in App Store Connect. Never paste the DPAPI ciphertext
as a password; decrypt only locally for the specifically approved Apple form.
