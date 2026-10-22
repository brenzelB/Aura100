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

Source version updated to 1.0.3+17. Signed CI builds, Apple processing/internal
assignment and Google Play upload/internal rollout are still pending. Completion
will be recorded with exact commit/run/artifact and final service status.

No new tester accounts, credentials, public App Review submission or production
rollout is requested in this step.
