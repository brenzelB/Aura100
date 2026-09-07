# Aura Quest – Code-, Datenbank- und Emulatorprüfung

Stand: 07.09.2026. Ausgangspunkt: Commit
`00566cc61f5abd8833a96073eea37c52dfa7b973`. Der ältere Prüfbericht zum Commit
`7335781` diente als Vergleich; die dort aufgeführten Korrekturen wurden nicht
ungeprüft übernommen.

## Ergebnis und Bereitstellung

Mehrere Sicherheits- und Buchungsfehler wurden reproduziert und korrigiert.
Die Änderungen am Flutter-Code liegen im Arbeitsverzeichnis und sind auf
beiden Android-Emulatoren installiert. Neun Datenbankmigrationen wurden nach
Tests auf einer isolierten NAS-Kopie am NAS übernommen: acht gemeinsam atomar,
danach eine zusätzliche Berechtigungskorrektur in eigener Transaktion. Es wurde nichts
committet, gepusht oder in einen App Store veröffentlicht.

Die App organisiert Gewohnheiten als Check-in-, Fortschritts- und Avoid-Quests.
Flutter/Riverpod hält Darstellung und lokalen Zustand; Supabase Auth liefert die
Benutzeridentität. PostgREST liest unter RLS und ruft serverseitige Spielregeln
auf. PostgreSQL verwaltet Aura, Strikes, Duelle, Käufe und Abrechnungen; Cron
führt periodische Arbeit aus. Push wird über eine Outbox und pg_net zugestellt.
Offline-Check-ins sind lokale Absichten, deren Auszahlung erst der Server bestätigt.

Geprüfte Bereiche: Anmeldung und Konto-Lebenszyklus, Repository-Abfragen,
Offline-Synchronisierung und Caches, Quest-Zeiträume, Fortschritt und Strikes,
Abrechnung, Duelle, Push-Client und Zustellfunktionen, Migrationen, RLS/Grants,
NAS-Docker-Betrieb, Sicherung und Wiederherstellung sowie Android-Laufzeit.
Diese Prüfung ist keine Garantie, dass jede mögliche Fehlerkombination fehlt.

## Bestätigte und korrigierte Befunde

| Priorität | Befund | Korrektur / Nachweis |
|---|---|---|
| Kritisch | Auf dem NAS fehlte bereits die Sicherheitsmigration vom 04.09.; Clients hatten direkte Schreibrechte auf Quest-/Teilnehmerdaten. | Rechte und überbreite Policies entfernt; direkte Aura-/Quest-Updates sind jetzt verboten. Spaltenrechte für Angriffsbestätigungen begrenzt. |
| Hoch | Historische ALL-Grants enthielten TRUNCATE und TRIGGER für Client-Rollen. RLS verhinderte im isolierten SQL-Test kein TRUNCATE CASCADE. | Unnötige DDL-/Wartungsrechte und anonyme Tabellenrechte entfernt. Vier neue Regressionstests. Ein direkter TRUNCATE-Endpunkt der REST-API wurde nicht behauptet oder nachgewiesen. |
| Hoch | Der überarbeitete Check-in-RPC referenzierte nicht existierende Heist-/Streak-Spalten; normale Buchungen schlugen fehl. | Schema-kompatible Spielregeln einschließlich Heists, Multiplikatoren und Meilensteinen wiederhergestellt. |
| Hoch | Die neue Check-in-Typprüfung blockierte auch das interne Erreichen eines Fortschrittsziels. | Auszahlung nur bei tatsächlich erreichtem Ziel; 99→100 und Überschreiten getestet, keine doppelte Auszahlung. |
| Hoch | Coop-Abrechnung konnte dieselbe Periode wiederholt belasten. | Fortschreiben von `settled_until`, Schutz bei Wiederholung, verspätetem Beitritt und Schildbehandlung. |
| Hoch | Globales Settlement war im überarbeiteten Code wieder für Nutzer freigegeben; ein transaktionsweiter GUC-Schalter umging Trigger. | Globaler RPC intern, Trigger ohne solchen Bypass; legitime historische Avoid-Abrechnung gesondert validiert. |
| Hoch | Unterschiedliche Sperrreihenfolgen konnten gleichzeitige ökonomische Vorgänge gefährden. | Gemeinsame Transaktionssperre vor Zeilensperren; parallele Buchungen getestet. Skalierungsgrenze siehe unten. |
| Hoch | UnifiedPush-URL-Prüfung ließ u. a. Großschreibung/Integer-IP-Tricks zu und erlaubte bei fehlender Konfiguration zu viel. | Exakte HTTPS-Host-Allowlist, Standardport, strikte Syntax; NAS erlaubt `push.brenzel.uk`. Registrierung und Versand prüfen beide. |
| Hoch | Push-Reaper nutzte `net._http_response.url`, das nicht existiert. | Verknüpfung über Request-ID. NAS: 672 Fehler in sieben Tagen vor der Korrektur; erfolgreiche Cron-Läufe ab 21:30 Uhr MESZ. |
| Hoch | Wiederholungen konnten erfolgreiche Geräte erneut benachrichtigen; verlorene Antworten blieben hängen; generische FCM-404 löschten gültige Tokens. | Zustellstatus pro Gerät, begrenzte Wiederholungen mit Wartezeit, Timeout-Erholung, Löschung nur bei eindeutiger FCM-UNREGISTERED-Antwort; Besitzerwechsel geschützt. |
| Hoch | Lokale Queue/Caches konnten beim Konto- oder Backendwechsel vermischt werden. | Queue nach Backend und Nutzer getrennt; alte Einträge ohne Eigentümer werden nicht fremden Konten zugeordnet. Serielle Schreibzugriffe und erneute Kontoprüfung während Sync. |
| Hoch | Bereits im Push-Payload vorhandener Text konnte die serverseitige Kontoprüfung umgehen. | Beide Transporte senden ohne Nachrichtentext; Anzeige und Öffnen verlangen eine autorisierte Outbox-Abfrage. Alte Kontobenachrichtigungen werden entfernt. |
| Mittel | Wiederherstellung der Verbindung bzw. Rückkehr zur App löste nicht zuverlässig einen vollständigen Sync aus. | Dienst auf App-Ebene und Wiederaufnahme-Synchronisierung; echter Offline-Test am Emulator erfolgreich. |
| Mittel | Große Aktivitätslisten/Summen konnten an REST-Zeilenlimits abgeschnitten werden. | Paginierte Listen mit eindeutiger Sortierung; aktuelle Fortschritts-/Slip-Summen serverseitig. 1.205 Einträge getestet. |
| Mittel | Endlos-Quests wurden in Detailstatistik und Periodengrenzen wie endliche Quests behandelt. | Begrenztes Kalenderfenster bis heute, an Originalperioden ausgerichtet; aktuelles Wochenziel wird nicht auf bereits verstrichene Tage verkürzt. |
| Mittel | UTC-Kalendertage konnten in westlichen Zeitzonen einen Tag zu früh erscheinen. | Datumsanzeige ohne Umrechnung des Kalendertags; echte Uhrzeiten bleiben lokal. |
| Mittel | Erinnerungen um 23 Uhr bzw. nach Mitternacht hatten falsche Fälligkeitsgrenzen. | Letzten lokalen Fälligkeitstermin bestimmen; Spielperioden bleiben konsistent in UTC. Sommer-/Winter-Offsets getestet. |
| Mittel | Ablauf eines Duells erstattete den Einsatz und warf danach eine Exception, die die Erstattung zurückrollte. Spätere Blockierungen wurden bei Annahme nicht erneut geprüft. | Dauerhafte Ablaufantwort, einmalige Rückzahlung, erneute Prüfung von Blockierung, Herausforderer und Quest-Zustand. |
| Mittel | Statistik-Reset konnte laufende Wettbewerbe verändern. | Reset bei aktiven Mitgliedschaften oder offenen Duellen gesperrt. |
| Hoch | NAS-`.env` hatte Modus 777; Sicherungen waren nicht ausreichend auf den Besitzer begrenzt. | Projekt-/Backup-Verzeichnis 700, `.env` und Compose-Datei 600, Dumps 600 mit Besitzer denzel/admin. Backup-Routine nutzt umask 077 und setzt den Besitzer. |
| Mittel | Routineprüfungen liefen erst beim Release; der Release-Workflow akzeptierte fehlende Android-Signierschlüssel. | Checks für Push/PR ergänzt, Flutter-Version fixiert, Release-Secrets verpflichtend, Buildnummer als validierte Umgebungsvariable. GitHub-Ausführung selbst steht nach einem Push noch aus. |

Bereits vorhandene Korrekturen wurden zusätzlich abgesichert: kollidierende
lange Benutzernamen, erster Avoid-Slip bei Strike-Budget null, Schildschutz,
späte LMS-Einladungen und Kontolöschung mit archivierter Quest/Einsatzrückzahlung.

## Verifikation

| Prüfung | Ergebnis |
|---|---|
| `flutter analyze` | Keine Befunde |
| Flutter Unit-/Widget-Tests | 81 bestanden |
| PostgreSQL-Regressionsfälle | 68 bestanden, sowohl auf synthetischem Schema als auch nach Upgrade der NAS-Kopie |
| `plpgsql_check` | Keine Schemafehler in den geprüften PL/pgSQL-Anwendungsfunktionen ohne Trigger |
| Echte Parallelverbindungen | 12 gleichzeitige Check-ins: genau eine Auszahlung; 20 Fortschrittsbuchungen: Summe 20, genau eine Auszahlung, keine Deadlocks |
| Android-Debug-Build | Erfolgreich gebaut und auf emulator-5554 / emulator-5556 aktualisiert |
| Emulator 5554 | Vorhandene Sitzung geladen; WLAN/Mobilfunk abgeschaltet; Check-in als wartend angezeigt; Netzwerk wieder aktiviert und App wiederaufgenommen; NAS bestätigt genau einen Check-in und 500→600 Aura |
| Emulator 5556 | Vorhandene andere Sitzung geladen; Fortschritt über ADD / Rest (10) / LOG IT erfasst; Ziel erreicht, NAS bestätigt 10.00 Fortschritt, einen Check-in und 500→600 Aura |
| Trennung der Testkonten | Jeweils nur eigene Prüfquest auf Home sichtbar; Freunde-/Profilansicht erfolgreich geladen |
| Cleanup | Beide Prüfquests entfernt, Netzwerk wieder aktiv; Ursprungszahlen auf NAS wieder bestätigt |
| Sicherung | Tagesdump vom 07.09. isoliert mit Besitzern/ACLs fehlerfrei wiederhergestellt; frischer Dump mit geänderter Backup-Routine um 21:40 erstellt und Inhaltsverzeichnis mit 1.087 Einträgen geprüft |

Das SQL-Testsetup und die Befehle stehen in [scripts/README.md](../scripts/README.md).
Die Tests verwenden echtes pg_net, spielen dessen Antworten aber kontrolliert
ein. Das bestätigt die Zustellzustandsmaschine, nicht jede externe Push-Strecke.

## NAS-Zustand

PostgreSQL 17.6, anfangs etwa 29 MB Datenbankgröße. Drei Konten, fünf Quests,
zwei aktuelle Teilnehmerzeilen, sieben Check-ins, zusammen 200 Quest-Aura.
Diese Zahlen blieben durch die Migration unverändert und wurden nach den
temporären Emulator-Tests erneut erreicht. Keine fehlenden Auth-/Profilpaare,
keine negativen Quest-Aura-Stände, keine doppelten Mitgliedschaften/Check-ins,
keine überfälligen offenen Duelle oder lange offenstehenden Transaktionen
in den geprüften Abfragen.

Fünf ältere Check-ins haben keine aktuelle Teilnehmerzeile mehr. Das ist bei
einem Modell mit gelöschten Mitgliedschaften und erhaltener Historie möglich;
sie wurden nicht ohne fachliche Grundlage gelöscht. Ein nicht validierter
Constraint in `realtime.messages` gehört zur Supabase-Infrastruktur und wurde
nicht als nachgewiesener Fehler an den Spieldaten gewertet.

Die Aura-Dienste laufen, Dienste mit Healthchecks melden gesund. PostgreSQL
und Studio haben keine direkt veröffentlichten Docker-Hostports. Sechs
Spiel-/Push-Cronjobs sind aktiv. Der Reaper läuft nach der Migration alle fünf
Minuten erfolgreich. Andere Anwendungen auf dem NAS wurden nicht verändert.

Die ersten acht Migrationen wurden um 21:28 Uhr MESZ gemeinsam committed;
die ergänzende Rechtekorrektur folgte um 21:46 Uhr. Liste und Prüfsummen
stehen in `aura_admin.applied_migrations`; PostgREST wurde anschließend zum
Neuladen seines Schemas benachrichtigt.

Backup unmittelbar vor der Migration:
`/volume2/Datenbanken/AuraQuest/backups/audit-before-20260907192801.dump`.
Zusätzlich liegt der aktuelle verifizierte Dump
`auraquest-20260907-2140.dump` im selben Ordner. Die nächtliche Routine bleibt
bei 03:15 Uhr und 14 rotierenden Tageskopien. Der separate Audit-Dump wird
nicht von dieser Rotation erfasst. Datenverzeichnis `volumes/db/data` wurde
weder über SMB bearbeitet noch kopiert.

Vor der zusätzlichen Rechtekorrektur wurde außerdem
`audit-before-20260907194655.dump` angelegt. Die beiden temporären
NAS-Prüfquests wurden entfernt. Die lokale NAS-Kopie und der ungenutzte lokale
Audit-API-Container wurden nach der Prüfung entfernt; der synthetische
Testdatenbankcontainer wurde angehalten.

## Weitere Optimierung und Prüfgrenzen

1. **Skalierung der Abrechnung:** Die gemeinsame Schreibsperre priorisiert
   korrekte Salden in diesem kleinen NAS-Setup. Unter höherer Last sollte
   `settle_periods` in Abrechnung pro Quest zerlegt werden, damit unabhängige
   Quests parallel schreiben können. Vorher Lastmessungen mit realistischen
   Teilnehmerzahlen durchführen; die kleinen Testdaten belegen keine
   Produktionskapazität. Lange Historien sollten künftig inkrementell geladen
   werden, statt alle Seiten bei jeder Aktualisierung neu zu lesen.
2. **Push unter realen Betriebssystembedingungen:** FCM/UnifiedPush im
   Vordergrund, Hintergrund, bei beendetem Prozess und nach Kontowechsel mit
   echten Zustellungen noch gesondert testen. Die Allowlist setzt vertrauenswürdige
   Hosts, DNS und Redirect-Verhalten voraus; sie ersetzt keine Beschränkung
   ausgehender NAS-Verbindungen. Bei großer Outbox die Auswahl wartender Jobs
   verbessern, damit frühe verzögerte Einträge spätere nicht aufhalten.
3. **Zeitmodell:** Spieltage bleiben UTC. Erinnerungen verwenden gespeicherte
   UTC-Offsets; eine dauerhafte IANA-Zeitzone wäre für Sommerzeitwechsel und
   Reisen zuverlässiger. Die Endlos-Kalenderstatistik betrachtet höchstens
   das letzte Jahr; dieser Zeitraum sollte im UI explizit beschriftet werden.
4. **Plattformen/Release:** iOS/APNs, Signierung und App-Store-Build sind auf
   diesem Windows-System nicht praktisch verifiziert. Android meldet eine
   zukünftige Kotlin-Plugin-Inkompatibilität für `unifiedpush_android` und
   `webcrypto`; der aktuelle Build funktioniert. Paket-/Image-Updates und
   ein gesonderter Abgleich gegen aktuelle Sicherheitsmeldungen bleiben ein
   eigener Wartungsschritt. `latest`-Images auf dem NAS nicht blind aktualisiert.
5. **Datenaufbewahrung:** Retention für `cron.job_run_details` ergänzen und die
   gewünschte Historie nach Quest-Austritten/Statistik-Reset festlegen. Derzeit
   wurden historische Testeinträge erhalten; kein pauschales Datenbereinigen.

Die vorhandenen Zugänge zu Code, NAS über SSH und beiden Testemulatoren waren
für diese Arbeiten ausreichend. Für einen späteren iOS-/Store-Durchlauf werden
die entsprechende Apple-Buildumgebung und Signierung benötigt.
