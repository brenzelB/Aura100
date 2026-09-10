# Umsetzungspaket 2: flüssiger Tagesablauf

Stand: 8. September 2026. Basis: Commit `2e6604d`.

## Verhalten

- Home zeigt zuerst den kompakten Tagesstand und direkt darunter offene Aufgaben.
  Gefährdete Quests bleiben innerhalb dieser Liste priorisiert.
- Fortschrittsquests haben direkte Schnellaktionen. Bei einem Ziel von 10:
  `+1`, `+5`, `Finish (Restmenge)`. Die Beträge skalieren mit dem Ziel, auch bei
  Dezimalwerten. `ADD` öffnet weiterhin die freie Eingabe.
- Während einer Buchung sind die Schnellaktionen gesperrt; sie warten auch auf
  den aktualisierten Restwert. Blackouts und gezielte Roast-Sperren gelten weiter.
- Bestätigte Aktionen erhalten eine kurze Rückmeldung und dezente Haptik. Der
  Aura-Zähler verwendet ausschließlich die vom Server gemeldete Gutschrift.
  Fehler, offene Anfragen und Offline-Buchungen zeigen keine Belohnung.
- Offline-Check-ins erscheinen sofort als lokal gespeichert. Sie zählen erst
  nach Synchronisierung zum bestätigten Tagesstand. Diese Anzeige wartet nicht
  auf den Timeout eines Hintergrundabrufs.
- Einladungen, Freunde, Angriffe und Ereignisse liegen in einer aufklappbaren
  Aktivitätssektion. Auch der Wochenrückblick startet eingeklappt. Abschlüsse und
  Verlustmeldungen öffnen sich über die Ereignisliste statt Home zu unterbrechen.
- Fortschrittsbalken und Aura-Animation respektieren reduzierte Bewegung.
  Karten und der Abschlussdialog passen auch auf schmale Displays.

## Zusätzlich behobener Ladefehler

Auf dem NAS existieren eigene historische Ereignisse zu Quests, deren Details
für das jeweilige Konto nicht mehr lesbar sind. Der bisherige Dart-Cast der
eingebetteten Quest auf eine nicht nullable Map ließ die gesamte Ereignisliste
scheitern. Der NAS-Test als `authenticated` bestätigte dies für sechs Ereignisse
des zweiten Testkontos.

Die App verarbeitet diesen Fall jetzt als `Unavailable quest`. Das Ereignis
bleibt lesbar und bietet keinen ungültigen Link auf die Quest an. Es wurden
keine Datenbankrechte erweitert und keine Schemaänderungen benötigt.
Das entspricht der dokumentierten NULL-Rückgabe bei fehlenden eingebetteten
Relationen: [Supabase: Join types](https://supabase.com/docs/guides/database/joins-and-nesting#join-types-and-join-modifiers).

## Validierung

- `flutter analyze`: keine Befunde.
- `flutter test`: **93 Tests bestanden**, davon zwölf für dieses Paket.
  Abgedeckt sind unter anderem Doppeltipps, Serverfehler und Wiederholung,
  Kontowechsel während einer Anfrage, Blackouts, Restwert-Aktualisierung,
  Offline-Anzeige bei veraltetem Serverstand, fehlende Quest-Joins,
  große Schrift bei 320 logischen Pixeln sowie bestätigte Aura und Haptik.
- `flutter build apk --debug`: erfolgreich. Der finale Build ist auf
  `emulator-5554` und `emulator-5556` installiert.
- NAS/Emulator-Test: `+1`, `+5`, Rest `4` ergaben exakt 10 Wiederholungen,
  einen Check-in und Aura `500 → 600`. Im finalen Build wurde außerdem
  `Finish (10)` ausgehend von null separat bestätigt.
- Offline-Test im finalen Build: nach lokalem Speichern **0** Check-ins und
  **500** Aura im NAS; nach Wiederherstellung des Netzes **1** Check-in und
  **600** Aura. Wartestatus und Tageszähler wechselten korrekt.
- Beide Aktivitätslisten laden wieder erfolgreich; eine nicht mehr zugängliche
  Quest wurde auch über ihre Ereignisdetails auf dem Emulator geprüft.
- Temporäre Prüfquests anschließend entfernt, Entfernung verifiziert;
  Netzwerkverbindungen beider Emulatoren eingeschaltet.

Die Screenshots und der Testlauf liegen lokal unter `build/smooth/` bzw.
`build/smooth-all-tests.log`. Die APK liegt unter
`build/app/outputs/flutter-apk/app-debug.apk`.

Die Emulatorprüfung belegt Bedienabläufe und korrekte Buchungen; eine
FPS-Messung auf physischen Geräten war nicht Teil dieses Pakets. Gradle meldet
weiterhin die vorhandene Warnung zur künftigen Kotlin-Plugin-Kompatibilität von
`unifiedpush_android` und `webcrypto`; der aktuelle Build ist erfolgreich.
