# Editorial Growth — Growth, Unscripted

Only Editorial Growth is redesigned. Existing uncommitted icon, release and NAS
work was retained. No backend, provider, database, route or purchase/check-in
logic changed in this task.

## Visual world

- Day: warm paper, cobalt ink, sculptural botanical still life.
- Night: aubergine gallery, acid-lime highlights, iridescent sculpture.
- Bundled DM Serif Display headlines and Plus Jakarta Sans body text.
- Asymmetric panels, pill actions and navigation indicators, magazine section
  headings, illustrated covers for Home, Quests, Friends, Profile, login and Perks.
- Desktop uses a maximum 1040 logical pixel reading area; cover composition
  switches from stacked to two columns at 640 pixels of available width.
- Body copy stays on opaque surfaces, separate from artwork. System font scaling
  remains enabled. Enlarged activity headings wrap independently from captions.

## Isolation

`EditorialTheme.refine` is called only for `AppThemeType.editorial`. Palette and
panel changes are confined to the editorial constants/switch branch. Added
screen content is explicitly guarded by the same theme check. Other branches
retain their original widgets and values.

Four component goldens in `test/goldens/unchanged_*` were generated using the
pre-redesign HEAD (`452797f`) versions of app_colors.dart, app_theme.dart and
app_theme_background.dart. Current sources then matched those images exactly.
They cover both other themes, both modes, typography, app bar, panels, buttons,
inputs, chips, progress, list tiles and navigation. Their offline font fixtures
are the exact Google Fonts files used by the installed package and are test-only.
This is representative visual regression coverage, not proof of every possible
screen/data state.

## Motion and cost

Cover entrances use the existing finite slide/opacity animation; pointer hover
scales artwork by 3.5% over 400ms. Android and desktop page transitions use a short
fade and 2.5% vertical translation; native iOS transitions are retained.
`MediaQuery.disableAnimations` bypasses the new motion. No continuous animations,
scroll listeners, shaders, blur filters, or new background work were added.
Images sit in repaint boundaries and use bounded decode sizes. Both WebPs total
184,702 bytes. Artwork and theme fonts are local assets.

## Validation

- Complete Flutter suite: 266 tests passed before widening the screen matrix.
- Design tests: 18 passed, covering 320/390/768/1440 widths, both modes, up to 2×
  text scaling, contrast, finite hover and reduced motion, with rendered goldens.
- Other-theme baseline comparison: four exact golden matches.
- Static analysis: no issues.
- Android debug APK built successfully; ZIP inspection confirms both WebP images
  and both theme font files are included. Existing plugin warnings about future
  Kotlin Gradle Plugin compatibility remain unrelated to this visual change.
- Expanded screen suite: 227 tests passed. The matrix exercises login, Home, empty/populated Quests,
  Friends, Profile, quest detail, creation, emoji picker, duels and Perks at 320,
  768 and 1440 pixels for Editorial, in both modes at 1× and 1.6× text scaling.

Preview goldens `editorial_*` use production theme/cover widgets with illustrative
content, not a live user account. The screen matrix uses real app screens with
stubbed providers. Device frame-time profiling and live backend interactions
were not part of these automated checks; no claim of measured device FPS is made.
No store release was published by this task.
