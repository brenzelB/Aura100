# Aura Quest – Code Review vom 30.09.2026

Im ursprünglichen Review wurden vier konkrete Fehler gefunden: ein Fehler mit hoher Priorität und drei mit mittlerer Priorität. Die damalige Testsuite erkannte sie nicht.

**Nachtrag: Alle vier Befunde wurden für Version 1.0.1, Build 5 korrigiert.** Duell- und Trophäenaktionen halten ihren Controller bis zum Abschluss am Leben und verwerfen Antworten nach Kontowechseln. Ein Reset aktualisiert Aktivitätsraster, Trophäen und Wochenrückblick. Realtime lädt soziale Einladungen und Anfragen beim Wiederverbinden und Fortsetzen neu; bei ausgefallenem Socket gibt es einen sparsamen Vordergrund-Fallback. Die folgenden Befundbeschreibungen dokumentieren den Zustand vor der Korrektur.

Stand: aktueller Arbeitsbaum auf `main`, Basis-Commit `452797f`, einschließlich der vorhandenen uncommitteten Änderungen. Kein Vergleich mit einer bestimmten Pull Request.

## 1. [P1] Duell wird gesendet, aber der Client-Ablauf kann mit einer Exception abbrechen

Fundstelle: [dice_duel.dart:1232](<D:/vibe projects/Aura 100/lib/features/challenges/presentation/widgets/dice_duel.dart:1232>), zugehöriger Controller [challenge_providers.dart:108](<D:/vibe projects/Aura 100/lib/features/challenges/application/challenge_providers.dart:108>) und `create()` ab Zeile 135.

`startDuelFlow()` liest den `autoDispose`-Controller nur mit `ref.read`. Ein dauerhafter Listener existiert für diesen Ablauf nicht. Der einzige `ref.watch(duelControllerProvider)` liegt im separaten Dialog zum Beantworten eines Duells. Dauert die Serveranfrage länger als die Freigabe des unbenutzten Providers, ist der Controller bei ihrer Rückkehr bereits zerstört.

Der isolierte Test mit dem echten Riverpod-Controller reproduziert nach erfolgreicher Repository-Antwort `Bad state: Future already completed`. Ein Kontrolltest mit gehaltenem Listener beendet dieselbe Anfrage erfolgreich. Der Serveraufruf wird durch die Freigabe nicht abgebrochen: Das Duell und der hinterlegte Einsatz können bereits existieren, während Bestätigung und anschließende Aktualisierung im Client ausfallen. Die UI fängt diese Exception im Startablauf nicht ab.

Korrektur: Laufende Aktionen im Controller bis zum Ende mit `ref.keepAlive()` und `try/finally` halten, die Ladeanzeige im sendenden UI abonnieren und Kontowechsel während der Anfrage berücksichtigen. Regressionstest: langsame erfolgreiche Anfrage sowie Serverfehler ohne geöffneten Antwortdialog.

## 2. [P2] Trophäe entfernen verwendet ebenfalls einen ungebundenen Controller

Fundstelle: [profile_screen.dart:928](<D:/vibe projects/Aura 100/lib/features/profile/presentation/screens/profile_screen.dart:928>), Controller [challenge_providers.dart:209](<D:/vibe projects/Aura 100/lib/features/challenges/application/challenge_providers.dart:209>).

Nach dem Bestätigen liest `_remove()` den `trophyControllerProvider` nur einmal. Dieser ist `autoDispose`; kein Widget abonniert ihn. Nach einer langsamen erfolgreichen `hideTrophy()`-Antwort wirft `hide()` deshalb ebenfalls `Bad state: Future already completed`. Der isolierte Test bestätigt diesen Ablauf.

Dadurch kann der Server die Trophäe ausgeblendet haben, während sie in der aktuellen Ansicht stehen bleibt: Der Controller erreicht `ref.invalidate(trophiesProvider)` und die Erfolgsrückmeldung nicht mehr.

Korrektur: Auch diese Aktion bis zum Abschluss halten und die UI an ihren Ladezustand binden. Regressionstest: Entfernen mit verzögerter Antwort, anschließend prüfen, dass die Liste neu geladen wird.

## 3. [P2] Erfolgreicher Statistik-Reset lässt Aktivitätsraster und Trophäenwerte veraltet

Fundstelle: [profile_providers.dart:93](<D:/vibe projects/Aura 100/lib/features/profile/application/profile_providers.dart:93>).

`resetStats()` invalidiert nur Spielerstatistiken, Profil und Questliste. `activityByDayProvider` und `trophiesProvider` hängen von keinem dieser drei Provider ab; sie werden im geöffneten Profil weiterhin beobachtet. Der Server löscht Check-ins und setzt die Aura der Teilnehmer auf null, aber diese beiden Ansichten behalten ihre vorherigen Daten. Auch der zwischengespeicherte Wochenrückblick wird nicht invalidiert.

Der isolierte Test hält die tatsächlichen Provider wie ein geöffnetes Profil am Leben. Nach erfolgreichem Reset bleiben ein Aktivitätstag und 100 Aura in einer Trophäe sichtbar. Die Repository-Methoden werden nicht erneut aufgerufen. Erst die explizite Invalidierung lädt den simulierten neuen Serverstand mit null Check-ins und null Aura.

Korrektur: Alle vom Reset betroffenen Abfragen gemeinsam aktualisieren, insbesondere Aktivitätsraster, Trophäen und Wochenrückblick. Zusätzlich fehlt die Aktualisierung des Aktivitätsrasters bei erfolgreichen Check-ins und Fortschrittsänderungen; die entsprechenden Refresh-Methoden enthalten ebenfalls keine Invalidierung dieses Providers.

Die Reset-Migration entfernt `check_ins`, aber keine `progress_entries`. Deshalb ist eine vollständig leere Aktivitätshistorie für Nutzer mit Fortschrittsquests derzeit auch nach erneutem Laden nicht zugesichert. Ob der Reset diese Einträge löschen soll, muss anhand der gewünschten Produktregel entschieden werden; das ist kein zusätzlich als sicher bestätigter Fehler dieses Reviews.

## 4. [P2] Verpasste Einladungen und Freundschaftsanfragen werden beim Wiederverbinden nicht nachgeladen

Fundstelle: [realtime_sync.dart:164](<D:/vibe projects/Aura 100/lib/core/realtime/realtime_sync.dart:164>).

Bei einer erfolgreichen Realtime-Verbindung ruft die App `_refreshEverything()` auf, um verpasste Änderungen nachzuholen. Dabei fehlen `myInvitesProvider`, `friendRequestsProvider` und `myFriendsProvider`. Diese werden ausschließlich durch passende Live-Ereignisse, Auth-Ereignisse, eigene Aktionen oder manuelles Aktualisieren neu geladen. Der 45-Sekunden-Fallback und das Nachladen beim Fortsetzen der App betreffen nur Roasts und Pokes.

Reproduktionsablauf aus dem Code: Home/Friends laden, kurz die Verbindung verlieren, in dieser Zeit auf einem zweiten Konto eine Einladung bzw. Anfrage senden, dann mit weiterhin gültiger Anmeldung wieder verbinden. Das während der Unterbrechung verpasste Ereignis wird nicht nachgespielt. Die bereits gehaltenen Listen und ihre Aktivitätszähler bleiben veraltet. Ein Wechsel zwischen Tabs hilft nicht zuverlässig, da die Navigation die Tabs in einem `IndexedStack` erhält. Auch das Öffnen des Friends-Tabs über eine Push-Nachricht invalidiert diese Listen nicht.

Korrektur: Die drei sozialen Abfragen in die Wiederverbindungs-Aktualisierung aufnehmen; Fortsetzen der App und einen Ausfall von Realtime ebenfalls abdecken. Sinnvoller Integrationstest: Einladung während unterbrochener Verbindung senden und nach Wiederherstellung ohne manuelles Aktualisieren anzeigen.

Nachweis für diesen Befund: Quellcodeprüfung der Realtime-Abonnements, Provider-Abhängigkeiten, Navigation, Push-Navigation und Fallbacks. Kein neuer Test gegen den echten NAS-WebSocket in diesem Review.

## Optimierung mit erkennbarem Nutzen für den NAS

[fetchCheckInsForChallenges():143](<D:/vibe projects/Aura 100/lib/features/challenges/data/challenge_repository.dart:143>) lädt für das Home-Dashboard die gesamte Check-in-Historie aller aktuell gehaltenen Quests. Die Pagination verhindert abgeschnittene Ergebnisse, begrenzt aber nicht die Gesamtarbeit. Lange laufende Quests verursachen bei jeder erneuten Dashboard-Abfrage immer mehr Datenbankzugriffe, übertragene Daten und Dart-Objekte.

Home benötigt für die Tages-/Periodenübersicht nur ein begrenztes Zeitfenster. Dieses serverseitig filtern; die vollständige Historie separat und bei Bedarf für die Detailansicht laden. Das ist eine belegte Optimierungsmöglichkeit, keine in diesem Review gemessene Überlastung oder Kapazitätsgrenze.

## Sicherheit und Prüfumfang

Verwendet wurde der lokale Skill `ecc:flutter-dart-code-review`. Das verfügbare Code-Review-Plugin stellt hier eine Abfrage von CI-Ergebnissen einer bestimmten Pull Request bereit; ohne vorgegebene Pull Request wurde lokal geprüft.

Schwerpunkte waren Authentifizierung und Kontowechsel, asynchrone Riverpod-Aktionen, Offline-Check-ins, Push-Autorisierung, Realtime, Reset, Quest-/Fortschrittsdaten und die sicherheitsrelevanten Datenbankmigrationen sowie der FCM-Sender. Die vorhandenen Theme-, Responsive- und Accessibility-Tests wurden mit ausgeführt.

In den geprüften Pfaden wurde keine zusätzliche konkrete Sicherheitslücke nachgewiesen. Positiv sind die serverseitige Autorisierung von Push-Texten, die nach Nutzer und Backend getrennte Offline-Warteschlange, eingeschränkte Schreibrechte auf Spieltabellen und die vertrauenswürdige Hostliste für UnifiedPush. Der öffentliche Supabase-Anon-Key im Client ist kein privater Server-Schlüssel.

Dies ist keine vollständige Sicherheitsfreigabe: Die tatsächlichen Berechtigungen und Migrationen des laufenden NAS, dessen Netzwerkregeln, Store-Signierung und Zustellung auf einem echten Telefon wurden in diesem Durchlauf nicht erneut geprüft. Es wurde kein Docker auf dem PC gestartet und keine NAS-Datenbank verändert.

## Verifikation des ursprünglichen Reviews

- `flutter analyze --no-pub`: keine Probleme.
- `flutter test --no-pub --reporter expanded`: 354 Tests bestanden.
- Vier zusätzliche isolierte Review-Diagnosen: Reset-Cache, ungebundener Duell-Controller, Kontrollablauf mit gehaltenem Listener und ungebundener Trophäen-Controller. Alle vier bestätigen die oben beschriebenen Ergebnisse.
- Die ursprüngliche Diagnose-Datei wurde nach der Korrektur in `build/code-review/repro_test.dart.txt` archiviert. Sie dokumentiert die damaligen Fehler und gehört nicht zur regulären Testsuite.

## Regressionstests der Korrektur

Aktueller Stand: `flutter analyze --no-pub` ohne Probleme; die vollständige Suite besteht mit **372 Tests**, einschließlich **18 neuer Regressionstests**.

Die permanente Datei [test/review_regressions_test.dart](<D:/vibe projects/Aura 100/test/review_regressions_test.dart>) prüft das gewünschte Verhalten: erfolgreiche und abgewiesene verzögerte Aktionen, verschwundene Widget-Listener, Kontowechsel, doppelte Duell-Taps, erfolgreiche und abgelehnte Resets sowie Nachladen sozialer Daten beim Wiederverbinden und Fortsetzen.

```powershell
flutter test --no-pub test/review_regressions_test.dart --reporter expanded
```

Die Optimierung der Dashboard-Historienabfrage und die Produktentscheidung zum Löschen alter Fortschrittseinträge bleiben außerhalb dieser vier Fehlerkorrekturen. Es war keine neue Datenbankmigration erforderlich.
