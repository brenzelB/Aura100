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

Build: flutter build appbundle --release --build-number=2
Verify the resulting AAB with keytool -printcert -jarfile.
The certificate must not identify Android Debug.

## Apple

The workflow produces an **unsigned xcarchive**, not a distributable IPA.
Its artifact name says ios-unsigned-archive. It checks iOS SDK >=26 on macOS 26
and fails if the archive is missing.

Store export needs an Apple Developer team, distribution certificate,
provisioning profile for com.auraquest.auraQuest and export options.
Configure them after the account/app identity is confirmed.
iOS Firebase/APNs and physical-device testing are also outstanding.

No store upload or review submission happens automatically.
See docs/2026-09-10-store-readiness.md for remaining blockers.
