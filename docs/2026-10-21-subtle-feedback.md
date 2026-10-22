# Subtle sounds and haptics

## Implemented

- Three original ElevenLabs Sound Effects v2 cues, generated on 21 October 2026
  in the `Aura Quest · Quiet wins` flow (`jHodvZXG9PcRIykkDGpH`).
- A confirmed check-in plays `check_in.wav` and one light haptic impact, from the
  shared controller so Home, quest cards and the timeline use the same behavior.
- Confirmed progress plays `progress.wav`; first reaching the period target plays
  `milestone.wav`. Bonus entries use the progress cue. The celebration dialog
  also uses the milestone cue when the user opens it.
- Success sounds never run on failed/queued check-ins, background synchronization,
  widget rebuilds or a response belonging to a previous account.
- Existing correction/slip haptics now use the same preference and a short light
  impact; no heavy vibration or failure buzzer.
- Profile → **SOUND & FEEL**: **Subtle sounds**, **Gentle haptics**, **TRY FEEDBACK**.
  Both preferences default to enabled and persist independently on the device.
  No server or account settings/schema changes.
- Playback is foreground-only, optional and never awaited by the transaction.
  Audio failure does not affect a saved action; late sounds after decoder warmup
  are discarded. A 900 ms cooldown avoids overlapping chimes and repeated buzzes.

## Audio delivery

| Asset | Duration | Generation ID | Size |
| --- | --- | --- | --- |
| `assets/audio/check_in.wav` | 0.48 s | `dbt17pLbdLIQxLq1EG2Y` | 42,380 B |
| `assets/audio/progress.wav` | 0.48 s | `a4lW8eQSzuR4Ha611AUq` | 42,380 B |
| `assets/audio/milestone.wav` | 0.80 s | `Ne6qrOhCV3PX26Ks8Er6` | 70,604 B |

155,364 bytes combined. Mono 44.1 kHz / 16-bit PCM, high/low frequency filtering,
gentle compression, tiny edge fades, peak ceiling -12 dBFS and playback volume
0.65. `tools/master_ui_sounds.py` reproduces mastering from the selected original
MP3s in the ignored `build/audio-source/` directory. Original prompts and takes
remain in that ElevenLabs flow; no credentials are included in app assets.

`audioplayers` 6.8.1 preloads three reusable players. Android uses SoundPool low
latency mode, sonification content, the ring stream for silent/vibrate mode and
no audio focus request. iOS uses the ambient audio session category, respecting
the silent switch and mixing with existing music. No background audio mode,
microphone permission, audio network calls or runtime ElevenLabs dependency.

## Verification

- 42 focused tests passed: preference persistence, cooldown, foreground/disposal,
  decoder warmup, unsupported hardware, PCM duration/peak limits, check-in and
  progress result lifecycle, existing Home interactions, app boot and feedback
  controls in all themes/modes at 320/900 px with 1.8× text.
- Full Flutter suite: **436 tests passed**, including all eight existing exact
  theme screenshot comparisons. No theme palette/layout source or golden changed.
- Final `flutter analyze --no-pub`: **No issues found**.
- Android debug APK compiled successfully with local build override **1.0.2 (17)**.
  All three WAVs are present inside the APK. SHA-256:
  `2184d0d2c46b97f0d72b7a4f26f83506f150dba3c325daff7261ed227568e6f8`.
- Updated both running test emulators (`emulator-5554`, `emulator-5556`) with
  `adb install -r`; existing app data retained. Both report build 17 and start
  without a native audio/asset/plugin exception. The first is at login, the
  second retains its test session. SoundPool loads successfully on both.
- Physical feel, device volume, headphones/Bluetooth and iPhone silent-switch
  behavior still require a real-device listening/haptic check. An emulator cannot
  establish whether the vibration feels pleasant.
- This feature does not submit, replace or release the existing Apple review.
