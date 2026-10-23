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

Distribution status and artifact provenance will be appended after verification.
Physical-device accessibility, frame times and a complete authenticated user
journey are not established by the automated suite.
