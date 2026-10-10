# Aura Quest: erster Test mit TestFlight

Stand: 10. Oktober 2026. Kandidat: **1.0.2 (9)**. Apple hat den Build verarbeitet, aber die Testfreigabe wartet noch auf die Export-Compliance-Angabe. Dieser Plan beschreibt noch offene Gerätetests; er ist kein Nachweis, dass sie bestanden wurden.

## Installieren

1. Apples TestFlight-App auf dem iPhone installieren. Die folgenden Schritte sind erst nach der bestätigten Build-Freigabe möglich.
2. Die Einladung an das freigegebene Apple-Konto öffnen und annehmen. Falls TestFlight eine Anmeldung verlangt, das eingeladene Apple-Konto verwenden.
3. Aura Quest installieren. In TestFlight muss Version **1.0.2 (9)** angezeigt werden.

Die Gruppe **Aura Quest iOS intern** ist ein interner Test. Eine öffentliche Veröffentlichung im App Store ist dafür nicht erforderlich. Neue Builds werden dieser Gruppe derzeit manuell zugeordnet.

## Mit zwei Testkonten prüfen

iOS und Android verwenden denselben Backend-Dienst unter `https://api.brenzel.uk`. Für gegenseitige Einladungen und Push zwei unterschiedliche Testkonten verwenden. Die Anmeldung mit demselben Konto auf beiden Geräten ist zusätzlich ein eigener Synchronisationstest.

| Prüfung | Schritte | Erwartetes Ergebnis | Status |
| --- | --- | --- | --- |
| E-Mail-Anmeldung | Mit einem vorhandenen Testkonto anmelden, App schließen und wieder öffnen. | Profil und Quests laden; die Sitzung bleibt erhalten. | Offen |
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
| Darstellung | Alle drei Themes in Hell/Dunkel öffnen; große iOS-Schrift, Hoch-/Querformat und ein iPad prüfen. | Keine abgeschnittenen Bedienelemente, lesbarer Text und keine auffälligen Ruckler. | Offen |

## Noch gesperrte Abnahme

**Apple-Konto löschen:** Die lokale Kontolöschung ist vorhanden, aber Apples Token-Widerruf fehlt noch. Dieser Punkt bleibt ein Hindernis für die öffentliche Einreichung. Eine erfolgreiche lokale Löschung allein würde diese Anforderung nicht erfüllen. Einen vollständigen Löschtest erst nach der Korrektur mit einem ausdrücklich dafür vorgesehenen, entbehrlichen Testkonto durchführen.

## Fehler festhalten

Für einen Fehler reichen zunächst: Gerät/iOS-Version, App-Build, verwendeter Anmeldeweg, konkrete Schritte und ein Screenshot oder TestFlight-Feedback. Keine Passwörter, Bestätigungscodes oder Apple-Schlüssel mitsenden.

Die einzelnen Status erst nach einem tatsächlichen Gerätetest auf „Bestanden“ oder „Fehlgeschlagen“ ändern. Den allgemeinen Einreichungsstand enthält `docs/2026-10-09-apple-launch-readiness.md`.
