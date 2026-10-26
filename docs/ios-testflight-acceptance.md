# Aura Quest: erster Test mit TestFlight

**Neuer Ersatzbuild:** 1.0.2 (14) mit nativer `ASWebAuthenticationSession` ist
erstellt, geprüft, zu Apple hochgeladen, verarbeitet und in der vorhandenen Gruppe
**Aura Quest iOS intern als „Im Test“ freigegeben**. Exportbestätigung ohne
Frankreich und Gruppenzuordnung sind nach erneuter Browser-Anmeldung abgeschlossen.
Der Nutzer bestätigt am 16. Oktober den erfolgreichen erneuten iPhone-Test:
„das hat wunderbar mit der google anmeldung funktioniert“. Die zuvor ausdrücklich
angefragte Anmeldung einschließlich automatischem Schließen ist damit für Build 14
bestanden. Build 13 bleibt dafür nicht abgenommen.

Stand: 16. Oktober 2026. Aktueller Testbuild: **1.0.2 (14)**. Build 14 ist in der bestehenden internen Testgruppe **Im Test**; die Google-Anmeldung samt automatischem Schließen ist auf dem iPhone vom Nutzer bestätigt. Zum Vorgänger Build 13 hat der Nutzer seine vorherige Antwort korrigiert: Die Google-Anmeldung funktioniert, das Browserfenster schließt sich jedoch **nicht automatisch**. Die Kontolöschung wurde als erfolgreich bestätigt. Die übrigen Prüfungen bleiben offen, soweit kein konkretes Ergebnis vorliegt.

**Erster Versuch mit Build 13:** Der echte Google-Login-Test mit Build 11 zeigte einen
offen bleibenden Safari-Controller. Der erste Korrekturversuch ist als Build 13
erstellt, hochgeladen, von Apple verarbeitet und intern freigegeben. Der Nutzer
korrigierte danach ausdrücklich: „die anmeldung funktioniert aber fenster schließt
sich nicht automatisch bei google anmeldung“. Der Schließfehler besteht weiter;
Build 13 darf dafür nicht als bestanden markiert werden.

Der neue Test-Kandidat **1.0.2 (14)** enthält zusätzlich zur korrigierten
Activity-Karte beim Theme-Wechsel den nativen Google-Web-Anmeldeablauf. Er wurde
erfolgreich signiert erstellt und nach Abschluss der Export Compliance ohne
Frankreich zum Testen freigegeben. Der Apple-Widerruf ist auf dem NAS aktiv.
Nach der bestätigten Google-Geräteabnahme wurde Build 14 für die Version gespeichert
und am 16. Oktober um 20:31 Uhr zur App Review übermittelt. Apple bestätigt
**Warten auf Prüfung**. Den Einreichungsnachweis dokumentiert der verlinkte
Checkpoint vom 16. Oktober.

## Installieren

1. Apples TestFlight-App auf dem iPhone installieren.
2. Die Einladung an das freigegebene Apple-Konto öffnen und annehmen. Falls TestFlight eine Anmeldung verlangt, das eingeladene Apple-Konto verwenden.
3. In TestFlight Aura Quest aktualisieren. Für die finale Abnahme muss
   TestFlight **1.0.2 (14)** anzeigen. Ältere Builds genügen dafür nicht.

Die Gruppe **Aura Quest iOS intern** ist ein interner Test. Eine öffentliche Veröffentlichung im App Store ist dafür nicht erforderlich. Neue Builds werden dieser Gruppe derzeit manuell zugeordnet. Build 14 ist zusätzlich zur App Review eingereicht; die öffentliche Veröffentlichung ohne Frankreich steht nach Apples Genehmigung noch aus.

## Mit zwei Testkonten prüfen

iOS und Android verwenden denselben Backend-Dienst unter `https://api.brenzel.uk`. Für gegenseitige Einladungen und Push zwei unterschiedliche Testkonten verwenden. Die Anmeldung mit demselben Konto auf beiden Geräten ist zusätzlich ein eigener Synchronisationstest.

| Prüfung | Schritte | Erwartetes Ergebnis | Status |
| --- | --- | --- | --- |
| E-Mail-Anmeldung | Mit einem vorhandenen Testkonto anmelden, App schließen und wieder öffnen. | Profil und Quests laden; die Sitzung bleibt erhalten. | Offen |
| Google-Anmeldung auf iOS | Mit Build 13 über Google anmelden. | Anmeldung funktioniert und das Safari-Fenster schließt sich automatisch. | Fehlgeschlagen: Anmeldung erfolgreich, Browser bleibt offen; ausdrückliche Nutzerkorrektur am 16. Oktober 2026 |
| Google-Anmeldung mit Ersatzbuild 14 | In TestFlight auf 1.0.2 (14) aktualisieren; gegebenenfalls in Aura Quest abmelden und über Google anmelden. | Die native iOS-Anmeldesitzung schließt beim Callback; Home erscheint ohne manuelles X. | Bestanden: Nutzer bestätigt am 16. Oktober nach der ausdrücklichen Testaufforderung für Build 14 „das hat wunderbar mit der google anmeldung funktioniert“ |
| Google-Wiederholung und Abbruch | Abmelden und erneut anmelden; einen weiteren Versuch abbrechen und später wiederholen. | Wiederholte Anmeldung funktioniert; ein Abbruch erzeugt keine neue Sitzung. | Offen: nicht gesondert bestätigt |
| Kontolöschung auf iOS | Ein entbehrliches Testkonto in der App löschen. | Die Kontolöschung wird erfolgreich abgeschlossen. | Bestanden aus Nutzersicht: „iphone test gemacht, konto löschen geklappt“ am 16. Oktober 2026; Anmeldeanbieter und serverseitige Detailprüfung nicht angegeben |
| Apple-Anmeldung | Mit einem eigenen Apple-Testkonto erstmals anmelden; abmelden und erneut anmelden. Auch Apples Option zum Verbergen der E-Mail prüfen. | Kein Anmeldefehler und kein zweites Profil bei erneuter Anmeldung. | Offen |
| Gemeinsame Quest | Android-Konto und iOS-Konto befreunden; eine Quest-Einladung verschicken und auf iOS annehmen. | Einladung ist sichtbar; beide Konten sehen dieselbe Quest. | Offen |
| Check-in | Eine fällige Einheit auf iOS abhaken und die Quest auf Android aktualisieren. | Genau ein Check-in; Aura, XP, Fortschritt und Aktivität passen auf beiden Geräten zusammen. | Offen |
| PERKS und Duelle | Einen verfügbaren Perk nutzen und einen zulässigen Duellablauf mit dem zweiten Konto prüfen. | Kosten und Wirkung erscheinen korrekt; kein doppelter Einsatz bei schnellem Tippen. | Offen |
| Push im Vordergrund | Auf iOS Benachrichtigungen erlauben; vom Android-Konto eine passende Einladung/Aktion auslösen. | Genau eine Benachrichtigung; kein doppelter Eintrag. | Offen |
| Push im Hintergrund | iOS-App verlassen, Bildschirm sperren und vom zweiten Konto eine neue Einladung/Aktion auslösen. | Eine sichtbare Nachricht erscheint. Antippen öffnet den passenden, erlaubten Bereich. | Offen |
| Push nach Konto-Wechsel | Auf iOS abmelden und mit dem anderen Testkonto anmelden; eine Nachricht an das vorherige Konto auslösen. | Keine privaten Daten des vorherigen Kontos im neuen Konto. | Offen |
| Push abgelehnt | Benachrichtigungen in iOS-Einstellungen deaktivieren und die App weiter nutzen. | Die App bleibt bedienbar; Aktivitäten sind weiterhin in der App sichtbar. | Offen |
| Melden und Blockieren | Einen testweise problematischen Inhalt melden und das zweite Testkonto blockieren. | Bestätigung erscheint; blockierte Interaktionen werden verhindert; die Meldung ist beim Betreiber vorhanden. | Offen |
| Netzunterbrechung | Kurz den Flugmodus einschalten, einen Check-in versuchen, Verbindung wiederherstellen. | Kein verlorener oder doppelter Check-in; der tatsächliche Status ist nachvollziehbar. | Offen |
| Darstellung | Alle drei Themes in Hell/Dunkel öffnen; große iOS-Schrift, Hoch-/Querformat und ein iPad prüfen. Bei heller iOS-Systemdarstellung auch in den App-Dark-Mode wechseln und die Statusleiste prüfen. | Keine abgeschnittenen Bedienelemente, lesbarer Text einschließlich Uhrzeit/Statussymbolen und keine auffälligen Ruckler. Die Nachaufnahme vom 14. Oktober hat lesbare Statussymbole; der frühere Fehler lag in der abweichenden Aufnahme-Konfiguration. Reale Geräteabnahme weiter offen. | Offen |

## Apple-Kontolöschung auf einem entbehrlichen Testkonto prüfen

Der Nutzer hat die erfolgreiche Kontolöschung auf dem iPhone bestätigt. Daraus
folgt noch kein gesonderter Nachweis für den Apple-Autorisierungswiderruf oder
die vollständige serverseitige Datenentfernung; der Anmeldeanbieter des gelöschten
Testkontos wurde nicht genannt.

**Apple-Konto löschen:** Der Widerruf ist implementiert und in isolierten Backend-
und Datenbanktests geprüft. Schlüssel, Worker und Migration sind seit 16. Oktober
auf dem aktiven NAS eingerichtet. Mit dem freigegebenen finalen Build und einem ausdrücklich entbehrlichen
Testkonto prüfen: neu anmelden, Konto löschen, vollständige Entfernung der Daten
und widerrufene Apple-Autorisierung kontrollieren. Ein Abbruch der Apple-Abfrage
oder ein Netzfehler muss das Konto erhalten. Für ältere Apple-Testkonten außerdem
die einmalige erneute Apple-Bestätigung testen; auf Android muss die App dafür
den verständlichen Hinweis auf eine vorherige iPhone-Anmeldung zeigen.

## Fehler festhalten

Für einen Fehler reichen zunächst: Gerät/iOS-Version, App-Build, verwendeter Anmeldeweg, konkrete Schritte und ein Screenshot oder TestFlight-Feedback. Keine Passwörter, Bestätigungscodes oder Apple-Schlüssel mitsenden.

Die einzelnen Status erst nach einem tatsächlichen Gerätetest auf „Bestanden“ oder „Fehlgeschlagen“ ändern. Den aktuellen Einreichungsstand enthält [der Checkpoint vom 16. Oktober](2026-10-16-apple-launch-completion.md).
