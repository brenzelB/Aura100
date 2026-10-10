# Store builds

Flutter is pinned to 3.44.6 in both GitHub workflows. The marketing version
comes from pubspec.yaml. Both platforms share the same CI build number.
Use a number greater than every previously submitted build.

## Android

Release builds require a real keystore. Missing signing properties or a
missing keystore stop the build; there is no debug-signing fallback.
Local credentials live in android/key.properties. storeFile is relative
to android/app. Keep and back up the existing upload key.

GitHub Actions requires encrypted repository secrets:
- ANDROID_KEYSTORE_BASE64: base64 of the existing upload keystore.
- ANDROID_KEY_PROPERTIES: the four signing properties, using
  storeFile=../aura-quest-release.jks for CI.

Never commit signing credentials. With Play App Signing, a lost upload key
can be reset through Play Console; it differs from Google's app signing key.

Build: flutter build appbundle --release --build-name=1.0.2 --build-number=7
The existing local AAB was built on 30 September 2026, before the current
changes. Do not upload it. Build a fresh AAB from the final, tested commit
through the release workflow, then verify it with keytool -printcert -jarfile.
The certificate must not identify Android Debug.

## Apple

The default workflow produces an **unsigned xcarchive** for validation.
Choose `ios_signing=app-store` to export a signed App Store IPA on macOS 26.
That path checks the profile's team, bundle, expiration, Apple login and
production APNs entitlements before signing. It needs these repository secrets:

- `IOS_FIREBASE_PLIST_BASE64`: matching GoogleService-Info.plist.
- `IOS_DISTRIBUTION_P12_BASE64`: Apple Distribution certificate/private key.
- `IOS_DISTRIBUTION_P12_PASSWORD`: its export password.
- `IOS_PROVISION_PROFILE_BASE64`: App Store profile for this exact App ID.

`upload_testflight=true` additionally requires `APPLE_API_KEY_BASE64`,
`APPLE_API_KEY_ID` and `APPLE_API_ISSUER_ID`. It uploads the IPA for processing;
it does not submit it for App Review or release the app. Leave this option false
until the credentials and upload have been specifically authorized.

The project now contains Sign in with Apple and Push Notifications capability
settings. Store export still needs the active Apple team, distribution
certificate, provisioning profile for `com.auraquest.auraQuest`, export
options, and matching Firebase/APNs credentials. Firebase iOS registration and
native NAS Apple configuration are complete; credential transfer/signing,
Apple token revocation on deletion and real-device acceptance remain open.
The signed path has not run yet. Certificate requests are prepared with
`scripts/prepare-ios-csr.ps1`; ignored files stay in `build/apple-private/`.

No store upload or review submission happens automatically.
See [the current readiness report](../../docs/2026-10-09-apple-launch-readiness.md)
for remaining blockers. The September report is historical.

Current release candidate: version 1.0.2, build 7. Confirm build 7 is unused
in both stores before building. Launch the release workflow with an explicit
`build_number=7` so Android and iOS share the same build number.
See RELEASE_NOTES_1.0.2.md for the current store notes.
