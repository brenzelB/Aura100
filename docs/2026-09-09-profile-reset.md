# Verständliche Ablehnung beim Stats-Reset

Der NAS-RPC `reset_my_stats` lehnt den Reset bei aktiven Quest-Teilnahmen
oder offenen Duellen absichtlich ab (Postgrest-Code `P0001`). Beide
Emulator-Konten hatten bei der Prüfung jeweils zwei aktive Teilnahmen.
Die bisherige Oberfläche ersetzte diese Erklärung durch eine pauschale
Aufforderung, den Reset nochmals zu versuchen.

Die Voraussetzungen stehen jetzt im Profil und im Bestätigungsdialog.
Ein bestätigter Reset löscht zusätzlich die persönliche XP-Historie und setzt
das Level auf 0. Eine bewusste RPC-Ablehnung zeigt ihren konkreten Grund für acht
Sekunden;
unerwartete technische Fehler bleiben allgemein formuliert. Die
serverseitige Schutzregel bleibt bestehen. Es wurden keine Stats gelöscht.

Im selben Profil fiel beim Laden der Erinnerungen zusätzlich SQL-Fehler
42703 auf: `quest_reminders` hat keine Spalte `id`. Die paginierte Abfrage
sortiert jetzt nach `challenge_id`, das innerhalb der durch RLS auf das
eigene Konto beschränkten Daten eindeutig ist.

Prüfung am 09.09.2026:

- Zwei neue Widgettests prüfen den bestätigten Reset mit fachlicher und
  technischer Ablehnung, einschließlich Schutz vor internen Fehlerdetails.
- Zusammen mit Check-in- und Home-Regressionen: 17 Tests bestanden.
- `flutter analyze`: keine Probleme; Android-Debug-Build erfolgreich.
- APK auf beiden Emulatoren installiert, bestehende App-Daten erhalten.
- Auf Emulator 5556 Reset-Dialog und echte NAS-Ablehnung geprüft: konkrete
  Voraussetzungen erscheinen korrekt in der Meldung.
- Erinnerungsabfrage läuft dort erfolgreich (`fetchQuestReminders: 0 set`),
  passend zur schreibgeschützt geprüften leeren Tabelle auf dem NAS.

Die Migration `20260909075449_reset_lifetime_xp.sql` wurde auf dem NAS
eingetragen und atomar ausgeführt. Das geprüfte Backup liegt unter
`/volume2/Datenbanken/AuraQuest/backups/xp-reset-before-20260909105005.dump`.
Docker wurde ausschließlich auf dem NAS verwendet.
