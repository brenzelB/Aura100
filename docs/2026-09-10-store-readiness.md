# Store readiness — 10 September 2026

**Result: not ready for submission.** Updated builds are necessary, but do not
replace the remaining signing, configuration and store review work.

The owner confirmed that no Apple Developer account exists yet. Apple output
therefore remains an unsigned build for validation, with no TestFlight submission.

## Existing GitHub artifacts

- Release run 33868092264: 4 September, commit 93cdeb551a25f2f2cd79fdbf18fe8a8444c86f12.
- Downloaded Android AAB certificate: **CN=Android Debug**. Not store-signable output.
- Apple output: unsigned xcarchive, not a distributable IPA.
- Remote HEAD before audit: 2e6604d. Latest balance, reset, UI and activity fixes
  were local and absent from the release artifacts.
- No repository signing secrets were configured at the start of this audit.

## Corrections

- Require Android signing properties and a valid keystore path for release tasks.
- Advance source version to 1.0.0+2; resolve a shared build number in CI.
- Label iOS job/artifact explicitly unsigned; fail on missing archive.
- Require iOS SDK >=26 on macOS 26; correct outdated build documentation.

## Outstanding submission requirements

| Area | Finding / next step |
|---|---|
| Apple signing | Confirm Developer team and App Store Connect app; configure distribution signing and export a real IPA. |
| Apple login | Google and email login are present, but no equivalent privacy-preserving login alternative. Resolve guideline 4.8, normally with Sign in with Apple. |
| iOS push | Runner has no Firebase plist, push entitlement or remote-notification background mode. Configure Firebase/APNs and verify on a physical iPhone. |
| Privacy manifest | Only email and user ID are declared. Reconcile user content, game interactions and device push identifiers with actual collection and store forms. |
| External account deletion | Public legal page describes in-app deletion only. Provide a clearly identified external request route for Play Console. |
| Moderation | Report/block UI exists. Demonstrate content filtering, published rules/contact and timely report handling for user-generated content. |
| Legal copy | Live /aura-quest/ returns HTTP 200 with operator details. Local markdown has placeholders. Live text is dated August and refers to the discontinued EU ODR platform. Reconcile factual copy, runtime Google Fonts requests and verified retention. |
| Store metadata | Screenshots, age/content ratings including dice wagering, data disclosures and reviewer access still need console verification. |
| Android | Pinned Flutter targets API 36. Final AAB native 16-KB alignment and device/pre-launch testing still need verification. |
| Backend | Defaults to the public NAS API. This build audit does not recertify RLS, backups or retention. Existing migrations must match shipped code. |
| Device tests | Previous Android emulator checks are available; physical iPhone/TestFlight and store-console validation are outstanding. |

## References

- [Google target API](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Android 16-KB pages](https://developer.android.com/guide/practices/page-sizes)
- [Apple SDK requirement](https://developer.apple.com/news/?id=ueeok6yw)
- [Apple Review Guidelines: 1.2, 4.8 and 5.1](https://developer.apple.com/app-store/review/guidelines/)
- [Google account deletion](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Firebase iOS messaging setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)

No store submission or publication is performed by these build workflows.
