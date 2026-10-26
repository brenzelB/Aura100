# Aura Quest — Store-Serie, Revision 2, 14. Oktober 2026

**Konzept: „Weniger morgen. Mehr machen.“**

Warme Pfirsich-, Creme-, Mint- und Violettflächen, große Serifenschrift,
abwechselnd oben und unten platzierte Nutzen-Botschaften, schräge schwarze
Geräte und echte Neo-Brutalist-App-Ansichten. Die zwei früheren Editorial-
Motive wurden durch Fortschritt und Check-ins ersetzt. Zusätzliche 3D-Motive
sind in sämtlichen Screenshots und beiden Feature-Grafiken entfernt. Das
vorhandene flache App-Logo bleibt erhalten.

Alle Bildschirmansichten zeigen ausschließlich das App-Theme
`Kinetic Neo-Brutalist` (`neoBrutalist` im Code), entsprechend dem Wunsch nach
„Brutal Neutralism“. Die violette Fläche im vierten Apple-Motiv ist nur der
Marketing-Hintergrund. Die sichtbare App ist auch dort Neo-Brutalist Light.

`index.html` öffnen, um alle Bilder anzusehen. Ein Klick auf ein Bild öffnet die
PNG-Datei in voller Auflösung. Nur die PNGs in den folgenden Exportordnern
hochladen; Quellen und Vorschauübersichten sind keine Store-Screenshots.

## Fertige Dateien

| Ordner | Motive pro Sprache | Größe |
| --- | ---: | --- |
| `Google_Play/de/` und `Google_Play/en/` | 5 | 1080 × 1920 |
| `Apple_iPhone/de/` und `Apple_iPhone/en/` | 4 | 1206 × 2622 |
| `Apple_iPad/de/` und `Apple_iPad/en/` | 4 | 2064 × 2752 |
| `Feature_Graphic/de/` und `Feature_Graphic/en/` | 1 | 1024 × 500 |

**28 uploadfähige PNG-Dateien**, jeweils RGB ohne Transparenz.
Die Datei beginnt mit ihrer empfohlenen Reihenfolge: `01_`, `02_` usw.
`de` ist Deutsch; `en` ist Englisch. Die Marketingtexte sind übersetzt, die
Oberfläche innerhalb der Geräte entspricht den ursprünglichen App-Aufnahmen.

Die Formate wurden anhand der aktuellen [Apple-Spezifikation](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
und [Google-Play-Vorgaben](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)
gewählt. Stand: 14. Oktober 2026. Die Feature-Grafik gehört in Google Play ins
entsprechende separate Grafikfeld; die iPad-Bilder in Apples iPad-Bereich.

## Bildreihenfolge

Google Play:

1. Weniger morgen. Mehr machen. — tägliche Gewohnheiten und Check-ins
2. Kleine Schritte. Sichtbar weiter. — Ziele, Fortschritt und Streaks
3. Allein geht. Zusammen knallt. — gemeinsame Quests
4. Deine Ziele. Deine Regeln. — eigene Ziele und Quest-Arten
5. Aura sammeln. Perks zünden. — virtuelle Aura, Schutz, Heists und Roasts

Apple iPhone und iPad:

1. Weniger morgen. Mehr machen. — Lesen, Fokus und Training
2. Allein geht. Zusammen knallt. — Fortschritt und kooperatives Training
3. Dein Fortschritt. Im Blick. — Fortschritt und Aura
4. Heute zählt. Jeder Check-in. — tägliche Ziele und Check-ins

## Quellen und Prüfung

- Die Android-Bildschirmdateien stammen aus den bereits vorhandenen
  Testemulator-Aufnahmen in `screenshots/raw/`. Während der Erstellung war
  kein Android-Emulator verbunden. Es wurde keine neue Aufnahme behauptet.
- Apple nutzt die bereits geprüften iPhone-/iPad-Simulatoraufnahmen aus
  `screenshots/apple/`; sie zeigen Produktions-Widgets mit lokalen,
  beispielhaften Quest-Daten. Verwendet werden ausschließlich die originalen
  Neo-Brutalist-Light-Ansichten von Home und Quests vom 10. Oktober.
  Die Motive 3 und 4 verwenden diese echten Ansichten erneut mit einem
  anderen Layout und einer anderen Nutzen-Botschaft.
- `sources/` enthält unveränderte Kopien der Screenshots. Die Prüfsummen im
  `manifest.json` stimmen mit den ursprünglichen Dateien im Projekt überein.
- Die Bildschirmbilder wurden nicht von einer Bild-KI nachgezeichnet. Sie
  bleiben eigene Bildebenen in einer neu erstellten HTML/CSS-Komposition.
  Skalierung, Geräte-Rundungen und leichte Drehung dienen der Präsentation.
  Bei Android blendet der Geräterahmen den schmalen Aufnahme-Rand aus.
- Revision 2 verwendet keine generierten 3D-Illustrationen. Die Änderung erfolgt
  direkt im bearbeitbaren Layout, ohne die App-Oberfläche nachzuzeichnen.
- Die PNG-Exporte wurden auf Maße, RGB-Farbkanäle, fehlende Transparenz,
  Dateigröße und unterschiedliche Inhalte geprüft. Die Texte und Layouts
  wurden visuell kontrolliert.
- Alt-Texte für die einzelnen Bilder stehen im Manifest und in
  `ALT-TEXTE.md`; sie können bei Google Play eingetragen werden.

Es wurden keine App-Funktionen, Themes oder Datenbankdaten geändert. Alle
28 Bilder sind seit dem 15. Oktober 2026 in den passenden Store-Einträgen
gespeichert und geprüft. Noch nicht zur Veröffentlichung eingereicht.
Details und Prüfgrenzen stehen in `UPLOAD_STATUS.md` und `upload-status.json`.

## Bearbeiten und erneut exportieren

`campaign.mjs` enthält Texte, Farben, Reihenfolge und das Layout.
`render.mjs` rendert die fertigen HTML/CSS-Kompositionen offline mit dem bereits
installierten Chromium über Playwright. Die Store-PNGs sind gewöhnliche Bilder
und brauchen zum Hochladen keine dieser Programme.

Für einen erneuten Export werden Node.js, `playwright` und `sharp` benötigt.
Die Module können über `NODE_PATH` aus der vorhandenen Codex-Laufzeit geladen
werden. Optional zeigt `AURA_STORE_CHROMIUM` auf die installierte Chromium-
Programmdatei. Dann `node render.mjs` in diesem Ordner ausführen.
Das Skript liest die vorhandenen Screenshots und Schriften im Repository.
Es verwendet keine Browser-Anmeldedaten und ruft keine Internetdienste auf.

Schriften: DM Serif Display und Inter aus den App-Assets. Die zugehörigen
SIL-Open-Font-Lizenzen liegen unter `sources/fonts/`.
