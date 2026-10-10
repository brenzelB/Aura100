# Public Apple launch preparation — 10 October 2026

Candidate: **1.0.2+11**. Build 10 is superseded by a visual regression found during
the screenshot inspection. This is not evidence of public release or device acceptance.

## Implemented

- Native Apple sign-in exchanges its one-time authorization code on the NAS and
  retains a user-bound AES-256-GCM encrypted refresh token. No private key or
  provider refresh token is returned to the app.
- Account deletion revokes the Apple authorization before the existing
  transactional deletion RPC. This also works from Android for retained Apple
  authorizations. Legacy accounts request Apple reauthorization on an Apple
  device. Direct RPC calls cannot bypass the revocation guard.
- Provider failure preserves the account. A failed local deletion can retry the
  idempotent Apple revoke request. A token version prevents a concurrent sign-in
  from incorrectly marking a replacement token as revoked.
- Android retains UnifiedPush's same Android implementation and default
  registration arguments. The unused Linux umbrella dependency and webcrypto
  were removed. FCM/APNs remain the iOS delivery mechanism.
- Added a separate, manually triggered iOS simulator screenshot workflow. It
  renders production Home/Quests widgets with illustrative local fixtures,
  without authenticating or writing to the NAS. It uses an isolated entrypoint
  and cannot be part of the normal release entrypoint.

## Evidence and open boundaries

- All 376 Flutter tests, including eight unchanged exact theme goldens and a new
  regression for Activity fill after changing Light/Dark mode: passed locally.
- Flutter analyzer: passed.
- Apple backend isolation/encryption/deletion regression tests: passed.
- All eight SQL regression suites passed after restoring a fresh live NAS backup
  into a disposable database with network isolation and inactive cron jobs.
  Twelve new revocation assertions include retained tokens after Apple unlinking.
  Backup: `backups/apple-revocation-before-20261010123430.dump`.
  The active database still has the original 12-migration baseline.
- Apple Sign-in key creation and transfer to NAS require the user's explicit
  approval; requested for `Aura Quest Account Revocation`, exact bundle/team.
- Signed [release run 38052895628](https://github.com/brenzelB/Aura100/actions/runs/38052895628)
  passed all four jobs on `f8590f6`: analysis/unit tests, exact theme goldens,
  signed Android AAB and signed iOS IPA. Apple upload was explicitly disabled.
- Downloaded IPA: `build/store/ios-1.0.2-10/ipa/Aura Quest.ipa`, SHA256
  `a9a92dd6ca06582575a874af5a0f1e3fb7a618734f8b3029ffbb6b4691b861ae`.
  Bundle ID, build number and iPad orientation guards passed. SDK is iphoneos26.5,
  minimum iOS 15.0. The unused webcrypto framework and screenshot-only fixtures
  are absent. Android artifact 11670037752 is downloaded and not sent to Google Play.
- Final [release run 38075183018](https://github.com/brenzelB/Aura100/actions/runs/38075183018)
  passed all four jobs on `423dad4`, producing signed build 11 with Apple upload
  disabled. All 376 Flutter tests passed locally; CI verified the non-golden
  tests on Linux and the eight unchanged goldens on Windows.
  Downloaded IPA: `build/store/ios-1.0.2-11/ipa/Aura Quest.ipa`, SHA256
  `ad07dccbd697fcfda5439edeea0e4086ee929f9a4ae5c4283ac7650fbc33cca5`.
  Artifact 11677964939, ZIP digest
  `1bee7ebbcf75d830c6a259bd757aa5957bf41e19137a9760f0fd4563867fc6ab`.
  Android artifact 11677719591 was also downloaded; AAB SHA256
  `38641ce748a333791a4a1d726c5f449dd39c26d0aa4d7e96271b37a20468fdbc`.
  Local keytool inspection identifies the existing Denis Brandt / AuraQuest /
  Brenzel release certificate, not Android Debug (certificate SHA256
  `56:66:F2:DF:01:59:70:58:13:6F:0E:DB:26:A6:D5:2A:49:BC:07:EB:B3:7D:9C:8F:C2:CB:4C:95:73:A7:1A:4F`).
  Neither candidate was uploaded to either Store. Build 9 remains the released
  internal TestFlight build.
- IPA privacy inspection found 22 SDK/app manifests and 13 data types, with no
  declared tracking. The FCM manifest additionally discloses unlinked technical
  SDK metadata for the provider's analytics; the Store/privacy draft reflects it.
  This archive inspection is not an Xcode-generated report or real-device test.
  Build 11's bundle/version/build, 22 manifests and 13 types were inspected again;
  all manifests exactly match build 10. Store fixtures and webcrypto remain absent.
- Saved Store preparation: copyright 2026 Denis Brandt; free pricing with Germany
  as base and 175 price regions; all 175 countries configured as available upon
  app release. German promotional copy and an English-US description, keywords
  and subtitle are saved. Both language privacy links point to the public page.
- Apple key and Review-credential approvals, review phone, privacy declaration,
  age/content-right declarations and live NAS deployment remain open. The legal
  page changes are local drafts, not yet deployed. The automatic approval review
  rejected saving the new Apple key and the privacy declaration without explicit
  confirmation; neither rejection was bypassed.
- Screenshot workflow 38056278657 completed on `66f53ce`, with four 1206 x 2622
  iPhone 17 Pro and four 2064 x 2752 iPad Pro 13-inch (M5) renders.
  Visual inspection of all eight found a stale light Activity panel with pale text
  in Editorial Dark after changing theme. The const inbox widget did not observe
  theme changes when its data stayed identical. It now watches the theme provider;
  the regression test exercises Light -> Dark -> Light with unchanged inbox data.
  No theme palette, layout or gameplay behavior changed. These pictures were not
  uploaded. Corrected screenshot run 38075185296 on `423dad4` captured all four
  iPhone views but timed out waiting for the first iPad page's VM extension reply.
  Its failure image shows a fully rendered Home view, with no Flutter UI error.
  The capture entrypoint now explicitly schedules rendering and uses an event-loop
  settling delay instead of awaiting a frame callback across startup lifecycle
  transitions. The host allows 90 seconds for the first reply and retains partial
  diagnostics/images if a capture fails. Full-set and duplicate guards still apply.
  Replacement run 38076725703 uses `d36b61d`; its production lib/assets/iOS sources
  are exactly identical to signed build 11's `423dad4`.
  Earlier runs found an unavailable old simulator name, a redundant-build timeout
  and a missing Dart log stream with a direct simulator launch. Run 38055174368
  produced four iPhone files, but inspection found a shifted page, one duplicate
  and no iPad files because Flutter consumed the device-list stdin. None was
  uploaded to Apple. The corrected workflow uses Flutter's prebuilt bundle and
  an isolated debug service extension to select each page explicitly; stdin is
  detached, dimensions/duplicates are checked, and all eight images are required.
  The controller's dev dependency was already present at the same version as a
  transitive dependency; no runtime dependency or normal release entrypoint changed.
  Analyzer passed after the controller update. Replacement images will be visually
  checked before uploading.
- Worldwide encryption/export compliance remains open. Removing webcrypto does
  not prove OS-only encryption: the exported Flutter engine still contains TLS
  implementation markers. No unverified exemption flag was added.
- Real iPhone/iPad Apple sign-in, revocation, push and Android/iOS interaction
  remain unverified until performed with the final deployed build.
- Build 9's no-France internal declaration is not reused for public launch.
- No App Review submission or public release has been performed.

Current operational guides: `deploy/store/README.md` and `RELEASE_CHECKLIST.md`
now identify candidate build 11 and the actual signing/secret setup. The saved English
listing/subtitle/keywords and both promotional texts are mirrored in the listing
files. `docs/apple-launch-naechste-schritte.md` explains the pending decisions in
German. The export draft and proposed age/content declarations are prepared,
not filed. The old Google Data Safety guide is explicitly marked incomplete;
this pass did not submit Android declarations or upload to Google Play.

The NAS deployment helper now routes preparation/write failures through the
backup rollback path and checks the existing push worker after recreating the
shared runtime. Syntax and dry-run checks passed. Its actual deployment remains
unperformed until the dedicated Apple key is approved.
