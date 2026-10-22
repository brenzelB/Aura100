# Checked & Done test release 1.0.3 (18)

Requested on 22 October 2026: replace the previous soft sounds with an
unmistakable check-off/completed cue, increase the short vibration, and upload
the new version to the existing iPhone and Android internal test channels.
The user confirmed that the requested stronger feedback means the vibration.

## Changes

- Original checkbox click followed by a warm completion ding; a shorter step
  cue for progress and a resolved two-note cue for milestones.
- The replacement ElevenLabs flow `ryFMrwGw12MM4CZbHjoo` could not generate
  usable audio: the first attempt rejected a long prompt, then corrected
  retries were blocked by HTTP 429. These assets are **original procedural
  compositions**, not ElevenLabs generations. Reproduce with
  `python tools/master_ui_sounds.py` (standard library only).
- Mono 44.1 kHz, 16-bit PCM: 0.58 / 0.46 / 0.78 seconds, 160,656 bytes total.
  Target RMS -23 dBFS, peak ceiling -9 dBFS, existing playback volume 0.65.
- One `HapticFeedback.heavyImpact` replaces the former light impact. The
  platform controls actual strength; there is no repeated or prolonged buzz.
- Profile label is now `Haptic feedback`, with a firm short tap description.
  The existing independent switches, cooldown, foreground checks and
  confirmed-action-only behavior remain intact. App text remains English.
- No theme, account, navigation, backend, permission or privacy changes.

## Validation

- 29 targeted Flutter tests passed, including the actual native heavy-impact
  method request, cooldown and mute, all theme/control layouts at narrow/wide
  sizes and large text, and check-in/progress lifecycle regressions.
- PCM assets checked for format, duration, size and controlled peak levels.
- Local static analysis: no issues. Full CI tests, static analysis and the
  exact Windows theme screenshots all passed. Both signed binaries verified.
- Source commit: `754db9b520b9b6adb32513f0b30955e7d98a7afa`.
- Release workflow: <https://github.com/brenzelB/Aura100/actions/runs/39784042770>.

## Distribution

New build number: **18**, marketing version **1.0.3**. Existing TestFlight group
`Aura Quest iOS intern` and Google Play internal track `4701204184033716950`.
Release uploads are authorized; public publication is outside this request.

**Completed on 22 October 2026 at approximately 16:38 Europe/Berlin.** Both
existing internal test channels now provide **1.0.3 (18)**.

### iPhone / TestFlight

- Build ID `5b7c759a-1916-4046-8aff-957c9fddf612`, processed `VALID`.
- Saved the already approved standard-encryption / no-France answers for this
  build. Resulting API flag: `usesNonExemptEncryption=false`.
- Saved English test notes and added build 18 to `Aura Quest iOS intern`.
  It retains its one tester and previous builds, now eight builds total.
- API confirms `internalBuildState=IN_BETA_TESTING`; the live group page
  confirms **Build 1.0.3 (18) — Im Test**.
- The existing tester's iPhone 13 still showed installed build 17 at the final
  check. Availability is confirmed; installation of build 18 is a user action.
- Public version 1.0.2 / build 16 remains `READY_FOR_SALE`, with its complete
  version snapshot checked unchanged before/after internal assignment.

### Android / Google Play

- Internal track `4701204184033716950`, release ID `4`.
- Release name: **Aura Quest 1.0.3 (18) - Checked & Done**.
- Uploaded the verified AAB, English/German notes and confirmed both internal
  publication steps. Final track page: **Für interne Tester verfügbar**, one
  version code, published **22 October, 16:38**. Preview confirmed code 18 /
  1.0.3, API 24+, target SDK 36 and no loss of previously supported devices.
- Existing test track/testers retained. No global pending metadata or closed
  test changes submitted.
- Opt-in/install: <https://play.google.com/apps/internaltest/4701204184033716950>.
- The browser extension's local file transfer blocked for approximately
  76 minutes before Google received the file; the actual Google upload and
  optimization then completed. No duplicate upload or release was created.
- Google propagation normally takes up to an hour and can take longer.

### Binary provenance and evidence

- Android AAB SHA-256:
  `b1aae28b6f305509e53b02ed002a23162f5849b650b672b73c20ef257fc83406`.
- iOS IPA SHA-256:
  `6e8be7a6e88e70a95e40d3a48c9f5c3ea22d6cc08aa4a707b48859bcd6331e62`.
- Both build-info records identify commit `754db9b`, build 18; iOS signing
  is confirmed. All three embedded WAVs exactly match the source assets.
- iOS native audio plugin remains statically linked; SDK 26.5, minimum iOS 15,
  22 privacy manifests, 13 declared data types, no tracking, analytics/ads off.
- Ignored local evidence:
  `build/audit/done-feedback-18-test-release-android-ios-artifacts.json`,
  `build/audit/ios-build-18-privacy-report-2026-10-22.json`,
  `build/audit/done-feedback-18-testflight-release-verified.json` and the two
  `*-done-feedback-1.0.3-18-internal-2026-10-22.txt` live accessibility records
  under `build/audit/proofs/`. Browser screenshot capture timed out; the live
  UI text and Apple's API independently confirm the release states.

## Phone test

Update to 1.0.3 (18), then open Profile > SOUND & FEEL > TRY FEEDBACK.
Check normal/silent mode, each switch independently, a confirmed check-in,
progress and a completed goal. Physical vibration strength, device audio
routing and the subjective sound remain real-device acceptance checks.
