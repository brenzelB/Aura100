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
- Full release CI, exact theme screenshots and signed binary verification:
  pending the release workflow.

## Distribution

New build number: **18**, marketing version **1.0.3**. Existing TestFlight group
`Aura Quest iOS intern` and Google Play internal track `4701204184033716950`.
Release uploads are authorized; public publication is outside this request.

Status: source prepared; CI and internal distribution pending.

## Phone test

Update to 1.0.3 (18), then open Profile > SOUND & FEEL > TRY FEEDBACK.
Check normal/silent mode, each switch independently, a confirmed check-in,
progress and a completed goal. Physical vibration strength, device audio
routing and the subjective sound remain real-device acceptance checks.
