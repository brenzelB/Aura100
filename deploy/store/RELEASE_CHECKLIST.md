# Aura Quest — Store Launch Master-Checkliste

Dieser Leitfaden führt dich Schritt für Schritt durch die Veröffentlichung von **Aura Quest** im **Google Play Store** und **Apple App Store**.

---

## 1. Übersicht der vorbereiteten Store-Artefakte

Alle Dateien liegen einsatzbereit im Ordner `deploy/store/`:

| Dateipfad | Zweck |
|---|---|
| [`build/app/outputs/bundle/release/app-release.aab`](../../build/app/outputs/bundle/release/app-release.aab) | **Signiertes Android App Bundle** (Release-Signatur aktiv) |
| [`deploy/store/assets/icon_512.png`](assets/icon_512.png) | **Google Play App Icon** (512 × 512 px, 32-bit PNG) |
| [`deploy/store/assets/feature_graphic_1024x500.png`](assets/feature_graphic_1024x500.png) | **Google Play Feature Graphic** (1024 × 500 px Banner) |
| [`deploy/store/assets/screenshots/`](assets/screenshots/) | **Reale Screenshots** aus der App (Dashboard, Duelle etc.) |
| [`deploy/store/STORE_LISTING_DE.md`](STORE_LISTING_DE.md) | App-Titel, Untertitel, Kurzbeschreibung & Langtext (Deutsch) |
| [`deploy/store/STORE_LISTING_EN.md`](STORE_LISTING_EN.md) | App-Titel, Subtitle, Short Description & Full Text (Englisch) |
| [`deploy/store/DATA_SAFETY_GOOGLE.md`](DATA_SAFETY_GOOGLE.md) | Exakte Antworten für das **Google Play Datensicherheitsformular** |
| [`deploy/store/APP_PRIVACY_APPLE.md`](APP_PRIVACY_APPLE.md) | Exakte Antworten für **App Store Connect App-Datenschutz** |
| [`.github/workflows/release.yml`](../../.github/workflows/release.yml) | GitHub Actions CI/CD-Pipeline für automatisierte iOS- und Android-Builds |

---

## 2. Google Play Store (Android)

### Schritt 2.1: Google Play Console Account
1. Registriere dein Entwicklerkonto unter [play.google.com/console](https://play.google.com/console) (einmalig **25 USD**).
2. Verifiziere deine Identität (Personalausweis / Reisepass bzw. D-U-N-S Nummer bei Firmen).

### Schritt 2.2: App anlegen
1. Klicke auf **App erstellen**.
2. **App-Name:** `Aura Quest: Gamified Habits`
3. **Standard-Sprache:** Deutsch (oder Englisch)
4. **App oder Spiel:** App
5. **Kostenlos oder kostenpflichtig:** Kostenlos

### Schritt 2.3: App-Inhalte & Richtlinien (Dashboard-Aufgaben)
Gehe im linken Menü auf **App-Inhalte** und fülle die Pflichtformulare aus:
- **Datenschutzerklärung:** URL `https://legal.brenzel.uk`
- **App-Zugriff:** *Alle Funktionen sind ohne besondere Einschränkungen verfügbar* (oder Test-Account `testuser@auraquest.local` / `Passwort` bereitstellen).
- **Werbung:** *Nein, meine App enthält keine Werbung*.
- **Zielgruppe & Inhalte:** 13+ bzw. 16+ Jahre auswählen.
- **Finanz-Apps / Behörden-Apps / COVID-19:** Jeweils *Nein*.
- **Datensicherheit:** Öffne [`deploy/store/DATA_SAFETY_GOOGLE.md`](DATA_SAFETY_GOOGLE.md) und übernimm die dort aufgelisteten Antworten (Name, E-Mail, App-Aktivität, Push-Token; keine Datenweitergabe an Dritte).

### Schritt 2.4: Store-Eintrag gestalten
Unter **Haupt-Store-Eintrag**:
- **Kurzbeschreibung & Vollständige Beschreibung:** Kopiere die Texte aus [`deploy/store/STORE_LISTING_DE.md`](STORE_LISTING_DE.md).
- **App-Symbol:** Lade [`deploy/store/assets/icon_512.png`](assets/icon_512.png) hoch.
- **Feature-Grafik:** Lade [`deploy/store/assets/feature_graphic_1024x500.png`](assets/feature_graphic_1024x500.png) hoch.
- **Screenshots für Smartphones:** Lade mindestens 4 Screenshots aus [`deploy/store/assets/screenshots/`](assets/screenshots/) hoch.

### Schritt 2.5: Release erstellen & Testen
> **Wichtig (Google-Regel seit Nov. 2023 für persönliche Konten):**
> Neue private Entwicklerkonten müssen vor der Freigabe für die Produktion einen **geschlossenen Test mit mindestens 12 Testern über 14 Tage** durchführen.
1. Gehe zu **Testen → Geschlossener Test**.
2. Erstelle einen neuen Release und ziehe die Datei:
   `build/app/outputs/bundle/release/app-release.aab`
   in das Upload-Feld.
3. Versionsname: `1.0.0 (1)`
4. Release-Hinweise aus `STORE_LISTING_DE.md` einfügen.
5. Testerliste (E-Mails von Freunden / Familie) hinterlegen und Testlink teilen.
6. Nach Ablauf der 14 Tage geschlossenen Tests den Antrag auf Produktionszugriff stellen.

---

## 3. Apple App Store (iOS)

### Schritt 3.1: Apple Developer Program Account
1. Registriere dich unter [developer.apple.com](https://developer.apple.com/programs/) (**99 USD / Jahr**).
2. Melde dich bei [App Store Connect](https://appstoreconnect.apple.com) an.

### Schritt 3.2: Identifiers & App-Eintrag in App Store Connect
1. **App ID anlegen:**
   - Identifier: `com.auraquest.auraQuest` (exakt wie in `ios/Runner.xcodeproj`).
   - Capabilities aktivieren: **Push Notifications**.
2. **In App Store Connect neue App anlegen:**
   - Plattform: iOS
   - Name: `Aura Quest`
   - Primäre Sprache: Deutsch
   - Bundle-ID: `com.auraquest.auraQuest`
   - SKU: `auraquest-ios-1`

### Schritt 3.3: iOS Build erstellen (Cloud CI/CD auf Windows)
Da du auf Windows arbeitest, nutzt du die fertige GitHub Actions Pipeline:
1. Hinterlege dein Repository auf GitHub (privat).
2. Pushe ein Git-Tag, z. B.:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. Alternativ: Klicke unter **GitHub → Actions → Release Builds → Run workflow**.
4. Der GitHub-Runner auf macOS kompiliert die App und generiert das signierte iOS-Archiv (`Runner.xcarchive` / `.ipa`).
5. Alternativ: Verbinde Codemagic oder Fastlane mit App Store Connect API Key für automatischen TestFlight-Upload.

### Schritt 3.4: Store-Listing & Datenschutz in App Store Connect
1. **App-Informationen:**
   - Untertitel: `Gewohnheiten, Duelle & Aura`
   - Kategorie: Produktivität
   - Datenschutzrichtlinie-URL: `https://legal.brenzel.uk`
2. **App-Datenschutz:**
   - Folge den Vorgaben aus [`deploy/store/APP_PRIVACY_APPLE.md`](APP_PRIVACY_APPLE.md).
   - Das erforderliche `PrivacyInfo.xcprivacy` ist bereits im Projekt eingebunden!
3. **App-Überprüfungsinformationen (App Review):**
   - Kontaktdaten angeben.
   - Demo-Konto angeben (E-Mail und Passwort eines Demo-Users in Supabase, z. B. `apple-review@auraquest.local`), damit der Apple-Prüfer alle Tabs, Quests und Duelle sofort testen kann.

### Schritt 3.5: Einreichen
1. Wähle den Build aus TestFlight aus.
2. Klicke auf **Zur Überprüfung einreichen**.
3. Die Apple-Prüfung dauert üblicherweise 24 bis 48 Stunden.
