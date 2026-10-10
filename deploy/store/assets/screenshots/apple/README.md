# Apple Store screenshot provenance

Capture completed successfully on 10 October 2026. All eight renders were
visually inspected. Seven were selected for the Store: three iPhone images and
four iPad images. The iPhone Editorial Dark render is excluded because the
simulator retained dark status-bar symbols over the dark background. The app's
AppBar already requests light symbols in dark mode; verify the actual iPhone
behavior before device acceptance. Do not alter or retouch this capture to hide
the issue. The iPad Editorial Dark render has readable status and Activity text.

Do not upload previous run 38056278657: visual inspection found the Activity
panel retaining a light fill after switching to Editorial Dark. Build 11 fixes it.

The successful replacement workflow is [38076725703](https://github.com/brenzelB/Aura100/actions/runs/38076725703),
using source `d36b61d`. Its production lib/assets/iOS sources are exactly identical
to signed release candidate 1.0.2 (11), source `423dad4`. Only the isolated capture
entrypoint/controller/workflow changed after the signed release.

Run 38075185296 captured the four iPhone views but timed out waiting for a frame
callback on the first iPad page. Its diagnostic image shows a fully rendered Home
view. The capture now explicitly schedules rendering and lets the event loop settle,
without awaiting a callback across the simulator's startup lifecycle transitions.

The capture uses the production Home/Quests widgets with three illustrative,
locally supplied quests. It does not log into an account, use live personal
data or write to the NAS. The debug capture entrypoint is separate from the
release entrypoint. No screenshot-only functionality is included in the release.

Selected files are unchanged simulator PNGs. iPhone 17 Pro images are
1206 x 2622; iPad Pro 13-inch (M5) images are 2064 x 2752. `manifest.json`
records SHA256 hashes, dimensions, capture/release commits and the excluded file.
The unselected original remains in ignored `build/store/apple-screenshots-38076725703/`.

Saved in App Store Connect version 1.0.2 for both German and English (USA):
three medium-Dynamic-Island iPhone images and four iPad 13-inch images per
localization. Uploads are explicit for each language; all four counts were
verified after reloading the page. Save is disabled because no unsaved metadata
remains. This is an unpublished Store draft, not an App Review submission.

Desktop delivery: `AuraQuest_Store_Bilder/Apple_iOS/` contains the seven selected
PNGs, this README and the manifest; every copied PNG hash was verified.
`Nicht_fuer_Store/` separately preserves the excluded iPhone Dark original
with a warning. It was not uploaded to Apple or included in the approved selection.

Views, in Store order:

1. Home / Neo Brutalist Light: daily check-ins and countable reading progress.
2. Quests / Neo Brutalist Light: progress, cooperative training, Aura and Perks.
3. Quests / Editorial Growth Light: the optional editorial design.
4. Home / Editorial Growth Dark: the independent dark design (iPad only).

The workflow checks supported dimensions, four different images per device and
eight images in total. All guards passed, with no Flutter rendering exceptions
in the capture logs. The seven selected images passed visual inspection.
Simulator rendering does not verify real-device sign-in, deletion, notifications,
gameplay or animation performance. Those remain in the TestFlight acceptance plan.
