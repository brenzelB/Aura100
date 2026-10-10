# Aura Quest — Store Launch Master-Checkliste

Dieser Leitfaden führt dich Schritt für Schritt durch die Veröffentlichung von **Aura Quest** im **Google Play Store** und **Apple App Store**.

---

## 1. Übersicht der vorbereiteten Store-Artefakte

Vorbereitete Dateien und Entwürfe liegen im Ordner `deploy/store/`. Den aktuellen, noch nicht einreichbaren Apple-Stand beschreibt [der Fortschrittsbericht vom 10. Oktober](../../docs/2026-10-10-apple-launch-completion.md). Die [nächsten Schritte](../../docs/apple-launch-naechste-schritte.md) erklären die noch offenen Bestätigungen.

| Dateipfad | Zweck |
|---|---|
| [Signierter CI-Build 10](https://github.com/brenzelB/Aura100/actions/runs/38052895628) | Version 1.0.2 (10), Quellstand `f8590f6`: signierte Android-AAB und iOS-IPA, alle Release-Prüfungen bestanden. Beide heruntergeladen, noch nicht hochgeladen. Das alte September-AAB nicht verwenden. |
| [`deploy/store/assets/icon_512.png`](assets/icon_512.png) | **Google Play App Icon** (512 × 512 px, 32-bit PNG) |
| [`deploy/store/assets/feature_graphic_1024x500_v2.png`](assets/feature_graphic_1024x500_v2.png) | **Google Play Feature Graphic** (1024 × 500 px Banner, neues Aura-Quest-Design) |
| [`deploy/store/assets/screenshots/`](assets/screenshots/) | **Reale Screenshots** aus dem Android-Emulator (Dashboard, Quests, Quest-Editor und Perks) |
| [`deploy/store/STORE_LISTING_DE.md`](STORE_LISTING_DE.md) | App-Titel, Untertitel, Kurzbeschreibung & Langtext (Deutsch) |
| [`deploy/store/STORE_LISTING_EN.md`](STORE_LISTING_EN.md) | App-Titel, Subtitle, Short Description & Full Text (Englisch) |
| [`deploy/store/DATA_SAFETY_GOOGLE.md`](DATA_SAFETY_GOOGLE.md) | Entwurf für das **Google Play Datensicherheitsformular**, vor Einreichen gegen finale Dienste prüfen |
| [`deploy/store/APP_PRIVACY_APPLE.md`](APP_PRIVACY_APPLE.md) | Geprüfter Datenfluss-Entwurf für **App Store Connect App-Datenschutz**, finalen SDK-Bericht abgleichen |
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
- **App-Zugriff:** Anmeldung ist erforderlich. Ein tatsächlich funktionierendes Review-Konto mit passenden Zugangsdaten bereitstellen; die bisherigen Platzhalter sind kein gültiger Zugang.
- **Werbung:** *Nein, meine App enthält keine Werbung*.
- **Zielgruppe & Inhalte:** 13+ bzw. 16+ Jahre auswählen.
- **Finanz-Apps / Behörden-Apps / COVID-19:** Jeweils *Nein*.
- **Datensicherheit:** [`DATA_SAFETY_GOOGLE.md`](DATA_SAFETY_GOOGLE.md) ist als unvollständiger historischer Entwurf markiert. Vor einem neuen Android-Upload die tatsächlichen App-/Provider-Datenflüsse gegen Googles Formular prüfen; die alten Antworten nicht unverändert übernehmen.

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
3. Aktueller signierter Kandidat: Versionsname `1.0.2`, Versionscode `10`. Vor dem Upload in Play Console den belegten Versionscode prüfen. Für später geänderte App-Binaries eine höhere freie gemeinsame Build-Nummer verwenden.
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

- Der native Apple Provider ist auf dem NAS für `com.auraquest.auraQuest` aktiviert. Für den nativen ID-Token-Austausch ist keine Browser-Service-ID nötig. Apple-Token-Widerruf bei Kontolöschung ist implementiert und isoliert geprüft; der dedizierte Schlüssel und die Aktivierung auf dem aktiven NAS warten noch auf Bestätigung. Ein erfolgreicher Login-Build bestätigt diesen Lebenszyklus nicht.
- Die Firebase-iOS-App, das genehmigte GitHub-Plist-Secret und der produktive APNs-Key sind eingerichtet. Noch offen: echter Push-Test auf dem iPhone. Schlüssel und Plist nicht ins Repository committen.
- Moderationsmigration und öffentliche Community-Seite sind nach Sicherung/Regressionstests auf dem NAS bereitgestellt. Noch praktisch durchspielen: problematische Texte werden abgewiesen, normale Texte gespeichert, Meldungen vom Betreiber bearbeitet.
- Push, Anmeldung, Account-Löschung und Report/Block mit echten Testkonten auf einem iPhone durchspielen.

### Schritt 3.3: Signierter iOS-Build

Windows kann kein iOS-IPA erzeugen. Die GitHub-Action baut standardmäßig ein **unsigniertes** Archiv; `ios_signing=app-store` erstellt die signierte IPA. Zertifikat, Profil und die genehmigten Secrets sind eingerichtet und der signierte Export ist erfolgreich geprüft. Der gesonderte Apple-Upload von Build 9 wurde verarbeitet und intern freigegeben. `upload_testflight=true` reicht die App nicht zur Review ein. Details: [Build-Anleitung](README.md).

Die Version ist aktuell `1.0.2`, signierter Kandidat `10`. Dieser Build ist noch nicht zu Apple hochgeladen. Der tatsächlich freigegebene interne Test ist Build `9`. Für eine spätere neue App-Binary eine höhere freie gemeinsame Android-/iOS-Build-Nummer verwenden.

### Schritt 3.4: Listing und Prüfung

- Beschreibung und Keywords aus [`STORE_LISTING_DE.md`](STORE_LISTING_DE.md) übernehmen und im finalen Build verifizierte Aussagen verwenden.
- Datenschutz-URL: `https://legal.brenzel.uk/aura-quest/`. Community-Regeln und aktuelle Provider-Angaben sind veröffentlicht und per HTTPS geprüft.
- Datenschutzangaben mit [`APP_PRIVACY_APPLE.md`](APP_PRIVACY_APPLE.md) und dem endgültigen SDK-/Datenfluss abgleichen.
- Apple verlangt mindestens einen iPhone-Screenshot für ein iPhone mit Dynamic Island in mittlerer Displaygröße. Weil das Projekt iPad unterstützt, wird zusätzlich ein iPad-13-Zoll-Screenshot benötigt. Die vorhandenen Store-Bilder stammen nur von Android und sind dafür kein Ersatz.
- Den vorbereiteten [Alters- und Inhaltsrechte-Fragebogen](APPLE_AGE_AND_CONTENT_DECLARATIONS.md) bestätigen und Apples tatsächliche Einstufung prüfen. Würfelduelle mit virtuellen Aura-Einsätzen als simuliertes Glücksspiel angeben; die alte pauschale Angabe „4+“ nicht übernehmen.
- App Review Zugangsdaten für ein funktionierendes Demo-Konto bereitstellen und sicherstellen, dass Backend und Testzugang während der Prüfung erreichbar sind.
- Export-Compliance gemäß [technischem Entwurf](APPLE_EXPORT_TECHNICAL_DRAFT.md), App-Privacy, Supportkontakt, Lizenztexte und finale Datenschutzseite vor dem Einreichen abhaken. Kostenloser Preis, Copyright, deutsche/englische Texte und 175 Länder für den künftigen Start sind bereits als Entwurf gespeichert.

### Schritt 3.5: Einreichen

Nur nach erfolgreichem signiertem Upload, Verarbeitung in TestFlight und bestandener iPhone-/iPad-Prüfung den Build zur App-Review einreichen. Upload und Einreichung erfolgen nicht automatisch durch das Repository.
