# Apple App Store — App-Datenschutzangaben (App Privacy)

Leitfaden zum Ausfüllen des Bereichs **"App-Datenschutz" (App Privacy)** in **App Store Connect** für **Aura Quest**.

---

## 1. Werden in dieser App Daten erfasst?

Wähle: **Ja, wir erfassen Daten aus dieser App.**

---

## 2. Erfasste Datentypen

### A. Kontaktdaten (Contact Info)
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
- **Sonstige Benutzerinhalte:**
  - *Verknüpfung mit der Identität des Nutzers:* **Ja**
  - *Zu Tracking-Zwecken verwendet:* **Nein**
  - *Zweck:* **App-Funktionalität** — Speicherung der erstellten Habits, Check-ins, Duell-Ergebnisse und Einkäufe.

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

Die Datei ist bereits unter [`ios/Runner/PrivacyInfo.xcprivacy`](../../ios/Runner/PrivacyInfo.xcprivacy) angelegt und im Xcode-Projekt registriert:
- `NSPrivacyAccessedAPITypeUserDefaults`: Begründung `CA92.1` (Zugriff auf lokale Einstellungen für Theme & Audio)
- Keine verbotenen Tracking-Domains
- `NSPrivacyTracking`: `false`
