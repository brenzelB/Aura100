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

- Source: `2f084265068a564f682de429ebaa0ebd7ea43c49`.
- Workflow: https://github.com/brenzelB/Aura100/actions/runs/40023666465.
- Workflow conclusion: success after rerunning the queued iOS job. Analysis,
  behavior checks, exact Windows theme screenshots, Android signing, and iOS
  signing all passed.
- Android AAB: `build/store/android-release-1.0.3-20/app-release.aab`,
  SHA-256 `c979e728e0d863ce7503d67333710532ceb830d90579a3e07bf496a8e919d48a`.
- Google Play internal track: release 6, **Aura Quest 1.0.3 (20) - Cut & Grow**,
  marked “Für interne Tester verfügbar” on 24 October 2026. Testers join at
  https://play.google.com/apps/internaltest/4701204184033716950. The existing
  tester list currently contains one account.
- Signed iOS IPA: `build/store/ios-1.0.3-20/ipa/Aura Quest.ipa`,
  SHA-256 `d1c0835d136be0fd7856e1d0c424068f633a1e5188e912b3f1e4942016464e10`.
  Apple build `9c95a557-237c-46fe-83cd-5f8c3a1ae743` processed as `VALID`,
  export compliance was recorded as standard encryption and not distributed
  in France, and the build is `IN_BETA_TESTING` in **Aura Quest iOS intern**.
  That existing internal group currently contains one tester and now has 10
  builds; automatic notification is enabled.
- The public App Store version remains 1.0.2 (16). This upload did not submit
  or publish a new public store version.

The internal track and TestFlight group show build 20 as available to testers.
Physical-device acceptance for the new build remains open; the existing tester
has not yet installed or exercised build 20 on an iPhone.
