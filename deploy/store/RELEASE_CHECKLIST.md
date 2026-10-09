# Aura Quest — Store Launch Master-Checkliste

Dieser Leitfaden führt dich Schritt für Schritt durch die Veröffentlichung von **Aura Quest** im **Google Play Store** und **Apple App Store**.

---

## 1. Übersicht der vorbereiteten Store-Artefakte

Alle Dateien liegen einsatzbereit im Ordner `deploy/store/`:

| Dateipfad | Zweck |
|---|---|
| Aktueller CI-Build | Das vorhandene AAB wurde am 30.09.2026 gebaut und ist älter als die aktuellen Änderungen. Vor einem Test oder Upload muss ein neuer signierter Build aus dem finalen Commit erstellt werden. |
| [`deploy/store/assets/icon_512.png`](assets/icon_512.png) | **Google Play App Icon** (512 × 512 px, 32-bit PNG) |
| [`deploy/store/assets/feature_graphic_1024x500_v2.png`](assets/feature_graphic_1024x500_v2.png) | **Google Play Feature Graphic** (1024 × 500 px Banner, neues Aura-Quest-Design) |
| [`deploy/store/assets/screenshots/`](assets/screenshots/) | **Reale Screenshots** aus dem Android-Emulator (Dashboard, Quests, Quest-Editor und Perks) |
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
- **Datenschutzerklärung:** URL `https://legal.brenzel.uk/aura-quest/`
- **App-Zugriff:** *Alle Funktionen sind ohne besondere Einschränkungen verfügbar* (oder Test-Account `testuser@auraquest.local` / `Passwort` bereitstellen).
- **Werbung:** *Nein, meine App enthält keine Werbung*.
- **Zielgruppe & Inhalte:** 13+ bzw. 16+ Jahre auswählen.
- **Finanz-Apps / Behörden-Apps / COVID-19:** Jeweils *Nein*.
- **Datensicherheit:** Öffne [`deploy/store/DATA_SAFETY_GOOGLE.md`](DATA_SAFETY_GOOGLE.md) und übernimm die dort aufgelisteten Antworten (Name, E-Mail, App-Aktivität, Push-Token; keine Datenweitergabe an Dritte).

### Schritt 2.4: Store-Eintrag gestalten
Unter **Haupt-Store-Eintrag**:
- **Kurzbeschreibung & Vollständige Beschreibung:** Kopiere die Texte aus [`deploy/store/STORE_LISTING_DE.md`](STORE_LISTING_DE.md).
- **App-Symbol:** Lade [`deploy/store/assets/icon_512.png`](assets/icon_512.png) hoch.
- **Feature-Grafik:** Lade [`deploy/store/assets/feature_graphic_1024x500_v2.png`](assets/feature_graphic_1024x500_v2.png) hoch.
- **Screenshots für Smartphones:** Lade mindestens 4 der neuen Store-Screenshots hoch. Die fertige Auswahl liegt hier:
  - [`store_01_home_progress.png`](assets/screenshots/store_01_home_progress.png) — Startseite mit Tagesfortschritt und erledigten Quests
  - [`store_02_quests_overview.png`](assets/screenshots/store_02_quests_overview.png) — Quest-Übersicht mit Check-off, Fortschritt, Perks und neuem Quest
  - [`store_03_progress_detail.png`](assets/screenshots/store_03_progress_detail.png) — Fortschrittsziel mit Streak, Tagesziel und Gesamtstatistik
  - [`store_04_new_quest_modes.png`](assets/screenshots/store_04_new_quest_modes.png) — Quest-Editor mit Progress, Einheiten, Co-op und Freundeseinladung
  - [`store_05_perks.png`](assets/screenshots/store_05_perks.png) — Perks mit Aura-Heist, Aura-Ward und Targeted Roast

  Die Aufnahmen stammen aus einem echten 1280 × 2856 Android-Testemulator. Die unveränderten Rohaufnahmen liegen zu Prüfzwecken unter [`assets/screenshots/raw/`](assets/screenshots/raw/).

### Schritt 2.5: Release erstellen & Testen
> **Wichtig (Google-Regel seit Nov. 2023 für persönliche Konten):**
> Neue private Entwicklerkonten müssen vor der Freigabe für die Produktion einen **geschlossenen Test mit mindestens 12 Testern über 14 Tage** durchführen.
1. Gehe zu **Testen → Geschlossener Test**.
2. Erstelle nach erfolgreicher CI-Prüfung einen neuen Release und lade das signierte AAB des aktuellen Commits aus dem GitHub-Actions-Artefakt hoch. Das lokale AAB vom 30.09.2026 nicht verwenden.
3. Versionsname: `1.0.2`, Versionscode: `6` (nur verwenden, wenn 6 in der Play Console noch frei ist).
4. Release-Hinweise aus [`RELEASE_NOTES_1.0.2.md`](RELEASE_NOTES_1.0.2.md) einfügen.
5. Testerliste (E-Mails von Freunden / Familie) hinterlegen und Testlink teilen.
6. Nach Ablauf der 14 Tage geschlossenen Tests den Antrag auf Produktionszugriff stellen.

---

## 3. Apple App Store (iOS)

### Schritt 3.1: Konto und App-Eintrag

Du hast inzwischen ein Apple Developer Konto. Prüfe in [App Store Connect](https://appstoreconnect.apple.com), dass die Mitgliedschaft aktiv ist und Aura Quest als iOS-App angelegt ist. Für den Eintrag müssen diese Werte stimmen:

- Bundle-ID: `com.auraquest.auraQuest` (wie im Xcode-Projekt)
- Plattform: iOS; App Name und SKU nach dem bereits angelegten Eintrag
- App ID: **Sign in with Apple** und **Push Notifications** aktivieren
- Entwicklerkontakt und Support-URL eintragen

### Schritt 3.2: Backend und Anmeldung

- Apple Provider in Supabase aktivieren und die Service-ID/Schlüsselwerte im Supabase Auth-Dashboard konfigurieren. Apple-Anmeldung ist im iOS-Client eingebaut; ein erfolgreicher Build allein bestätigt den Provider noch nicht.
- Für iOS Push `GoogleService-Info.plist` zur Firebase-App mit Bundle-ID `com.auraquest.auraQuest` erzeugen, einen APNs-Auth-Key in Firebase hinterlegen und die Konfiguration sicher in den Build geben. Schlüssel und Plist nicht ins Repository committen.
- Die neue Moderationsmigration `20261009120000_app_store_moderation.sql` muss nach Backup und Regressionstest auf dem NAS angewendet werden. Danach Test durchführen: problematische Profil-/Quest-Texte werden abgewiesen, normale Texte gespeichert, Meldungen in der Moderationswarteschlange sichtbar.
- Push, Anmeldung, Account-Löschung und Report/Block mit echten Testkonten auf einem iPhone durchspielen.

### Schritt 3.3: Signierter iOS-Build

Windows kann kein iOS-IPA erzeugen. Die GitHub-Action baut derzeit nur ein **unsigniertes** Archiv. Für eine einreichbare IPA braucht der macOS-Runner eine Apple-Distribution-Signatur, ein App-Store-Provisioning-Profil und die Export-Optionen für das Team. Firebase-Konfiguration muss ebenfalls sicher eingebunden sein. Die bestehende Pipeline lädt nichts hoch.

Die Version ist aktuell `1.0.2`, Build `6`. Verwende Build 6 nur, wenn er in App Store Connect noch frei ist; andernfalls erhöhe die gemeinsame Android-/iOS-Build-Nummer. Version und Build-Nummer müssen zum App-Store-Connect-Datensatz passen.

### Schritt 3.4: Listing und Prüfung

- Beschreibung und Keywords aus [`STORE_LISTING_DE.md`](STORE_LISTING_DE.md) übernehmen und im finalen Build verifizierte Aussagen verwenden.
- Datenschutz-URL: `https://legal.brenzel.uk/aura-quest/`. Die lokale Website enthält jetzt Community-Regeln; sie muss nach dem Datenbank- und Build-Update veröffentlicht und live geprüft werden.
- Datenschutzangaben mit [`APP_PRIVACY_APPLE.md`](APP_PRIVACY_APPLE.md) und dem endgültigen SDK-/Datenfluss abgleichen.
- Apple verlangt mindestens einen iPhone-Screenshot für ein iPhone mit Dynamic Island in mittlerer Displaygröße. Weil das Projekt iPad unterstützt, wird zusätzlich ein iPad-13-Zoll-Screenshot benötigt. Die vorhandenen Store-Bilder stammen nur von Android und sind dafür kein Ersatz.
- Den aktuellen Altersfreigabe-Fragebogen selbst vollständig beantworten. Dabei Aura Heist, Zufallschancen und ausschließlich virtuelle Aura-Einsätze wahrheitsgemäß angeben; die alte pauschale Angabe „4+“ nicht übernehmen.
- App Review Zugangsdaten für ein funktionierendes Demo-Konto bereitstellen und sicherstellen, dass Backend und Testzugang während der Prüfung erreichbar sind.
- Export-Compliance, App-Privacy, Supportkontakt, Lizenztexte und finale Datenschutzseite vor dem Einreichen abhaken.

### Schritt 3.5: Einreichen

Nur nach erfolgreichem signiertem Upload, Verarbeitung in TestFlight und bestandener iPhone-/iPad-Prüfung den Build zur App-Review einreichen. Upload und Einreichung erfolgen nicht automatisch durch das Repository.
