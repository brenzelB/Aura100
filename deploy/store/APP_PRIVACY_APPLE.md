# Apple App Store — App-Datenschutzangaben (App Privacy)

Leitfaden zum Ausfüllen des Bereichs **"App-Datenschutz" (App Privacy)** in **App Store Connect** für **Aura Quest**.

---

## 1. Werden in dieser App Daten erfasst?

Wähle: **Ja, wir erfassen Daten aus dieser App.**

---

## 2. Erfasste Datentypen

### A. Kontaktdaten (Contact Info)
- **Name:** bei Google-Anmeldung kann der Provider einen Namen liefern, der in den Auth-Identitätsdaten gespeichert wird. Konto-verknüpft, App-Funktionalität, kein Tracking. Der frei gewählte App-Nutzername gehört zusätzlich unter User ID.
- **E-Mail-Adresse:**
  - *Verknüpfung mit der Identität des Nutzers:* **Ja** (an Nutzer-ID gebunden)
  - *Zu Tracking-Zwecken verwendet:* **Nein**
  - *Zweck:* **App-Funktionalität** (App Functionality) — Authentifizierung, Account-Wiederherstellung.

### B. Kennungen (Identifiers)
- **Benutzer-ID (User ID):**
  - *Verknüpfung mit der Identität des Nutzers:* **Ja**
  - *Zu Tracking-Zwecken verwendet:* **Nein**
  - *Zweck:* **App-Funktionalität** — Zuordnung von Quests, Duellen, Freunden und Aura-Punkten.
- **Geräte-ID (Device ID):**
  - *Verknüpfung mit der Identität des Nutzers:* **Ja**
  - *Zu Tracking-Zwecken verwendet:* **Nein**
  - *Zweck:* **App-Funktionalität** — Push-Token zur Zustellung von Benachrichtigungen.

### C. Benutzerinhalte (User Content)
- **Gameplay-Inhalte:**
  - *Verknüpfung mit der Identität des Nutzers:* **Ja**
  - *Zu Tracking-Zwecken verwendet:* **Nein**
  - *Zweck:* **App-Funktionalität** — Quest-Namen und -Beschreibungen, Check-ins, Duell- und Spielfortschritt sowie im Spiel freigeschaltete Perks.
- **Andere Benutzerinhalte:** freie Quest-Beschreibungen und Meldungstexte. Konto-verknüpft, App-Funktionalität, kein Tracking. Aus beliebigen Freitextfeldern folgt keine pauschale Erfassung aller darin denkbaren sensiblen Datentypen.
- **Kundensupport:** Sicherheits-/Moderationsmeldungen und deren Bearbeitung. Konto-verknüpft, App-Funktionalität, kein Tracking.

### D. Kontakte, Fitness und Käufe

- **Kontakte:** der in der App gespeicherte Freundschaftsgraph. Das ist kein Zugriff auf das Telefon-Adressbuch. Konto-verknüpft, App-Funktionalität, kein Tracking.
- **Fitness:** manuell gespeicherte Trainingsziele und Fortschritt, beispielsweise Wiederholungen oder Kilometer. Kein HealthKit-/Bewegungssensor-Zugriff. Konto-verknüpft, App-Funktionalität, kein Tracking.
- **Kaufverlauf:** mit virtueller Aura erworbene Perks (`benefit_purchases`). Keine Zahlungen, Kreditkarten oder Echtgeldkäufe. Konto-verknüpft, App-Funktionalität, kein Tracking.

### E. Nutzung und technische Protokolle

- **Produktinteraktion:** Auth-Audit-Ereignisse wie Anmeldungen und Kontoaktionen mit Zeitstempel und Konto-ID. Konto-verknüpft, ausschließlich App-Funktionalität/Sicherheit, keine Verhaltensanalyse oder Werbung.
- **Andere Diagnosedaten:** technische Verbindungs- und Auth-Protokolle einschließlich IP-Adresse. Konto-verknüpft, App-Funktionalität/Betrieb und Missbrauchsabwehr, kein Tracking. Keine Standortbestimmung aus IP-Adressen.

Die aktive NAS-Instanz besitzt `auth.audit_log_entries` mit `created_at`, `ip_address` und dem Payload-Feld `actor_id`. Diese Daten dürfen bei den Store-Angaben nicht fehlen, auch wenn kein Analyse- oder Crash-SDK eingebaut ist.

### F. Technische Metadaten des Firebase-SDK

- **Andere Datentypen:** Firebase-User-Agent mit SDK-/Plattform-/OS- und App-Versionsinformationen. **Nicht mit dem Nutzer verknüpft**, **kein Tracking**, Zweck **Analysen** zur technischen Plattform-/Versionsverbreitung des SDK-Anbieters. Das ist zusätzlich zu den zwölf konto-verknüpften App-Funktionalitätsangaben zu deklarieren.
- Der exportierte Build 10 enthält im `Firebase_FirebaseMessaging.bundle` eine eigene Privacy-Datei mit `OtherDataTypes`, nicht verknüpft, nicht für Tracking, Zweck Analytics. Laut [Firebase-Datenerfassungsdokumentation](https://firebase.google.com/docs/ios/app-store-data-collection) werden Firebase-User-Agent-Daten standardmäßig gesammelt und vom Firebase-Team für technische Produktentscheidungen genutzt. Kein Firebase-Analytics-, Crashlytics-, Performance- oder Werbe-SDK ist eingebaut; daraus folgt trotzdem keine vollständige Abwesenheit technischer Anbieterstatistiken.

---

## 3. Datenverwendung & Tracking

| Frage | Antwort |
|---|---|
| **Verfolgen (Tracking) Sie Nutzer über Apps und Websites anderer Unternehmen hinweg?** | **Nein** (Kein IDFA-Zugriff, kein Werbe-Tracking) |
| **Werden Daten für Drittanbieter-Werbung genutzt?** | **Nein** |
| **Werden Daten für Entwickler-Werbung oder Marketing genutzt?** | **Nein** |
| **Werden Daten an Datenbroker verkauft?** | **Nein** |

---

## 4. Privacy Manifest (`PrivacyInfo.xcprivacy`)

Die Datei unter [`ios/Runner/PrivacyInfo.xcprivacy`](../../ios/Runner/PrivacyInfo.xcprivacy) ist im Xcode-Projekt registriert und nennt:
- `NSPrivacyAccessedAPITypeUserDefaults`: Begründung `CA92.1` (Zugriff auf lokale Einstellungen für Theme & Audio)
- Name, E-Mail, User ID, Device ID, Contacts, Fitness, Gameplay Content, Other User Content, Customer Support und Purchase History als mit dem Konto verknüpft, nicht für Tracking, zur App-Funktionalität.
- Product Interaction und Other Diagnostic Data für konto-bezogene Sicherheits- und Verbindungsprotokolle, ebenfalls App-Funktionalität ohne Tracking.
- Keine Tracking-Domains; `NSPrivacyTracking` ist `false`.

Diese Deklaration muss vor dem Upload gegen den finalen iOS-Build und alle eingebundenen SDKs abgeglichen werden. Die Push-Angaben setzen voraus, dass FCM/APNs tatsächlich für iOS aktiviert wird. Die Store-Privacy-Antworten müssen auch die Datenverarbeitung durch die verwendeten Dienste berücksichtigen; ein Privacy Manifest ersetzt das App-Privacy-Formular nicht.

## 5. Vor dem Einreichen abgleichen

- In App Store Connect die tatsächlichen Datenflüsse von Supabase, Firebase/APNs, Apple Sign in und Google Sign-In prüfen.
- Die Schriftdateien der beiden Google-Fonts-Familien liegen jetzt lokal im App-Bundle; der App-Code unterbindet Runtime-Fetches dieser Fonts.
- Die öffentlich verlinkte Datenschutzerklärung muss diese Dienste, Aufbewahrung, Löschung und Kontakt aktuell erklären.
- Keine Tracking-Aussage bestätigen, bevor die finalen SDKs und deren Konfiguration geprüft wurden.

Abgleich am 10.10.2026: Firebase-iOS-Konfiguration hat Analytics und Ads deaktiviert. Das App-Privacy-Formular in App Store Connect ist noch offen. Maßgeblich sind [Apples Datentypen und Freitext-Hinweise](https://developer.apple.com/app-store/app-privacy-details/); das finale Xcode-Privacy-Report muss vor der Einreichung gegen diese Angaben geprüft werden.

Exportprüfung des tatsächlichen IPA 1.0.2 (10): 22 eingebettete Privacy-Dateien, 13 deklarierte Datentypen in der Vereinigung, kein Tracking. Die zwölf eigenen App-Datentypen stehen im Runner-Manifest; die zusätzliche technische Firebase-Deklaration steht im SDK-Manifest. Prüfdatei: ignoriert `build/audit/ios-build-10-privacy-report.json`. Diese eigene Archivprüfung ist kein von Xcode erzeugter Privacy Report und ersetzt keinen Gerätetest.
