# Apple encryption review — build 1.0.2 (11)

On 16 October 2026, after explicit user approval, France was removed from the
initial country selection. The build-level answers **standard encryption outside
or in addition to Apple's operating system** and **no distribution in France**
were saved in App Store Connect. Build 11 cleared Missing Compliance and is now
testing in the existing internal group. No French filing has been submitted;
the app has not been publicly released.

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

## Saved initial distribution decision

Apple's published table distinguishes OS-only encryption from industry-standard
encryption implemented outside the Apple OS. The latter requires a French
encryption declaration when the app is distributed in France. For the initial
release the user chose to exclude France. App Store Connect shows France as
unavailable and 174 selected countries/regions. All other country selections
remain unchanged; local age/content restrictions still apply separately.

The existing build was declared independently using its verified technical
evidence. No OS-only/no-encryption claim or exemption Info.plist flag was added.
Before adding France later, prepare and obtain the actual required documentation,
upload it for Apple's approval, and update availability and build declarations
consistently. A technical draft is not a filing receipt.

Sources checked 10 October 2026:

- [Apple encryption documentation requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/)
- [Apple procedure for determining and uploading encryption documentation](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation)
- [Dart SecureSocket TLS/SSL implementation](https://api.dart.dev/dart-io/SecureSocket-class.html)
- [ANSSI control procedures and consumer-product classification](https://cyber.gouv.fr/reglementation/reglementation-identite-confiance-numerique/controles-reglementaires-cryptographie/controle-moyen-de-cryptologie/controle-rglementaire-cryptographie-demarches/)
- [ANSSI filing process](https://cyber.gouv.fr/reglementation/reglementation-identite-confiance-numerique/controles-reglementaires-cryptographie/controle-moyen-de-cryptologie/)

No French government response or French-document approval is available.
ANSSI's published consumer-product classification
procedure requires validation; the app has not received such a classification.
