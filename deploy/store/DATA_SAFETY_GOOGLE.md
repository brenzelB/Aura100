# Google Play Datensicherheitsformular (Data Safety Form)

Leitfaden zum Ausfüllen des Formulars **"Datensicherheit" (Data Safety)** in der Google Play Console für **Aura Quest**.

---

## 1. Übersicht & Grundsatzfragen

| Frage in der Google Play Console | Antwort | Begründung / Kontext |
|---|---|---|
| **Erhebt oder teilt Ihre App Nutzerdaten?** | **Ja** | Die App erhebt Nutzerdaten für Authentifizierung, Spielfortschritt und Push-Benachrichtigungen. |
| **Werden alle vom Nutzer erhobenen Daten bei der Übertragung verschlüsselt?** | **Ja** | Alle Verbindungen laufen über gesichertes HTTPS / TLS zu Supabase. |
| **Bieten Sie Nutzern eine Möglichkeit, die Löschung ihrer Daten zu beantragen?** | **Ja** | Vollständige In-App-Account-Löschung unter *Profil → Account löschen* vorhanden. |
| **Link zur Datenlöschung (URL)** | `https://legal.brenzel.uk` | URL der Datenschutzerklärung mit Kontakt- und Löschhinweisen. |

---

## 2. Erhobene Datenarten im Detail

### A. Personenbezogene Informationen (Personal Info)

1. **Name / Nutzername (Name)**
   - *Erhoben:* **Ja**
   - *Geteilt mit Dritten:* **Nein**
   - *Verarbeitung:* Flüchtig? **Nein** (wird gespeichert)
   - *Erforderlich:* **Ja** (für Profil und soziale Interaktion mit Freunden)
   - *Zweck:* **App-Funktionalität** (App functionality), **Konto-Verwaltung** (Account management)

2. **E-Mail-Adresse (Email address)**
   - *Erhoben:* **Ja**
   - *Geteilt mit Dritten:* **Nein**
   - *Verarbeitung:* Flüchtig? **Nein**
   - *Erforderlich:* **Ja** (für Registrierung, Login & Passwort-Reset)
   - *Zweck:* **Konto-Verwaltung** (Account management), **App-Funktionalität**

3. **Nutzer-IDs (User IDs)**
   - *Erhoben:* **Ja** (interne Supabase UUID)
   - *Geteilt mit Dritten:* **Nein**
   - *Zweck:* **App-Funktionalität**, **Konto-Verwaltung**

---

### B. Fotos und Videos, Audio, Dateien
- *Erhoben:* **Nein** (Aura Quest nutzt Avatar-Emojis, keine Kamera-/Dateiuploads)

---

### C. App-Aktivitäten (App Activity)

1. **App-Interaktionen (App interactions)**
   - *Erhoben:* **Ja** (Gewohnheits-Check-ins, Quests, Duelle, Shop-Käufe)
   - *Geteilt mit Dritten:* **Nein**
   - *Erforderlich:* **Ja**
   - *Zweck:* **App-Funktionalität** (Spiellogik, Fortschritt, Ranglisten unter befreundeten Nutzern)

---

### D. Geräte- oder andere IDs (Device or other IDs)

1. **Geräte-ID oder andere Kennungen (Push-Notification-Token)**
   - *Erhoben:* **Ja** (FCM- oder UnifiedPush-Token für Benachrichtigungen)
   - *Geteilt mit Dritten:* **Nein**
   - *Zweck:* **App-Funktionalität** (Zustellung von Erinnerungen, Duell-Einladungen, Nudges)

---

### E. Finanzdaten, Standort, Kontakte, Web-Browsing
- *Erhoben:* **Nein** (Keine Finanzdaten, kein GPS-Tracking, kein Zugriff auf Telefon-Kontakte)

---

## 3. Zusammenfassung für den Play Store Reviewer

- **Keine Weitergabe an Dritte:** Keine Daten werden an Werbenetzwerke, Data Broker oder Analysedienste weitergegeben.
- **Keine In-App-Werbung:** Keine Werbe-SDKs eingebunden.
- **Minimalprinzip:** Nur Daten, die für die Kernfunktionalität (Mehrspieler-Habit-Tracker) nötig sind.
- **Account-Löschung konform:** Nutzer können ihren Account inklusive aller Daten jederzeit in der App löschen.
