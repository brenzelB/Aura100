---
name: Aura Quest — Editorial Growth / Cut & Grow
description: An opt-in paper-cut visual world for daily quests, with deliberate light and dark appearances.
colors:
  light-ground: "#F7E7F2"
  light-panel: "#FFF8F4"
  light-track: "#E8D7E2"
  light-ink: "#312149"
  light-muted: "#6A4D67"
  light-action: "#FE6746"
  light-link: "#A63420"
  light-success: "#296044"
  light-warning: "#785013"
  light-danger: "#B32C24"
  light-line: "#D6BED2"
  light-input-line: "#84617F"
  dark-ground: "#24182F"
  dark-panel: "#382542"
  dark-track: "#5B4064"
  dark-ink: "#FFE9DB"
  dark-muted: "#D6BDD4"
  dark-action: "#FFB08E"
  dark-success: "#B7EBCC"
  dark-warning: "#F2CB8D"
  dark-danger: "#FF9F93"
  dark-line: "#57405F"
  dark-input-line: "#B399B8"
  mint: "#B7EBCC"
  accent-ink: "#312149"
  button-ink: "#000000"
  cut-line-light: "#9C7B97"
  cut-line-dark: "#9A7FA0"
  invitation-dark: "#3D3C44"
typography:
  display:
    fontFamily: Editorial Display
    fontSize: 52px
    fontWeight: 400
    lineHeight: 1.08
    letterSpacing: -0.7px
  display-medium:
    fontFamily: Editorial Display
    fontSize: 48px
    fontWeight: 400
    lineHeight: 1.08
  display-small:
    fontFamily: Editorial Display
    fontSize: 43px
    fontWeight: 400
    lineHeight: 1.08
  headline:
    fontFamily: Editorial Display
    fontSize: 38px
    fontWeight: 400
    lineHeight: 1.08
  headline-medium:
    fontFamily: Editorial Display
    fontSize: 29px
    fontWeight: 400
    lineHeight: 1.08
  headline-small:
    fontFamily: Editorial Display
    fontSize: 22px
    fontWeight: 400
    lineHeight: 1.08
  title-large:
    fontFamily: Editorial Display
    fontSize: 24px
    fontWeight: 400
    lineHeight: 1.08
  title:
    fontFamily: Editorial Body
    fontSize: 16px
    fontWeight: 700
    lineHeight: 1.4
  body:
    fontFamily: Editorial Body
    fontSize: 15px
    fontWeight: 500
    lineHeight: 1.4
  body-small:
    fontFamily: Editorial Body
    fontSize: 13px
    fontWeight: 500
    lineHeight: 1.4
  label:
    fontFamily: Editorial Body
    fontSize: 14px
    fontWeight: 800
    lineHeight: 1.4
  progress-value:
    fontFamily: Editorial Body
    fontSize: 32px
    fontWeight: 800
    lineHeight: 1.08
rounded:
  control: 12px
  panel: 16px
  track-cut: 1px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  page: 20px
  xl: 24px
  xxl: 32px
components:
  button-primary:
    backgroundColor: "{colors.light-action}"
    textColor: "{colors.button-ink}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: 14px 20px
  button-primary-dark:
    backgroundColor: "{colors.dark-action}"
    textColor: "{colors.button-ink}"
    rounded: "{rounded.control}"
  button-quest-action:
    backgroundColor: "{colors.light-action}"
    textColor: "{colors.accent-ink}"
    rounded: "{rounded.control}"
  button-outlined:
    backgroundColor: "{colors.light-panel}"
    textColor: "{colors.light-ink}"
    rounded: "{rounded.control}"
    padding: 12px 16px
  input:
    backgroundColor: "{colors.light-panel}"
    textColor: "{colors.light-ink}"
    rounded: "{rounded.panel}"
    padding: 16px
  navigation:
    backgroundColor: "{colors.light-panel}"
    textColor: "{colors.light-ink}"
    height: 72px
  chip:
    backgroundColor: "{colors.light-panel}"
    textColor: "{colors.light-ink}"
    rounded: "{rounded.control}"
  panel:
    backgroundColor: "{colors.light-panel}"
    textColor: "{colors.light-ink}"
    rounded: "{rounded.panel}"
---

# Design System: Aura Quest — Editorial Growth / Cut & Grow

## Overview

**Creative North Star: "Cut & Grow"**

This system applies **only to the existing Editorial Growth theme**. Brutal
Neutralism and Auralis keep their independent implementation and visual rules.
Do not apply these tokens to shared defaults without the Editorial branch.

Daily effort feels tangible through precise geometric cuts, editorial serif
headings and compact sans-serif controls. The light appearance uses rose paper,
aubergine ink, coral actions and mint notices. The night appearance is composed
from deep aubergine, raised plum surfaces, warm cream type and apricot actions.
The app's English voice stays playful and adult; task information stays direct.

**Key Characteristics:**
- Confirmed progress expressed through authored cut geometry.
- Flat color surfaces and a clear serif/sans hierarchy.
- Deliberate light and dark palettes with readable text twins.
- Native controls, existing actions and reduced-motion support.

## Colors

The frontmatter records the actual Editorial palettes in `app_colors.dart`.
Dark mode is a separate palette, not a color inversion. Mint identifies active
navigation and invitations; dark invitations use a muted raised ground with
mint text. The aubergine foreground on mint is the same in both modes.
Sidecar tonal ramps are derived documentation swatches; runtime colors remain
the explicit light and dark palettes above.

**The Fill and Ink Rule.** Coral is an action fill. Small labels and links use
the darker readable coral twin in light mode; never use the raw fill as small
text on rose or cream. Status text uses `successText`, `warningText` or `danger`.

Generic primary controls use `readableOn(fill)` (black for coral and apricot).
The authored Home/Quest progress actions explicitly use aubergine `onAccent`.

## Typography

**Display Font:** bundled DM Serif Display, Flutter family `Editorial Display`.
**Body Font:** bundled Plus Jakarta Sans, Flutter family `Editorial Body`.
No runtime font downloads are required for this theme.

Serif display sizes are 52/48/43; headings 38/29/22; the large title is 24.
They use weight 400, line height 1.08 and tracking -0.7 logical pixels. Body
sizes are 17/15/13 at weight 500 and line height 1.4. Titles use 16/14 at
weight 700; labels use 14/13/12 with stronger weights. Quest progress overrides
the large title to Jakarta 32/800; compact numeric progress uses Jakarta 16/700.

**The Numbers Rule.** Keep progress values in readable body type and real
quantity/unit formatting. Display type supplies character to headings without
turning every control or metric into a headline. Preserve text scaling and
reflow the cut marks when the scaled value needs more width.

## Layout

Values are Flutter logical pixels. Standard page gutters are 20, panel padding
16–20, compact gaps 4/8/12 and section separation 20–24. Do not give decorative
artwork a fixed hero region ahead of a daily action.

The existing shell switches from bottom navigation to a rail at width 840,
and extends the rail at 1200. Wide branch content is bounded to 880; the
Editorial root is bounded to 1040. Keep these shared navigation structures.
Home completion marks stack with large text or narrow available space. Quest
goal marks stack below the value under 280 available pixels or text scale >1.3.

## Elevation & Depth

Custom Editorial panels use flat tonal layering, without default shadows or
borders. Danger panels retain their danger outline. Existing Material dialogs
retain their native elevation; this is not permission to add ambient glow or
hard offset shadows to Editorial content. Other themes' depth rules are separate.

## Shapes

Panels are rounded rectangles at radius 16; buttons, chips and active navigation
indicators use radius 12. Inputs retain radius 16 with a clear focus stroke.
The signature cut is a precise two-corner curved shape, grouped at most three
at a time. Partial fills report proportional progress rather than invented
completion counts. Segmented tracks have ten cuts and a real fractional fill.

## Components

### Buttons

Primary coral/apricot actions sit on solid surfaces. Base filled controls have
minimum 48 × 52; quest actions explicitly use a 48-pixel minimum height.
Outlined and text controls retain a 48 × 48 minimum. Material hover, focus,
pressed, busy and disabled states remain available. Existing callbacks own
all writes, offline behavior, lockouts and feedback.

### Inputs and chips

Fields use solid panel fill, the input-outline token, 16-pixel content padding
and a 3-pixel focused outline. Errors use the danger color. Chips use the
rounded control shape and preserve selected and disabled Material states.

### Panels and navigation

Custom panels use `AppColors.panelDecoration` inside the Editorial branch.
Do not normalize unrelated existing Material components into a new global
card rule. The bottom navigation is 72 pixels high; the active marker is mint
with aubergine icons. Badges and the direct Activity entry retain actual counts.

### Cut marks and progress

`EditorialMarks` reports the real confirmed daily count, excluding pending
offline check-ins. `EditorialGoalMarks` uses the real quest progress ratio;
its neighboring value supplies accessible quantity information. A 40% goal
fills one cut and part of the next, while the ten-segment track fills four.
Goal marks are decorative to accessibility; daily marks expose the real count.

Progress changes use a 280 ms ease-out transition from an already visible
initial value. Reduced motion sets its duration to zero. The painter repaints
only for changed data or colors and sits in a repaint boundary. No repeating
ticker, parallax or network image is part of this system. Editorial Android/
desktop routes retain the small fade/slide transition; iOS keeps its existing
platform transition, including its native back behavior.

## Do's and Don'ts

### Do:
- **Do** confine Cut & Grow changes to Editorial Growth.
- **Do** preserve real data, English copy, existing actions and game rules.
- **Do** use readable ink tokens on rose, cream and plum surfaces.
- **Do** reflow progress geometry for enlarged text and respect reduced motion.
- **Do** keep original icon/logo pixels and record raster origins.

### Don't:
- **Don't** spread this palette, typography or panel shape to the other themes.
- **Don't** show a pending offline check-in as confirmed progress.
- **Don't** restore the discarded 3D botanical cover ahead of a daily action.
- **Don't** turn legacy uppercase labels into a new eyebrow typography rule.
- **Don't** infer iOS runtime or physical-device smoothness from Android captures.
