---
target: Aura Quest app UI and UX
total_score: 25
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 1
method: native design review
skill_version: 4.7.0
target_identity: "file:D:\\vibe projects\\Aura 100\\lib\\features\\home\\presentation\\screens\\home_screen.dart"
target_fingerprint: "sha256:57d179619c66416f95e64ed6eedc41c3234d29df32dd5374a877a1e986f2aada"
target_path: "D:\\vibe projects\\Aura 100\\lib\\features\\home\\presentation\\screens\\home_screen.dart"
timestamp: 2026-10-22T20-53-17Z
slug: ome-presentation-screens-home-screen-dart-ba4a8f7d
---
Method: design review only (detector not applicable, native platform)

# Aura Quest – UI/UX-Prüfung mit Impeccable 4.7.0

Stand: 22. Oktober 2026. Modus: Operate. Bestehende Identität und alle drei
Themes sind die Grundlage, kein Redesign-Auftrag. App-Code unverändert.

## Grundlage und Grenzen

- Aktueller Flutter-Quellcode: Auth, Dashboard, Home/Activity, Quests,
  Quest-Erstellung, Perks, Friends und Profile sowie Theme-/Motion-Komponenten.
- Ein aktueller, lesend erfasster Android-Screenshot des Editorial-Logins:
  `build/ui-review/impeccable-2026-10-22-emulator-5554.png`. Dieser Emulator hat
  noch 1.0.2 (17); die bewertete Login-Struktur ist im aktuellen Quellcode
  weiterhin vorhanden. Der andere Emulator zeigt ChurchFlow und blieb unberührt.
- Bestehende mobile/weite Light-/Dark-Goldens und ältere Store-Screens wurden
  visuell verglichen. Die Goldens sind Komponenten-/Beispielansichten, keine
  vollständigen Durchläufe der echten Screens. Alte Store-Bilder sind ergänzende
  historische Evidenz und allein kein Beweis für den heutigen Zustand.
- Kein neuer iPhone-/iPad-Livetest, kein vollständiger Account-/Quest-Durchlauf,
  kein VoiceOver-/TalkBack-Test und keine Framezeit-/Hardwaremessung.
- Der Web-Detektor prüft kein Dart. Seine Ergebnisse sind hier nicht anwendbar;
  die aktuelle Skill-Version sieht für native Apps ausdrücklich Designprüfung
  ohne Detektor vor. Keine Browser-Overlays oder zusätzlichen Server gestartet.

## Urteil

Aura Quest hat eine erkennbare eigene Bildsprache und brauchbare Grundlagen
für den Alltag. Die größte Chance liegt in einer klareren Reihenfolge:
Anmelden, heutige Aufgabe erledigen, offene Einladung bearbeiten – Gestaltung,
Statistiken und Spielregeln unterstützen diese Schritte.

Die Neo-Brutalist-Identität soll bleiben. Editorial Growth darf expressiv sein,
braucht an häufig benutzten Stellen aber eine kompaktere Darstellung. Auralis
muss nicht gestalterisch angeglichen werden.

## Heuristische Bewertung

Vorläufige Experteneinschätzung, keine Nutzerstudie oder Release-Zertifizierung.

| Kriterium | Punkte / 4 | Hauptbeobachtung |
|---|---:|---|
| Systemstatus | 3 | Offline-/Sync-Hinweise und Activity-Lade-/Fehlerzustände vorhanden |
| Verständliche Sprache | 2 | Viele Spielbegriffe und Regeln müssen auf einmal verstanden werden |
| Kontrolle und Auswege | 2 | Formular ohne Entwurf; absichtliche, nicht schließbare Roast-Sperre |
| Konsistenz | 3 | Gemeinsame Tokens und Komponenten; Akzentfarben nicht überall lesbar verwendet |
| Fehlervermeidung | 3 | Validierung, Balance-Vorlagen und Bestätigungen vorhanden |
| Wiedererkennen | 2 | Einladungen/Activity außerhalb Home nicht durchgehend sichtbar |
| Effizienz | 3 | Schnellfortschritt und erhaltene Tab-Stacks; langer Erstellungsdialog |
| Hierarchie und Reduktion | 2 | Große Editorial-Cover vor häufigen Hauptaktionen |
| Fehlerbehebung | 3 | Retry und Offline-Sync; einzelne rohe Serverfehlermeldungen |
| Hilfe im Kontext | 2 | Balance-/XP-Erklärungen vorhanden, aber recht regelreicher Einstieg |
| **Gesamt** | **25 / 40** | **Gute Basis, merkliche Reibung in den Hauptabläufen** |

## Was funktioniert

1. Die drei Themes besitzen eine klare eigene Identität und eigene Light-/Dark-
   Paletten. Illustration und Serifentypografie geben Editorial Growth Charakter.
2. Home trennt offene, erledigte und kommende Aufgaben. Activity besitzt bereits
   Zahl, hervorgehobenen Zustand, Lade-/Fehlermeldungen und eine Live-Semantik.
3. Es gibt bereits viele Schutzmaßnahmen: Balance-Presets, getrennte Aura/XP,
   beschriftete Navigation, 48-dp-Standardbuttons, reduzierte Bewegung,
   begrenzte Entrance-Verzögerungen und lokal gebündelte, gecachte Bildflächen.
   Die Wochentagsfelder sind außen 48×48 mit Semantik; die innere 44er-Höhe
   allein ist kein Beleg für einen zu kleinen Touchbereich.

## Fünf priorisierte Verbesserungen

### 1. [P1] Aktionsbeschriftungen zuverlässig lesbar machen

**Beleg:** `lib/features/challenges/presentation/widgets/slip_widgets.dart:15`
liefert rohe Füllfarben (`neonYellow`, `neonGreen`); Zeilen 104–110 benutzen sie
als Vordergrund des `I SLIPPED`-Buttons. Mit den aktuellen Neo-Light-Tokens
ergeben sich auf `surface` 1,54:1 für Gelb und 2,20:1 für Grün. Das bleibt unter
4,5:1 für normalen Text. Eigene Berechnung aus den tatsächlichen Tokens:
`build/ui-review/impeccable-2026-10-22-contrast.json`.

**Wirkung:** Eine zentrale Aktion ist besonders bei hellem Licht schlecht
lesbar. Das ist ein Kontrastproblem, kein gewünschter brutalistischer Stil.

**Vorschlag:** Für Schrift und Icons `warningText`/`successText` verwenden,
Füllfarben für ihre bisherige Aufgabe erhalten. Die vorhandenen dunkleren Tokens
erreichen hier 5,09:1 und 4,98:1. Danach reale Zustandskombinationen in allen
sechs Theme-/Modus-Varianten prüfen. Befehl: `$impeccable harden`.

Quelle: [W3C – Mindestkontrast](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum).

### 2. [P2] Editorial: Hauptaktion vor wiederholter Markeninszenierung

**Beleg:** `lib/features/auth/presentation/screens/login_screen.dart:346`
zeigt erst das Editorial-Cover, danach nochmals `AURA\nQUEST` und einen Claim.
Google folgt erst bei Zeile 529, Apple auf iOS danach. Im aktuellen Android-
Screenshot liegt selbst der E-Mail-Button erst am unteren Bildschirmrand.
`lib/core/widgets/editorial_cover.dart:79` reserviert zusätzlich Bildhöhe.

**Wirkung:** Anmeldung und Wiederkehr benötigen unnötiges Scrollen. Die
Anmeldemöglichkeiten wirken weniger auffindbar, obwohl sie vorhanden sind.

**Vorschlag:** Nur im Editorial-Login eine kompakte Markenfläche statt zweier
aufeinanderfolgender Branding-Blöcke; Auth-Aktionen in den ersten sichtbaren
Bereich. Auf Home darf die Illustration bei wiederkehrender Nutzung kompakter
werden. Beide anderen Themes und alle Auth-Verfahren erhalten.
Befehl: `$impeccable distill` / `$impeccable layout`.

### 3. [P2] Die erste Quest mit weniger Entscheidungen erstellen

**Beleg:** `lib/features/challenges/presentation/widgets/create_challenge_sheet.dart:274`
enthält ein einziges langes Sheet: Name, Beschreibung, drei Zielarten, ggf.
Ziel/Einheit, vier Spielmodi, Freunde, Laufzeit, Frequenz, Wochentage und Balance.
Neun Einheiten-Chips werden bei Fortschrittszielen gleichzeitig angeboten.
`CREATE` steht innerhalb des Scrollinhalts bei Zeile 900. Eingaben leben in
lokalen Controllern; kein Entwurf oder Schutz vor unbeabsichtigtem Schließen.

**Wirkung:** Der erste Erfolg verlangt bereits Verständnis vieler Spielregeln.
Nach versehentlichem Wegwischen muss der Nutzer erneut eingeben.

**Vorschlag:** Kurzer Einstieg mit Name, Ziel und Rhythmus; vorhandenes Classic
als sichtbaren Standard nutzen. Modus, Freunde und eigene Regeln nachgeordnet
zeigen; Zusammenfassung und Erstellungsaktion erreichbar halten. Entwurf lokal
erhalten oder bei ungespeicherten Eingaben bewusstes Verwerfen anbieten. Alle
bestehenden Optionen bleiben zugänglich. Befehl: `$impeccable onboard` /
`$impeccable distill`.

### 4. [P2] Offene Einladungen aus jedem Tab erkennbar machen

**Beleg:** `lib/features/home/presentation/screens/home_screen.dart:186` platziert
Activity nach den Aufgaben; die Zahl wird bereits ab Zeile 269 ermittelt.
`lib/features/dashboard/presentation/screens/dashboard_shell.dart:36` zeigt die
vier Navigationseinträge ohne Zahl für offene Aktionen.

**Wirkung:** Eine offene Quest-Einladung fällt beim Aufenthalt in Quests,
Friends oder Profile nicht auf. Bei vielen Tagesaufgaben liegt sie auf Home
zusätzlich weit unten.

**Vorschlag:** Vorhandenen Zähler wiederverwenden: dezente Zahl am Home-Tab,
kompakter Hinweis oberhalb der Tagesliste nur bei konkretem Handlungsbedarf
und direkter Sprung zu Einladungen. Neue Anfragen und bloßen Ereignisverlauf
sprachlich unterscheiden. Kein zweiter widersprüchlicher Zähler.
Befehl: `$impeccable clarify` / `$impeccable layout`.

### 5. [P2] Tablet-Platz für die Aufgabe nutzen

**Beleg:** `lib/features/dashboard/presentation/screens/dashboard_shell.dart:25`
verwendet für jede Breite die untere Navigation. Home und Quests sind
durchgehend einspaltige Listen; eine übergreifende Maximalbreite oder
Layout-Umschaltung fehlt dort. Das Cover und einzelne Profilkomponenten sind
bereits adaptiv; daraus folgt noch kein adaptiver Gesamtscreen.

**Wirkung:** Auf großen Geräten werden Karten und Eingabeflächen unnötig breit;
zusätzlicher Platz hilft weder dem Überblick noch dem Wechsel zu Questdetails.

**Vorschlag:** Nach verfügbarer Fensterbreite umschalten: begrenzte Lesebreite,
auf breiten Ansichten passende seitliche Navigation und optional Questliste
neben Details. Die schmale Smartphone-Ansicht erhalten. Mit großer Schrift,
Querformat und schmalen Mehrfenster-Ansichten prüfen. Befehl: `$impeccable adapt`.

## Einstieg, Belastung und Emotion

Die Quest-Erstellung bündelt viele Entscheidungen; neun Einheitenvorschläge
sind ein konkreter Punkt für progressives Aufklappen. Vorlagen sind bereits
vorhanden und sollten früher Arbeit abnehmen. Es braucht keine neuen Währungen
oder weiteren Systeme. Bei Wiederkehr zählt die heutige Aufgabe stärker als
eine wiederholte Begrüßungsinszenierung. Nach Erfolg sollen bestehender Sound,
kurze Haptik und Fortschrittsanzeige diesen Abschluss tragen.

**Erstnutzer:** Auth-Aktionen im Editorial-Modus weit unten; viele Regeln vor
der ersten Quest. **Unterwegs mit einer Hand:** langer Scrollweg zum Erstellen
und erneute Eingabe nach unbeabsichtigtem Schließen. **Nutzer mit Sehschwäche:**
rohe helle Akzentfarben als Aktionsschrift; realer Screenreader-Durchlauf fehlt.

## Kleinere Beobachtungen und bewusste Produktfragen

- `targeted_roast_gate.dart:133` setzt `canPop: false`; der Schließen-Button ist
  bis zum Timerende deaktiviert (Zeile 226). Der Spruch kann zur App passen,
  erzwungene Wartezeit unterbricht aber die Absicht, eine Aufgabe zu erledigen.
  Das ist eine vorhandene bewusste Mechanik, kein versehentlicher technischer
  Fehler. Nur nach Produktentscheidung verändern.
- Perks bezeichnet bereits das Guthaben als `quest aura`; auch der Quest-Dialog
  erklärt permanente XP. Diese Erklärungen nicht nochmals erfinden. Kurze Hilfe
  direkt am Bedarf kann die langen Regeltexte ergänzen.
- Einige Fehlermeldungen geben noch `PostgrestException.message` direkt aus,
  beispielsweise `slip_widgets.dart:147` und im Perks-Sheet. Verständliche
  Handlungshinweise sind hilfreicher; technische Details gehören ins Logging.
- Keine gemessenen Ruckler behauptet: Performance auf Geräten wurde nicht
  profiliert. Die vorhandenen Caches, Lazy-Questliste und Reduce-Motion-Pfade
  sind sinnvolle Grundlagen und sollten erhalten bleiben.

## Fragen für das nächste Umsetzungspaket

1. Zuerst **Kontrast + leichterer Einstieg**, **Activity/Einladungen** oder
   **Tablet-Layout** verbessern?
2. Die vorhandene Roast-Sperre **beibehalten** oder den **Spruch ohne
   erzwungene Wartezeit** zeigen?

Erst nach dieser Entscheidung umsetzen. Diese Prüfung veröffentlicht nichts
und verändert weder NAS-Daten noch App-Verhalten oder Themes.
