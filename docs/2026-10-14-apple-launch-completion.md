# Apple-Start: erneute Prüfung am 14. Oktober 2026

Historischer Prüfstand. Der aktuelle Stand mit NAS-Aktivierung, Apple-Upload und
gespeicherten Store-Deklarationen steht im
[Checkpoint vom 16. Oktober](2026-10-16-apple-launch-completion.md).

Die App ist noch nicht zur App Review eingereicht und nicht öffentlich veröffentlicht.
Der signierte Kandidat bleibt **1.0.2 (11)** aus Release-Run
[38075183018](https://github.com/brenzelB/Aura100/actions/runs/38075183018), Quellstand `423dad4`.

## Heute erneut bestätigt

- Repository und GitHub hatten denselben Stand `985fe31`; nur der separate,
  nicht veröffentlichte Screenshot-Einstieg wurde danach angepasst (`9944a76`).
  `lib/`, App-Assets, iOS-Dateien und die Abhängigkeitsdateien sind gegenüber
  Build 11 unverändert. Ein neuer Release-Build ist dafür nicht erforderlich.
- IPA-SHA256: `ad07dccbd697fcfda5439edeea0e4086ee929f9a4ae5c4283ac7650fbc33cca5`.
  Android-AAB-SHA256: `38641ce748a333791a4a1d726c5f449dd39c26d0aa4d7e96271b37a20468fdbc`.
- Flutter-Analyzer: bestanden. Die elf Apple-Backend-Regressionstests: bestanden.
  Die 376 Flutter-Tests und vier erfolgreichen Release-Jobs stammen vom geprüften
  Build 11. Zusätzlich sind die automatisch gestarteten Codeprüfungen
  [38550562897](https://github.com/brenzelB/Aura100/actions/runs/38550562897)
  auf `9944a76` erfolgreich: Linux-Analyse/Tests und die unveränderten acht
  exakten Windows-Theme-Goldens. Das ist keine reale Geräteabnahme.
- Der aktive NAS-Migrationsstand enthält weiterhin genau die erwarteten zwölf
  Migrationen mit passenden Prüfsummen. Ein frisches Backup wurde geprüft:
  `/volume2/Datenbanken/AuraQuest/backups/apple-revocation-before-20261014103310.dump`.
  Alle acht SQL-Prüfsuiten bestehen im isolierten Restore. Die aktive Datenbank
  wurde dabei nicht verändert. Docker wurde ausschließlich auf dem NAS benutzt.
- Das vorhandene normale Review-Konto **auraquest-review@brenzel.uk** wurde intern
  und über die öffentliche HTTPS-App-API erfolgreich angemeldet. Drei Solo-
  Beispielquests sind vorhanden. Das Passwort bleibt lokal geschützt und wurde
  weder an Apple übertragen noch veröffentlicht.
- App Store Connect ist angemeldet. Der direkte alte Versionslink hing zunächst
  im Login; der normale Einstieg lud den vorhandenen Entwurf erfolgreich.
  Version 1.0.2 ist weiterhin „In Vorbereitung zur Übermittlung“, ohne gewählten
  Build oder hinterlegte Review-Kontaktdaten. App Privacy zeigt noch „Erste Schritte“.
- Die öffentliche Support-/Datenschutzseite ist im Browser erreichbar und zeigt
  weiterhin den veröffentlichten Stand vom 9. Oktober. Die aktualisierten
  Provider-/Widerrufsangaben liegen lokal; ihre Veröffentlichung ist noch offen.
- Im Apple-Team fehlt weiterhin der dedizierte Aura-Quest-Widerrufsschlüssel.
  Ein anderes Projekt hat einen eigenen Apple-Schlüssel; dieser wird nicht verwendet.

## Neu: Apple verlangt eine aktualisierte Vereinbarung

Apple zeigte die **Apple Developer Program License Agreement LYL260 vom
13. Oktober 2026** an. Nach ausdrücklicher Freigabe durch den Nutzer wurde sie
am **14. Oktober 2026** angenommen. Die Account-Seite bestätigt nach Neuladen
„Akzeptiert am 14. Oktober 2026“; der vorherige Annahmehinweis ist entfernt.
App Store Connect verlangt die Annahme für neue Einreichungen; die Account-Seite
nennt den **29. Oktober 2026** für den weiteren Zugriff auf Mitgliedschaftsressourcen.
Dieser Schritt ist abgeschlossen. Er bestätigt keine App Review oder Veröffentlichung.

## Screenshot-Nachprüfung

Das Aufnahmeprogramm setzte den Light-/Dark-Modus bislang nicht so ausdrücklich
wie `AuraQuestApp`. Es verwendet jetzt ebenfalls `darkTheme` und den gewählten
`themeMode`. Die Änderung betrifft ausschließlich `tool/store_preview.dart`.
Die erneute Aufnahme ist erfolgreich abgeschlossen unter
[38550563749](https://github.com/brenzelB/Aura100/actions/runs/38550563749).
Alle acht Bilder wurden angesehen; keine Rendering-Ausnahme steht im Protokoll.
Die neue iPhone-Dark-Aufnahme zeigt lesbare Statussymbole und wurde der bestehenden
geprüften Auswahl hinzugefügt. Die sieben bereits gespeicherten Bilder bleiben.
In Deutsch und Englisch sind jetzt jeweils vier iPhone- und vier iPad-Bilder
gespeichert; die Zähler wurden nach Neuladen bestätigt. Ein Simulatorbild beweist
keine reale iPhone-Abnahme. Herkunft und Prüfsummen stehen unter
`deploy/store/assets/screenshots/apple/`. Das Desktop-Paket enthält die acht
aktuellen Store-Bilder und separat alle acht Rohaufnahmen der Nachprüfung;
alle Kopien wurden per SHA256 bestätigt.

## Weiterhin erforderliche Antworten und Abnahme

1. Den ausschließlich für diese App vorgesehenen Sign-in-with-Apple-Schlüssel
   freigeben; danach Worker, Migration und Widerruf auf dem NAS aktivieren.
2. Die vorbereiteten Privacy-/Alters-/Inhaltsrechte-Angaben und ihre passende
   öffentliche Datenschutzerklärung bestätigen.
3. Das korrekte Review-Konto samt Passwort ausschließlich für Apples Review-
   Zugangsfelder und die vorhandenen Apple-Kontaktdaten freigeben.
4. Den ersten Vertrieb ohne Frankreich bestätigen oder den tatsächlichen
   französischen Verschlüsselungsnachweis beschaffen. Keine Erklärung wurde abgegeben.
5. Nach NAS-Aktivierung Build 11 zu Apple hochladen, dann Apple-Anmeldung,
   Widerruf bei Löschung, Push, Statusleiste und Android-/iOS-Zusammenspiel auf
   echten Geräten prüfen. Erst anschließend die vollständige Version einreichen.

Die früheren Ablehnungen der automatischen Freigabeprüfung für Schlüssel und
App Privacy wurden nicht umgangen. Ohne die noch ausstehenden Antworten wurden
keine neue Apple-Berechtigung, App-Privacy-/Alters-/Export-Erklärung, NAS-Aktivierung, Apple-Upload
oder öffentliche Veröffentlichung vorgenommen.
