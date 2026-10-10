# Public Apple launch preparation — 10 October 2026

Candidate: **1.0.2+10**. This is not evidence of public release or device acceptance.

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

- Existing 375 Flutter tests, including eight exact theme goldens: passed.
- Flutter analyzer: passed.
- Apple backend isolation/encryption/deletion regression tests: passed.
- New PostgreSQL guard tests and existing lifecycle tests: passed in the
  network-isolated NAS test container. Deployment must additionally restore a
  fresh live backup and test against the actual GoTrue identity schema.
- Apple Sign-in key creation and transfer to NAS require the user's explicit
  approval; requested for `Aura Quest Account Revocation`, exact bundle/team.
- The live NAS worker/database deployment, signed build, screenshot capture,
  final IPA encryption/privacy inspection and Store forms are in progress.
- Real iPhone/iPad Apple sign-in, revocation, push and Android/iOS interaction
  remain unverified until performed with the final deployed build.
- Build 9's no-France internal declaration is not reused for public launch.
- No App Review submission or public release has been performed.
