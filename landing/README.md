# Landingpage

Statische Seite, kein Bauwerkzeug, keine Abhängigkeiten. Drei Dateien
plus Bilder — das reicht für das, was sie tut, und lädt entsprechend
schnell.

```
landing/
  index.html      Deutsch
  en/index.html   Englisch
  styles.css      Gestaltung, erbt die Farbwelt der App  (beide Sprachen)
  main.js         Store-Links, Einblenden, Sabotage-Demo (beide Sprachen)
  screens/*.webp  Echte Screenshots aus der App
```

## Zwei Sprachen

Zwei eigene Seiten mit eigenen Adressen — **kein** Umschalten per
JavaScript:

| Adresse | Sprache |
|---|---|
| `/` | Deutsch |
| `/en/` | Englisch |

Das hat drei Gründe: Der Umschalter funktioniert ohne JavaScript, jede
Sprache lässt sich einzeln verlinken und teilen, und Suchmaschinen
finden beide Fassungen. Die `hreflang`-Angaben im Kopf verweisen
wechselseitig aufeinander; `x-default` zeigt auf Englisch.

**Beim Übersetzen synchron halten:** Die Abschnitts-Kennungen (`#how`,
`#types`, `#sabotage`, `#modes`, `#get`) müssen in beiden Dateien gleich
bleiben. `main.js` hängt beim Sprachwechsel den gerade sichtbaren
Abschnitt an — wer auf der Sabotage steht und wechselt, landet dort
wieder statt ganz oben. Weichen die Kennungen ab, geht das still
verloren.

Die wenigen Texte im Skript (Sprüche und Meldungen der Sabotage-Demo)
richten sich nach `document.documentElement.lang`. Acht Zeilen im Skript
zu halten ist vertretbar; wächst das, gehört es in eigene Sprachdateien.

## Ansehen

```bash
python -m http.server 4173 --directory landing
```

Dann `http://localhost:4173` öffnen. Die Konfiguration dafür liegt in
`.claude/launch.json`.

---

## Die Store-Links eintragen

Nur **eine** Stelle ändern, ganz oben in [`main.js`](main.js):

```js
const APP_STORE_URL   = '#';   // Apple App Store
const GOOGLE_PLAY_URL = '#';   // Google Play Store
```

Solange dort `#` steht, tragen alle Store-Knöpfe `aria-disabled="true"`
und springen nur zum Abschluss-Abschnitt. Sobald eine echte Adresse
eingetragen ist, werden sie automatisch zu richtigen Links — es ist
nichts weiter anzupassen.

Das ist Absicht: Ein Knopf, der so aussieht, als führe er in den Store,
und dann nichts tut, ist schlechter als einer, der sichtbar noch nicht
bereit ist.

---

## Die Screenshots

Stammen aus der laufenden App auf dem Emulator, nicht aus einem
Bildbearbeitungsprogramm. Die Android-Statusleiste ist abgeschnitten,
der Geräterahmen kommt per CSS.

Neu aufnehmen, wenn sich die App sichtbar ändert:

1. Emulator starten, anmelden, ein paar Quests anlegen
2. `adb -s emulator-5554 exec-out screencap -p > roh.png`
3. Oben 118 px abschneiden, auf 560 px Breite bringen, als WebP mit
   Qualität 88 speichern (ergibt 22–42 KB pro Bild)

**Wichtig:** Nur Funktionen zeigen, die es wirklich gibt. Die Seite
beschreibt ausschließlich Mechaniken, die in
[`docs/FEATURES.md`](../docs/FEATURES.md) belegt sind — jene Datei wurde
gegen Quellcode und Datenbank geprüft.

---

## Gestaltung

Die Seite erbt die Designsprache der App (Kinetic Neo-Brutalist), damit
sich beides wie dasselbe Produkt anfühlt:

| | |
|---|---|
| Grund | `#FBE9E1` — aus dem hellen App-Theme |
| Aura | `#FFC700` |
| Aura-Werte, Shop | `#7C3AED` |
| Erfolg | `#00A63E` |
| Verlust (Fläche) | `#FF4D3D` |
| Verlust (Text) | `#C42D1C` |

Zum letzten Punkt: `#FF4D3D` erreicht als Text auf Weiß nur **3,29:1**
und fällt damit unter die Lesbarkeitsgrenze von 4,5. Für Textfarbe gibt
es deshalb den dunkleren Ton. Wer das Rot woanders als Text einsetzt,
sollte `--coral-text` nehmen.

Schrift: **Archivo Black** für Überschriften, **Space Grotesk** für
Fließtext (dieselbe wie in der App), **Space Mono** für Zahlen und
Kennzeichnungen — die App handelt vom Zählen, ein Monospace-Ton passt
dazu.

Bewusst **nicht** verwendet: Verläufe, Glaseffekte, Schlagschatten mit
Weichzeichnung. Das wäre eine andere Marke.

---

## Die Sabotage-Demo

Der Abschnitt „Aura ist kein Punktestand" ist das Kernstück. Statt zu
beschreiben, was ein Angriff anrichtet, führt die Seite ihn am Besucher
aus: Der Blackout legt sich mit laufendem Countdown über den Abschnitt,
der Roast blockiert drei Sekunden, der Aura Heist würfelt mit der echten
25-Prozent-Chance aus der App.

Jeder Klick kostet auch echte Punkte vom Zähler; ist er leer, schalten
sich die Knöpfe ab. Die Preise (120 / 150 / 250) stammen aus der
Datenbank.

---

## Barrierefreiheit und Leistung

Geprüft im Browser, nicht nur angenommen:

- Kein waagerechtes Scrollen bei 390, 819 und 1425 px
- Alle Berührungsziele mindestens 44 px hoch
- Alle Bilder mit `alt`, `width` und `height` (kein Layoutsprung)
- Fünf von sechs Bildern verzögert geladen, das Hero-Bild vorgeladen
- Überschriften-Hierarchie H1 → H2 → H3 ohne Sprünge
- Sprunglink an erster Stelle der Fokusreihenfolge
- `prefers-reduced-motion` schaltet Einblendungen **und** Versatz ab
- Kontrast: alle Textelemente über der geforderten Schwelle

Ein bekannter Grenzfall: Das ⚡ neben dem Markennamen ist Gold auf Creme
und erreicht rechnerisch nur 1,33. Es trägt eine schwarze Kontur, ist
`aria-hidden` und rein dekorativ — die Information steht im Text
daneben.

---

## Auf dem NAS ausliefern

Der Container `auraquest-legal` liefert bereits statische Seiten aus. Die
Landingpage ließe sich genauso einhängen; dann bräuchte es nur einen
weiteren öffentlichen Hostnamen im Cloudflare-Tunnel.
