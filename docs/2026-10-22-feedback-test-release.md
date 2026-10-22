# Feedback test release 1.0.3 (17)

Requested on 22 October 2026: make the new subtle ElevenLabs sounds and gentle
haptics available on real iPhone and Android devices through the existing
TestFlight internal group and Google Play internal test.

## Baseline verified before changes

- GitHub `main`: `8254f39fc29497758c49e068b7bb753c7916e86e`.
- Apple app `6821149239`, bundle `com.auraquest.auraQuest`, existing internal group
  `Aura Quest iOS intern` (`357f8c17-5506-43f7-89e2-f9781558b355`). Latest uploaded
  build 16 is valid and is already in that group.
- Apple public version 1.0.2 / build 16 now reports `READY_FOR_SALE`. The next
  test marketing version is therefore **1.0.3**, with build number **17**.
- Google Play's existing internal release is `Aura Quest 1.0.0+3`. Pending global
  store metadata and closed-test changes are outside this internal update.
- Feedback validation from 21 October: 436 Flutter tests including eight theme
  goldens passed, static analysis clean, Android debug build 17 installed on both
  test emulators. Real-device feel and iOS silent-switch behavior remain to test.

## Intended test notes (English)

Subtle new sounds for check-ins, progress and milestones, plus gentle haptic
feedback. Customize both in Profile > SOUND & FEEL and tap TRY FEEDBACK.
Please test normal and silent mode, each switch independently, and a successful
check-in. Offline/failed actions should not play a success sound.

## Release status

**Completed on 22 October 2026, approximately 14:16 Europe/Berlin:** both existing
internal test channels now provide **1.0.3 (17)**.

- Source commit: `c0acae8497c21cf53d4b0909b20574edbbe5f1c3` on `main`.
- [GitHub Actions run 39773526302](https://github.com/brenzelB/Aura100/actions/runs/39773526302)
  succeeded in all four jobs: tests/static analysis, exact theme screenshots,
  signed Android AAB, signed iOS IPA and TestFlight upload.
- Both downloaded binaries contain the exact three WAVs from this commit;
  their provenance records identify commit `c0acae8`, build 17 and iOS signing.
- Android AAB: `build/store/android-release-1.0.3-17/app-release.aab`, SHA-256
  `cd30adcd16becc0c85b7767ed8a4f01ffa1109f965c8c659197f7539d5552cb7`.
- iOS IPA: `build/store/ios-1.0.3-17/ipa/Aura Quest.ipa`, SHA-256
  `485ac67e868ee1549b568cfc2d63a6a6b0bc9713096647788d90a91a37ccb391`.
  Native audio plugin is statically linked into Runner and its channel/class
  markers are present. iOS SDK 26.5, minimum iOS 15, 22 privacy manifests,
  13 declared data types, no tracking, Firebase analytics/ads disabled.

### iPhone / TestFlight

- Apple build ID: `228b66ff-115a-4bfb-a0da-76bd31883bfd`.
- Apple processed the upload successfully (`VALID`). Saved the same already
  approved standard-encryption / no-France export answers as build 16. The
  resulting build API flag is `usesNonExemptEncryption=false`.
- Added English testing notes and assigned build 17 to the existing internal
  group `Aura Quest iOS intern`. It still has one tester and now seven builds.
- API confirms `internalBuildState=IN_BETA_TESTING`; the live group page confirms
  **Build 1.0.3 (17) — Im Test**. New installation on the physical phone has not
  been observed; the user must update through TestFlight.
- Public version 1.0.2 / build 16 remains `READY_FOR_SALE`; its snapshot was
  checked unchanged before/after internal assignment. No public 1.0.3 submission.

### Android / Google Play internal test

- Internal track ID: `4701204184033716950`, release ID `3`.
- Release name: **Aura Quest 1.0.3 (17) - Sound & Feel**.
- Uploaded the verified AAB and saved release notes in English and German.
  Preview confirmed version code 17 / version 1.0.3, API 24+, target SDK 36 and
  no loss of previously supported devices. The previous version code 3 is not
  included in this new release.
- Completed **Speichern und veröffentlichen**, including its internal-release
  confirmation. The final track page reports **Für interne Tester verfügbar**,
  published **22 October, 14:16**, with one version code.
- Existing checked tester list **Denis** (one account) retained.
- Existing opt-in/install link:
  <https://play.google.com/apps/internaltest/4701204184033716950>.
- Google notes that propagation normally takes up to an hour and can take longer.
  This confirms availability in the internal channel, not a physical-phone update.

### Evidence

Ignored local audit files:

- `build/audit/feedback-test-release-android-ios-artifacts.json`
- `build/audit/ios-build-17-privacy-report-2026-10-22.json`
- `build/audit/feedback-testflight-release-verified.json`
- `build/audit/proofs/apple-feedback-1.0.3-17-internal-2026-10-22.txt`
- `build/audit/proofs/google-feedback-1.0.3-17-internal-2026-10-22.jpg`

Real-device checklist: update to 1.0.3 (17), open Profile > SOUND & FEEL, try the
preview, confirm check-in/progress/milestone cues, test each switch independently
and restart persistence, then test silent mode and headphones/Bluetooth. Actual
haptic feel, device routing and iPhone silent-switch behavior remain user tests.

No new tester accounts, credentials, public App Review submission or production
rollout is requested in this step.
