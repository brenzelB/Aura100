# Cut & Grow internal test release 1.0.3 (20)

Authorized on 23 October 2026: upload the selected Cut & Grow implementation
to TestFlight and the existing internal Google Play test track. Public
publication is outside this request.

## Scope and validation

Only Editorial Growth receives the selected replacement world. Brutal
Neutralism and Auralis retain their design and behavior. Existing game rules,
authentication, account data, backend, navigation and feedback are retained.
See `2026-10-23-cut-and-grow.md` and root `DESIGN.md` for implementation detail.

Before the release-number change, all 458 Flutter tests passed, including the
four unchanged other-theme goldens and the four updated Editorial goldens.
Static analysis was clean. The normal Android debug app built and was restored
on the test emulator. A fresh Impeccable review and scored correction were
completed, including twelve native phone/wide/large-text captures.

The version-only change is 1.0.3+19 → 1.0.3+20. The release workflow reruns
analysis, behavior tests, exact Windows goldens and native signing guards.

## Distribution status

- Source commit and workflow: pending.
- Signed Android AAB and internal-track availability: pending.
- Signed iOS IPA, Apple processing and internal-group availability: pending.

An uploaded artifact or completed CI job alone does not establish availability
to testers. Verify each store's internal distribution state before marking it
complete. Physical iPhone testing remains a separate acceptance step.
