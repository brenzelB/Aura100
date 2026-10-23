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

### Google Play — still pending

Google internal release draft ID 5 was created in the existing track and given
the name `Aura Quest 1.0.3 (19) - Smoother Quests`, with English/German notes.
The verified AAB has **not** been selected/uploaded or published. At the upload
file picker, Windows Computer Use stopped this turn because it could not
determine the browser URL confidently enough to enforce its policy. No alternate
UI automation was used to bypass that stop. Existing build 18 remains available.
On the user's next explicit request to finish, a fresh parent-window activation
and capture encountered the same URL-enforcement stop. Native Chrome control
cannot currently complete this file selection; the user must select the local
AAB once before browser-based release confirmation can continue. No additional
release or duplicate upload was created.

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
