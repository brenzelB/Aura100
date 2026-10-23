# UI/UX improvements — test release 1.0.3 (19)

Implements the five recommendations in the 22 October Impeccable review.
Release scope: existing internal test channels; no public store submission.

## Changes

- Readable status foregrounds for slip actions in all six appearances.
- Compact Editorial Growth login and daily header. Google/Apple actions precede
  email fields in this theme. Other themes retain their existing login design.
- Quest creation: goal, rhythm, friends/rules; fixed footer action and every
  original game/balance option. Unfinished input is saved only on this device,
  under the current account ID, restored on reopening and cleared on success.
  Serialized storage operations prevent late writes resurrecting cleared drafts.
- One activity count shared by Home and navigation, including grouped pokes;
  a shortcut opens the existing inbox actions directly.
- Side navigation at 840 logical pixels and bounded content on wide windows;
  the four tab branches retain their navigation state.

Game rules, backend, permissions, sound/haptic preferences and the Roast timer
remain unchanged. English app copy retained. New Editorial Growth concepts are
separate proposals and are not part of this release.

## Verification

- Local static analysis: no issues.
- Full Flutter suite: 444 tests passed, including existing Windows goldens.
- New checks: account-isolated draft recovery, malformed draft handling, save/
  clear ordering, all six contrast combinations, stepped form validation,
  Editorial login placement and narrow/wide tab state preservation.
- Existing responsive checks cover 320–1440 logical pixels and text scale 1.6.
  They exposed a narrow/large-text divider overflow, fixed before release.
- Existing balance test now navigates through the new steps and verifies the
  same Classic/Chill/custom values as before.

Physical-device accessibility, frame times and a complete authenticated user
journey are not established by the automated suite.

## Distribution and provenance

Source: `16de31aa96d3ee0da8aebf69b67d2c0200a0733c`.
GitHub workflow: https://github.com/brenzelB/Aura100/actions/runs/39923413229.
All four jobs succeeded: static analysis/tests, exact Windows theme screenshots,
signed Android bundle and signed iOS IPA with TestFlight upload.

- Local additional rendering: six checks passed (Editorial login in both modes
  at phone/wide widths, all quest steps with scale 1.6, keyboard-visible action).
- Android emulator: existing Pixel_10_New updated without uninstalling; package
  reports version 1.0.3 / code 19. Actual login screenshot confirms the compact
  Editorial layout and visible Google action. Not an authenticated journey.
- Android AAB SHA-256:
  `2a1d9fc17eb5bb59dde250b90c75bcf559cc16a15ca7be4eed7b4bb073ace733`.
  Local file: `build/store/android-release-1.0.3-19/app-release.aab`.
- iOS IPA SHA-256:
  `14ff38666016a23affb11795ad6a1a26a0f41521bc3896ba3a0741d2f5b15d4c`.
  Local file: `build/store/ios-1.0.3-19/ipa/Aura Quest.ipa`.
- Both build-info files match source commit and build 19; iOS signing is true.
  Bundled feedback sounds match current source bytes, and the iOS native audio
  plugin remains linked.

### Google Play — complete

On 23 October at 15:23 Europe/Berlin, released the verified AAB as internal
release ID 5, `Aura Quest 1.0.3 (19) - Smoother Quests`, in the existing internal
track `4701204184033716950`. English/German notes are included.

- The browser's documented file-chooser API transferred the original signed
  AAB successfully. Its SHA-256 was rechecked against the provenance above.
- Google processed code 19 / version 1.0.3, minimum API 24 and target SDK 36.
  Review showed no errors and no loss of supported devices.
- Confirmed both internal publication steps. The final live track page states
  **Für interne Tester verfügbar**, one version code, published 23 October 15:23.
- Existing testers and track retained. No global metadata changes, closed-test
  changes or public-production release were submitted.
- Opt-in/install: https://play.google.com/apps/internaltest/4701204184033716950.
- Screenshot: `build/audit/proofs/google-play-19-internal.jpg`.
- Observed release record: `build/audit/ux19-google-release.json`.
- Google says changes normally appear within one hour and may take longer.

Windows-native capture had earlier stopped because its URL-enforcement check
could not identify the Chrome address. That control was not used again. The
separate browser file-chooser API verifies its own tab destination and completed
the authorized upload; its initial local transfer took about 16.5 minutes before
the Google upload/optimization phase. No duplicate release was created and no
manual file selection remains required.

### Apple / TestFlight — complete

On 23 October at 09:21 UTC (11:21 Europe/Berlin), saved the already-approved
standard-encryption / no-France answers for build 19 in App Store Connect.
The API then confirmed `usesNonExemptEncryption=false`; the provenance-guarded
helper saved English test notes and added build
`ce65274c-3086-4de5-882a-c2090784703d` to `Aura Quest iOS intern`.

- API verification: `internalBuildState=IN_BETA_TESTING`.
- Live group page: **Build 1.0.3 (19) — Im Test**.
- Group retains its one tester and previous builds, now nine builds total.
- Public version 1.0.2 / build 16 remains `READY_FOR_SALE`; its complete version
  snapshot was compared unchanged before/after assignment.
- Screenshot: `build/audit/proofs/testflight-19-internal.jpg`.
- Guarded API evidence: `build/audit/ux-19-testflight-release-verified.json`.
- Tester's iPhone 13 currently reports installed build 18. Build 19 availability
  is verified; installation and physical-device acceptance are user actions.

The local guarded assignment helper for build 19 and the verified artifact
reports are under ignored `build/`; credentials were not committed or printed.

## Editorial Growth proposals

The owner confirmed Google Play plus TestFlight and three separate directions,
with Home/Quest views in Light/Dark and the existing English tone. The twelve
proposal screens are now visually inspected and saved under
`design/editorial-growth-2026-10-23/`, with four browser comparison screenshots.
Example quests and rewards are aligned across variants. These remain concepts;
no replacement style was applied to the production app or this build.
