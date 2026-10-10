# Apple Store screenshot provenance

Capture is running. Do not upload previous run 38056278657: visual inspection
found the Activity panel retaining a light fill after switching to Editorial Dark.

The replacement workflow is [38076725703](https://github.com/brenzelB/Aura100/actions/runs/38076725703),
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

Expected views, in Store order:

1. Home / Neo Brutalist Light: daily check-ins and countable reading progress.
2. Quests / Neo Brutalist Light: progress, cooperative training, Aura and Perks.
3. Quests / Editorial Growth Light: the optional editorial design.
4. Home / Editorial Growth Dark: the independent dark design.

The workflow checks supported dimensions, four different images per device and
eight images in total. Visual inspection is also required before upload.
Simulator rendering does not verify real-device sign-in, deletion, notifications,
gameplay or animation performance. Those remain in the TestFlight acceptance plan.
