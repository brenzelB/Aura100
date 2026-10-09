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

Build: flutter build appbundle --release --build-name=1.0.2 --build-number=6
The existing local AAB was built on 30 September 2026, before the current
changes. Do not upload it. Build a fresh AAB from the final, tested commit
through the release workflow, then verify it with keytool -printcert -jarfile.
The certificate must not identify Android Debug.

## Apple

The workflow produces an **unsigned xcarchive**, not a distributable IPA.
Its artifact name says ios-unsigned-archive. It checks iOS SDK >=26 on macOS 26
and fails if the archive is missing.

The project now contains Sign in with Apple and Push Notifications capability
settings. Store export still needs the active Apple team, distribution
certificate, provisioning profile for `com.auraquest.auraQuest`, export
options, and the matching iOS Firebase/APNs configuration. The current job
still creates an unsigned archive, not an IPA. TestFlight and real-device
acceptance have not been completed.

No store upload or review submission happens automatically.
See [the current readiness report](../../docs/2026-10-09-apple-launch-readiness.md)
for remaining blockers. The September report is historical.

Current release candidate: version 1.0.2, build 6. Confirm build 6 is unused
in both stores before building. Launch the release workflow with an explicit
`build_number=6` so Android and iOS share the same build number.
See RELEASE_NOTES_1.0.2.md for the current store notes.
