# Aura Quest 1.0.5 — Build 28

Setzt das App-Review vom 09.11.2026 um (PR #1). Gebaut am 11.11.2026 über
den Release-Workflow mit `build_number` 28 (1.0.4 lief zuletzt als Build 27).

**Vor dem Build:** Die Migration `20261110120000_clock_rest_days.sql` muss auf
dem NAS liegen. Angewendet am 11.11.2026, siehe
[NAS-Dokumentation](../nas/README.md#migrationen-einspielen). Ohne sie ließe
der Server einen Stoppuhr-Start an Ruhetagen weiter zu. Die App würde ihn
dann zwar nicht mehr anbieten, alte Fassungen aber schon.

## Was sich gegenüber 1.0.4 (27) ändert

- Stoppuhr-Quests: Die laufende Uhr ist auf Home, den Quest-Karten und in der
  Quest-Ansicht sichtbar. An Ruhetagen startet sie nicht mehr, weder in der App
  noch auf dem Server. Verwerfen fragt nach.
- Home an Ruhetagen: „Rest day.“ statt „keine Quests“. Kommende Quests bleiben
  sichtbar. Karten öffnen die Quest beim Tippen.
- Fehlermeldungen: Nur noch Spielregel-Meldungen vom Server (SQLSTATE P0001),
  keine Datenbanktexte.
- Einladungen zeigen die Regeln. Fehlgeschlagene Einladungen beim Anlegen
  werden mit Namen gemeldet.
- Quests-Tab gruppiert (Active, Waiting to start, Finished). Der Questtitel
  steht in der App-Leiste, „Abandon“ liegt im ⋮-Menü.
- Erste Quest: Vorlagen Workout, Reading, 10k steps, No smoking und ein Satz
  zu Aura und Strikes.
- Texte nennen den Tageswechsel in Ortszeit statt „UTC“. Die Questtage selbst
  bleiben UTC-Tage.
- Release-Builds schreiben keine E-Mail-Adressen mehr ins Log.

## Google Play

„Neu in dieser Version“ kommt aus `deploy/store/play/whatsnew/*.txt` und wird
beim Upload mitgeschickt.

## TestFlight „Was testen“ (von Hand in App Store Connect eintragen)

DE:

```
1.0.5: Stoppuhr-Quests an Ruhetagen und auf dem Startbildschirm, Vorlagen für die erste Quest, Einladungen mit Regeln, gruppierter Quests-Tab. Bitte besonders testen: Stoppuhr starten und stoppen, eine Quest mit Ruhetag öffnen, eine Einladung annehmen.
```

EN:

```
1.0.5: Stopwatch quests on rest days and on Home, templates for the first quest, invites with rules, grouped Quests tab. Please test: starting and stopping a stopwatch, opening a quest on its rest day, accepting an invite.
```

## Was diese Fassung nicht enthält

- Questtage in Ortszeit (der Server rechnet weiter in UTC-Tagen).
- Einladungslink oder QR-Code.
- Offline-Speichern für Stoppuhr- und Fortschrittseinträge.

567 Tests (ohne Golden-Tests) und die Golden-Tests unter Windows waren auf
`main` grün. Auf einem Gerät ist diese Fassung noch nicht gelaufen.
