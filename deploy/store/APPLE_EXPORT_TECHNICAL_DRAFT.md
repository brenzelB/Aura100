# Apple encryption review — build 1.0.2 (11)

Technical preparation only. No export declaration, exemption or French filing
has been submitted. The app's operator must confirm the applicable declaration
before the public release.

## Verified package

- Bundle: `com.auraquest.auraQuest`, team `W558BUSST2`.
- Build: `1.0.2 (11)`, release source `423dad4`.
- IPA SHA256: `ad07dccbd697fcfda5439edeea0e4086ee929f9a4ae5c4283ac7650fbc33cca5`.
- `ITSAppUsesNonExemptEncryption` is not declared in the exported app.
- `webcrypto.framework` is absent. This does not establish that the remaining
  networking implementation uses only Apple's operating-system encryption.
- The exported Flutter engine contains TLS/SSL implementation markers including
  `SSL routines`, `CERTIFICATE_VERIFY_FAILED`, `TLSv1` and `SSL_CTX`.

## Cryptography and purpose

| Component | Purpose | Shipped in the iOS application? |
| --- | --- | --- |
| HTTPS/TLS via Flutter/Dart networking and native SDKs | Authentication and communication with `api.brenzel.uk`, Firebase and Apple | Yes |
| SHA-256 nonce used for Sign in with Apple | Binds the Apple response to the originating authentication request | Yes |
| Native Sign in with Apple services | Operating-system authentication flow | Yes, through Apple APIs |
| NAS worker AES-256-GCM token storage and ES256 client-secret signing | Protect retained Apple refresh tokens and authorize their revocation | No; server-side only |

There is no user-facing custom encrypted messaging, VPN or general-purpose
encryption feature. No proprietary encryption algorithm has been intentionally
implemented. These technical findings alone are not a legal exemption decision.

## Public-release decision still needed

Apple's published table distinguishes OS-only encryption from industry-standard
encryption implemented outside the Apple OS. The latter requires a French
encryption declaration when the app is distributed in France. The draft country
selection includes France, so this must be resolved before worldwide submission.

1. Confirm the shipped networking implementation and the applicable export
   classification/documentation using this build's evidence.
2. If France requires a filing, prepare and obtain the actual declaration and
   upload it in App Store Connect. A technical draft is not a filing receipt.
3. If the operator chooses to launch elsewhere first, obtain explicit approval
   to exclude France from availability and use the matching declaration.
4. Only then save the accurate build-level answers or exemption key. Never reuse
   build 9's internal no-France answer for the worldwide Store release.

Sources checked 10 October 2026:

- [Apple encryption documentation requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/)
- [Apple procedure for determining and uploading encryption documentation](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation)
- [Dart SecureSocket TLS/SSL implementation](https://api.dart.dev/dart-io/SecureSocket-class.html)
- [ANSSI control procedures and consumer-product classification](https://cyber.gouv.fr/reglementation/reglementation-identite-confiance-numerique/controles-reglementaires-cryptographie/controle-moyen-de-cryptologie/controle-rglementaire-cryptographie-demarches/)
- [ANSSI filing process](https://cyber.gouv.fr/reglementation/reglementation-identite-confiance-numerique/controles-reglementaires-cryptographie/controle-moyen-de-cryptologie/)

The current draft remains unsubmitted. Neither a French government response nor
Apple approval is available. ANSSI's published consumer-product classification
procedure requires validation; the app has not received such a classification.
