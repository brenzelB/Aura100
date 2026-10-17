# Apple age and content declarations — replacement draft, 17 October 2026

The 16 October answers below were saved for build 14, including infrequent
simulated gambling. Apple stopped that review because the app was submitted by
an individual developer. The replacement game removes wagers and all Aura/XP
gains, losses and transfers. The updated simulated-gambling answer below is for
the verified replacement build only; it has not yet been saved to App Store
Connect. The previous build must not be relabelled as gambling-free.

The user explicitly confirmed these declarations on 16 October 2026. The answers
and content rights are saved in App Store Connect. Apple calculated 13+; the
confirmed minimum target age was applied by overriding to 16+. Apple assigns
regional equivalents and globally 17+ for operating systems older than version 26.
Build 14 was submitted on 16 October; review was subsequently stopped as reported
by the user on 17 October. No public release has occurred.

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
| Cartoon/fantasy, realistic or graphic violence; weapons | None | Rock-paper-scissors uses hand symbols and playful text, without depicted violence. |
| Real-money gambling | No | Aura cannot be purchased for cash or redeemed/withdrawn for cash. |
| Simulated gambling | None — replacement build only | Free rock-paper-scissors has no stakes, currency rewards, transfers or paid retries. Old dice/Heist wagering endpoints are disabled. Change the saved answer only with the replacement build. |
| Contests | Frequent | Quest competition, rankings and shared progress are continuing core features. |
| Loot boxes | No | No randomized purchased reward boxes. |

Request a **minimum of 16+**, consistent with the published target age, only if
Apple's calculated rating is lower. Never override a higher computed rating
downward. Country-specific ratings and requirements must be read from Apple's
computed result. The saved result is 16+ with Apple's regional equivalents.

Source: [Apple's definitions and regional age ratings](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions).

## Content rights

Proposed selection: **Yes, the app contains/displays third-party content and has
the necessary rights.** Bundled fonts include OFL licenses, the visual assets
were prepared for this app, and users can supply quest/profile text. The
operator must confirm the right to distribute these assets and display user
content. Do not select “no third-party content” merely because there is no
external news/video feed.

## Export compliance

Build 11 no longer contains `webcrypto.framework`. This alone does **not** prove
the entire Flutter/Dart networking stack uses only Apple's OS cryptography.
The app uses HTTPS/TLS and a SHA-256 nonce for Apple authentication. The NAS
worker's AES token storage is server-side and is not shipped in the IPA.

Do not reuse build 9's internal no-France declaration for worldwide release,
declare “no encryption”, or automatically set the exemption flag without
resolving the actual networking implementation and relevant import/export
requirements. On 16 October the user explicitly chose the initial launch without
France. France is now unavailable; build 11's standard-encryption/no-France
answers are saved. French documentation remains necessary to resolve before
adding that country later.

Sources: [Dart SecureSocket](https://api.dart.dev/dart-io/SecureSocket-class.html),
[Apple encryption documentation](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/).
