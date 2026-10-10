# Apple age and content declarations — prepared for confirmation

Not saved or submitted. This is a proposed questionnaire based on the current
app, not an Apple-assigned rating or a legal opinion. The user must confirm the
declarations before they are submitted to Apple.

| Questionnaire content | Proposed answer | Evidence / reason |
| --- | --- | --- |
| Parental controls | No | No parent account or parental control UI. |
| Age assurance | No | No identity/DOB verification or Apple's declared-age API. |
| Unrestricted web access | No | Fixed support/legal links open externally; no general-purpose in-app browser. |
| User-generated content | Yes | Usernames, quest names and descriptions shared with quest members. |
| Social media | Yes | Shared quest activity and friend-based social interaction; conservative disclosure. |
| Social media disabled under 13 | No | Apple's declared-age API is not implemented; do not imply verified age restrictions. |
| Messaging and chat | Yes | Invitations and predefined nudges communicate directly with other users. No free-text chat. |
| Advertising | No | No paid advertisements. |
| Profanity or crude humor | Infrequent | Optional failure/give-up roasts with mild, provocative humor; no explicit profanity found in the built-in collections. |
| Horror/fear | None | No horror imagery or fear-driven content. |
| Alcohol, tobacco or drug references | Infrequent | A built-in roast mentions sleeping pills. User goals may also include quitting smoking; no promotion of substance use. |
| Medical/treatment information | None | No diagnoses, prescriptions or treatment advice. |
| Health and wellness topics | Yes | Manual training, reading and focus goals; no HealthKit or sensor data. |
| Mature/suggestive themes; sexual content/nudity | None | No such built-in images or content. |
| Cartoon/fantasy, realistic or graphic violence; weapons | None | Heists and Aura losses are abstract game mechanics, without depicted violence. |
| Real-money gambling | No | Aura cannot be purchased for cash or redeemed/withdrawn for cash. |
| Simulated gambling | Infrequent | Optional dice duels wager virtual Aura; this meets Apple's definition even without real money. The core experience is completing habits. |
| Contests | Frequent | Quest competition, rankings and shared progress are continuing core features. |
| Loot boxes | No | No randomized purchased reward boxes. |

Request a **minimum of 16+**, consistent with the published target age, only if
Apple's calculated rating is lower. Never override a higher computed rating
downward. Country-specific ratings and requirements must be read from Apple's
computed result; the final result is not known yet.

Source: [Apple's definitions and regional age ratings](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions).

## Content rights

Proposed selection: **Yes, the app contains/displays third-party content and has
the necessary rights.** Bundled fonts include OFL licenses, the visual assets
were prepared for this app, and users can supply quest/profile text. The
operator must confirm the right to distribute these assets and display user
content. Do not select “no third-party content” merely because there is no
external news/video feed.

## Export compliance

Build 10 no longer contains `webcrypto.framework`. This alone does **not** prove
the entire Flutter/Dart networking stack uses only Apple's OS cryptography.
The app uses HTTPS/TLS and a SHA-256 nonce for Apple authentication. The NAS
worker's AES token storage is server-side and is not shipped in the IPA.

Do not reuse build 9's internal no-France declaration for worldwide release,
declare “no encryption”, or automatically set the exemption flag without
resolving the actual networking implementation and relevant import/export
requirements. France is included in the draft country selection but its
public-release compliance remains open.

Sources: [Dart SecureSocket](https://api.dart.dev/dart-io/SecureSocket-class.html),
[Apple encryption documentation](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/).
