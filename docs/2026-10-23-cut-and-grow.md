# Cut & Grow — Editorial Growth

The owner selected Cut & Grow on 23 October 2026. The replacement is implemented
inside the existing Editorial Growth theme. Brutal Neutralism and Auralis retain
their palettes, theme branches and behavior. No fourth theme was added. The
other two proposed directions remain static concepts.

## Implemented

- Rose/aubergine/cream/coral/mint light appearance; deep aubergine, warm cream,
  apricot and mint dark appearance. Bundled DM Serif and Plus Jakarta fonts.
- Compact Today overview, direct Activity access and distinct invitation notice.
  Daily cut marks count confirmed completions, not pending offline actions.
- Progress quests have proportional segmented tracks, real numeric values,
  coral/apricot actions and their existing quick-add shortcuts.
- Quest detail uses real proportional cut marks, natural period context,
  readable rewards/penalties, Perks and all existing participant/history paths.
  Historical totals follow the actionable content only in this theme.
- Existing routes, check-in/progress controllers, lockouts, roasts, offline queue,
  game rules, account handling and NAS backend are retained.
- No repeating animation or network artwork. New progress graphics are vectors;
  the brand bar reuses the bundled logo asset. Progress
  transitions use 280 ms ease-out and respect reduced motion. Native iOS page
  transitions remain platform-provided.
- Removed the two unused botanical cover images from the Flutter asset bundle.
  Existing logo rasters gained source metadata only; decoded pixel hashes are
  identical before/after (`build/audit/cut-grow-raster-provenance.json`).

## Verification

- `build/audit/cut-grow-final-tests.log`: all **458 Flutter tests passed**.
  Includes all eight theme goldens, ten new Home action/offline/large-text cases
  and four new goal-progress/bonus/reduced-motion cases.
- Only the four Editorial golden baselines were regenerated. The four existing
  Brutal Neutralism/Auralis light/dark baselines passed without any change.
- `build/audit/cut-grow-analyze.log`: no issues found.
- Native Android captures use production Flutter screens and shell with an
  isolated, local fixture entrypoint in `build/cut_grow_preview.dart`. They are
  illustrative data, not screenshots of live account data. The fixture entrypoint
  is not included in the production `lib/main.dart` build.
- `build/ui-review/cut-grow/device-1-screen-{0,1,2,3}.png`: Home Light, Quest Light,
  Home Dark, Quest Dark at 1080 × 2424, density 420.
- `device-2-screen-{0,1,2,3}.png`: the same four views at 2560 × 1600, density 240.
  This is a wide Android emulator viewport, not a physical tablet.
- `device-3-screen-{0,1,2,3}.png`: actual Android font scale 1.6 on the phone
  viewport. Size, density and font scale were restored after capture.
- The existing screen matrix also checks 320/768/1440 logical widths, enlarged
  text, forms, navigation, invitations, profile, friends and Perks.

Native iOS runtime, physical-device frame timing and physical haptics are not
verified by these Windows/emulator checks. No web detector was used for Dart.

## Review and distribution

Impeccable's fresh native review requested one scoped correction: replace the
Quest progress eyebrow with natural period context and the chosen cut geometry.
That correction is implemented and recaptured in all twelve native views.
Review records are `build/audit/cut-grow-finish-review.md` and
`build/audit/cut-grow-finish-verdict.md`. The verdict scores the requested fix
as resolved, **ship at that fix's scope**, without claiming new platform or
physical-device verification. The four durable phone captures and their origin
manifest are in `design/editorial-growth-2026-10-23/native/`.

The normal `lib/main.dart` Android debug APK also builds successfully
(`build/audit/cut-grow-main-build.log`), separate from the fixture entrypoint.
It was installed as an update on `emulator-5554` without clearing app data.
The normal sign-in screen was visually verified in Cut & Grow Light, and the
emulator is back at 1080 × 2424, density 420, system font scale 1.0.

This implementation does not publish a store release. The existing store test
channels still carry build 19 from the preceding UI/UX refinement release; the
selected redesign requires a subsequent store build to reach those testers.

## Design documentation

`DESIGN.md` and `.impeccable/design.json` record the actual implemented tokens
and component patterns, explicitly limited to Editorial Growth. The documenter
agent hit its usage limit; documentation was completed directly using the
shipped fallback role. Local structure, token references and JSON were checked;
the available launcher exposes no dedicated schema validator. The check record
is `build/audit/cut-grow-documentation.txt`.
