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

Build: flutter build appbundle --release --build-name=1.0.2 --build-number=NEXT_UNUSED_NUMBER
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
settings. The active team, distribution certificate/profile, Firebase plist,
production APNs configuration and seven iOS signing/upload Actions secrets are
configured. The signed export and Apple upload path succeeded for build 9.
The new signed build 10 passed all release jobs with Apple upload disabled.
Apple token revocation is implemented and tested against an isolated restored
NAS backup; its dedicated key and live NAS deployment still await confirmation.
Real-device acceptance and the public Store declarations remain open.
Private local files stay in ignored `build/apple-private/`.

No store upload or review submission happens automatically.
See [the current readiness report](../../docs/2026-10-10-apple-launch-completion.md)
for remaining blockers. The September report is historical.

Current signed candidate: **1.0.2 (10)**, source `f8590f6`,
[release run 38052895628](https://github.com/brenzelB/Aura100/actions/runs/38052895628).
Its `ios-app-store-ipa-10` and `android-release-bundle-10` artifacts are already
downloaded under ignored `build/store/`; neither build 10 artifact is uploaded.
Apple's active internal test remains build 9. For a new binary after build 10,
check both stores and use a greater unused shared build number.
See RELEASE_NOTES_1.0.2.md for the current store notes.
