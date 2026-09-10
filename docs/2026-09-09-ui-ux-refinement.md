# UI/UX Refinement – 9. September 2026

Die App verwendet jetzt ein gemeinsames Komponenten- und Typografiesystem. Die Neo-Brutalist-Variante orientiert sich an den beiden bereitgestellten Referenzen: warmer Papierhintergrund, klare Konturen, kräftige Typografie, Gelb als Hauptaktion sowie Türkis und Violett zur Orientierung. Dark Mode verwendet eigene dunkle Flächen und helle Konturen. Editorial und Auralis bleiben auswählbar.

## Umsetzung

| Bereich | Änderung |
| --- | --- |
| Designsystem | Gemeinsame Farben, Abstände, Formen, Eingaben, Buttons, Navigation und Feedback; 2-px-Konturen und überwiegend 6-px-Radien im Neo-Theme. Harte Schatten markieren wichtige Karten. |
| Typografie | Hanken Grotesk für Neo mit tatsächlichen Schriftgewichten; deutlichere Überschriften, 15–17 px Fließtext und mindestens 12 px bei zuvor sehr kleinen Beschriftungen. |
| Home | Direkter Einstieg zum Erstellen einer Quest, klarer Erststart, übersichtliche Tageskarte, kontrastreichere Überschriften und verständliche Lade-/Fehlerzustände mit Wiederholen. Die Aktivitätskarte hebt offene Ereignisse mit roter Kontur, aktiver Glocke und einem Zähler direkt am Kästchen hervor; Quest-Einladungen sind darin enthalten. |
| Questliste | Titel und Regeln erhalten die volle Kartenbreite. Guthaben, Check-in und Perks stehen darunter und können umbrechen. Leere Listen bieten einen direkten Einstieg. |
| Questdetails | Datum, Fortschritt, Regeln, Perks und Gruppeneinladung umbrechen bei Platzmangel. Ladefehler bieten Wiederholen. Die Verlassen-Bestätigung beschreibt die Aktion ohne Beschimpfung. |
| Erstellen | Dauerhafte Feldbeschriftungen, scrollbares Formular, größere Wochentagsauswahl mit vollständigen Screenreader-Namen, mindestens 48 px große Plus-/Minus-Steuerung. Chill, Classic, Chaos und erweiterte Werte bleiben erhalten. |
| Perks und Duelle | Lesbarer Kontostand, größere Kaufaktionen, gemeinsame Fensterform; Duell und Wiederholung sind scrollbar. Reduzierte Bewegung überspringt die Würfelinszenierung. |
| Freunde | Verständlicher Erststart mit Aktion, kompaktere leere Unterbereiche, konsistente Bestätigungen und ein scrollbarer Vergleich mit Freunden. |
| Profil | Anpassungsfähiges Statistikraster, vollständig lesbare/kopierbare Kontodaten, überarbeitete Designauswahl und eine scrollbare Avatar-Auswahl. Der Themewechsel erhält Widget-State, Eingaben und Scrollpositionen. |
| Anmeldung und Start | Sichtbarkeit des Passworts umschaltbar; eindeutige Felder und Tastaturaktionen. Mindestanzeige des Startbildschirms auf 350 ms reduziert. |
| Übergreifendes Feedback | Gemeinsame scrollbare Bestätigungsdialoge und kontrastreiche, per Live-Region angekündigte Snackbars. Technische Ladefehler werden nicht mehr als rohe Exceptions angezeigt. |
| Bedienung | Fokusrahmen und Enter/Leertaste für eigene klickbare Karten, größere Material-Touchflächen, kürzere gestaffelte Animationen. Modale Fenster liegen über der gesamten Navigation. |

Die Spielregeln, Backend-Verträge und bestehenden Korrekturen aus Paket 1/2, Check-in und XP-Reset bleiben erhalten. In dieser UI-Runde wurden keine Datenbankmigrationen ausgeführt und keine Docker-Dienste gestartet. Der NAS bleibt die Backend-Umgebung.

## Gefundene und korrigierte Probleme

- Horizontale Überläufe bei Datum, Fortschrittskopf, Party-Aktion, Shopguthaben und Regel-Chips auf 320 px mit großer Schrift.
- Leerer Freundes-Einladungsdialog bei vorhandenen Freunden: Die begrenzte Auswahlliste verwendet jetzt einen festen Viewport und kann vom Dialog sicher gemessen werden.
- Vertikale Überläufe im Statistikraster bei vergrößerter Schrift.
- Zu schmale Questtitel durch eine vorherige Aufteilung in drei Spalten.
- Verlorener Screen-State beim Themewechsel durch einen nach Theme neu erzeugten Teilbaum.
- Nicht scrollbarere Avatar-/Duell-/Vergleichsansichten bei geringer Höhe.
- Unter modalen Fenstern weiterhin bedienbare Tab-Navigation.
- Verschluckte Fehler und hängenbleibender Ladezustand bei einer Home-Poke-Aktion.
- Zu schwache Kontraste einzelner Überschriften und uneinheitliche Statusmeldungen.

## Prüfung

- `flutter analyze`: keine Befunde.
- `flutter test --reporter compact`: **156 Tests erfolgreich**.
- Darin **51 UI-Tests**: Anmeldung, leere/gefüllte Questliste, Avatar, Freunde, Profil, Questformular, Home, Details, Duellangebot, Shop, der sichtbare Aktivitätszähler mit Quest-Einladung und beide Einladungsdialogzustände in Neo Light/Dark auf **320 × 800** bei **100 % und 160 % Schriftgröße**; zusätzlich Kontraste, Tastaturbedienung/reduzierte Bewegung, Erhalt eines Eingabeentwurfs beim Themewechsel und ein langer Bestätigungsdialog bei Tastatur-Inset.
- Die beiden Reset-Tests prüfen weiterhin die Unterscheidung zwischen fehlender Berechtigung zum Reset und unerwartetem Datenbankfehler. Sie scrollen jetzt die gesamte Schaltfläche sichtbar und warten die Bewegung ab.
- `flutter build apk --debug`: erfolgreich. Finale APK auf **emulator-5554 und emulator-5556** installiert; Anmeldungen bleiben erhalten.
- Native Sicht-/Bedienprüfung: Home, gefüllte Questliste, Questdetails, Shop, Freunde/Freundesvergleich, Einladungsdialog, Profil/Themewechsel sowie Questformular mit Texteingabe, Wochentagen, Vorlagen und erweitertem Bereich. Light auf 5554, Dark auf 5556. Der Entwurf wurde nicht als Quest gespeichert; es wurden keine Einladungen verschickt oder Käufe ausgelöst.
- In den erfassten Logs beider finalen App-Prozesse keine Flutter-Fehlerzeilen, unbehandelten Exceptions oder RenderFlex-Überläufe.

Die Layouttests verwenden kontrollierte Zustände. Sie ersetzen keinen vollständigen manuellen Test aller Spielereignisse. Ein neuer Performance-Benchmark auf echten Geräten und ein vollständiger TalkBack-Durchlauf wurden in dieser Runde nicht durchgeführt. Die vorhandene Gradle-Warnung zur künftigen Kotlin-Plugin-Kompatibilität von `unifiedpush_android` und `webcrypto` verhindert den aktuellen Build nicht.

## Lokale Prüfarbeitsdateien

- Screenshots: `build/ui-review/` (Home Light/Dark, Quests, Details, Shop, Einladungsdialog, Erstellen und Balancebereich).
- Testlauf: `build/ui-all-tests.txt`.
- Analyse: `build/ui-analyze.txt`.
- Build: `build/ui-apk-build.txt`.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`.

Die Änderungen liegen im Arbeitsverzeichnis; in dieser Runde wurde kein Commit und kein Push erstellt.
