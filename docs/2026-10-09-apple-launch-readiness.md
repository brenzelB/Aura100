# Aura Quest — Apple App Store launch readiness

**Checked:** 9 October 2026
**Scope:** Repository and read-only NAS inspection. No code was pushed, no store build uploaded, and the app database was not changed.

## Work completed in this pass

- Added native Sign in with Apple to the iOS sign-in screen, including nonce hashing/exchange, the Xcode capability, and the entitlement. Supabase's Apple provider still needs account-side configuration and a real-device test.
- Enabled the iOS Push Notifications project capability and `remote-notification` background mode. Firebase's iOS plist and APNs key are absent, so this does not make iOS push operational yet.
- Added a local pre-check and server-side filter for common profanities in usernames and quest text, plus report queue status fields and an operator procedure. The migration was replayed and tested in the isolated NAS test container; it has **not** been applied to the app database.
- Added the Community Guidelines page section and an in-app link to it. The local legal page source has changed; the public page has not been redeployed.
- Added exact-hash Hanken Grotesk and Inter font files with their OFL licenses. The app disables Google Fonts runtime fetches, keeping the existing theme font bytes offline and avoiding the external font request.
- Updated the App Store description drafts, removed obsolete `Half Damage` claims, shortened both Play descriptions to fit, and removed the unsupported hard-coded `4+` age-rating claim.
- Advanced the release candidate to version `1.0.2+6`; build number 6 still must be checked against both stores before use. The local Android AAB is dated 30 September and predates this work, so it must not be uploaded; regenerate it from the final tested commit.
- Added localized 1.0.2 release notes and corrected the store checklist to point to a fresh CI artifact instead of the stale local AAB.
- Expanded the Apple privacy manifest to cover the app's account, push identifier, gameplay data, and in-game purchase history. Reconcile it once the final iOS SDK set is configured.

## Verification

- `flutter analyze --no-pub`: passed.
- `flutter test --no-pub --reporter compact`: 375 tests passed.
- `flutter test --no-pub --tags=golden`: all 8 theme goldens passed; Neo-Brutalist and Auralis remained pixel-identical.
- `flutter build apk --debug`: passed (Android regression check only; it is not an iOS build).
- NAS isolated test container: full migration replay and `plpgsql_check` passed; nine moderation/filter assertions and the existing balance, audit, push, lifecycle, duel, and privilege SQL regression suites passed.
- NAS app database read-only inspection: 11 existing migrations, scheduled jobs succeeded in the inspected window, no pending notification deliveries. No database write was performed.

## Google Play status

- German and English listing drafts and Android screenshots are prepared. The short descriptions are 61 and 57 characters, within Google Play's 80-character limit.
- The local release AAB was built on 30 September 2026 and predates the current fixes. It is not a launch candidate; create and verify a new signed AAB from the final tested commit.
- If this is a personal Play developer account created after 13 November 2023, Google requires a closed test with at least 12 opted-in testers continuously for 14 days before production access. An internal test with one tester does not satisfy that requirement. Confirm the account's eligibility and track status in Play Console.

## Still required before submission

1. Confirm the Apple Developer Program membership is active and the App Store Connect app record uses `com.auraquest.auraQuest`.
2. Enable/configure Apple in Supabase Auth. Configure Sign in with Apple services and test first-time and returning users on an iPhone.
3. Create the matching iOS Firebase app, provide `GoogleService-Info.plist` securely to the build, add the APNs authentication key in Firebase, and verify permission, foreground, background, and tap-through push on a real iPhone.
4. Apply the moderation migration to the NAS app database through its verified backup-and-PostgreSQL deployment path. Do not use a Windows Docker container or write PostgreSQL files over SMB. Confirm reports reach the operator and set up daily review.
5. Publish the updated legal page and verify its privacy, Community Guidelines, and contact sections at the public URL. The current live page has contact details but does not yet show the new Community Guidelines section.
6. Configure Apple distribution signing on the macOS runner (team, distribution certificate, App Store provisioning profile and export options). The repository workflow currently creates an unsigned artifact and cannot create an uploadable IPA from this Windows PC.
7. Confirm build number 6 is unused in App Store Connect (otherwise increase the shared Android/iOS number), produce a signed IPA on macOS, upload it to TestFlight, and test sign-in, account deletion, push, report/block, and all major flows on real iPhone/iPad devices.
8. Capture real app screenshots at Apple's required iPhone Dynamic Island medium size and iPad 13-inch size; current store screenshots are Android captures.
9. Complete the App Store Connect privacy form, age-rating questionnaire (including chance-based Aura Heist with virtual-only stakes), export-compliance questions, support details, and App Review demo credentials. Check that the final backend is reachable for review.

Apple's current screenshot rules require an iPhone Dynamic Island medium screenshot and, because this project supports iPad, an iPad 13-inch screenshot. Its review rules for user-generated content require filtering, reporting with timely responses, blocking, and published contact details. See the [screenshot requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) and [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

The launch is **not submission-ready yet**: signing, provider/Firebase setup, the live database migration, live legal-page update, real-device/TestFlight acceptance, and App Store Connect metadata remain outstanding.
