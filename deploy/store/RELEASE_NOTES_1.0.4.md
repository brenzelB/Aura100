# Aura Quest 1.0.4 — Build 26

Die beiden Apple-Abschnitte unten sind **wortgleich** mit dem, was am
02.11.2026 in App Store Connect gesichert wurde — inklusive der schlichten
Bindestriche. Wer sie ändert, muss sie dort mitändern, sonst ist diese Datei
kein Abbild mehr, sondern eine Behauptung.

Zwei Dinge: die neue Zielart CLOCK, und die Reparatur der Mitteilungen.

Zur Buildnummer: 1.0.3 lief als Build **24** (freigegeben am 28.10.2026,
14:49 Uhr). `pubspec.yaml` stand zu dem Zeitpunkt noch auf `+20`, weil die
Builds 21–24 über `--build-number` gebaut wurden. Mit 1.0.4 ist die Nummer
wieder im Projekt verankert.

Build **25** wurde am 02.11.2026 hochgeladen, aber keiner Testergruppe
zugewiesen — niemand hat ihn je geöffnet. Build **26** ersetzt ihn, bevor das
passiert ist. Die Apple-Texte unten bleiben dabei **unverändert**: 26 ändert
keine Zusage, sondern löst eine ein, die 25 nur halb gehalten hat (siehe
unten).

**Vor dem Build:** Die Migration `20261102120000_clock_quests.sql` muss auf dem
NAS liegen, sonst bricht die Questliste weg — diese Fassung fragt die Spalte
`challenges.tracking` ab. Angewendet am 02.11.2026, siehe
[NAS-Dokumentation](../nas/README.md#migrationen-einspielen).

## Was Build 26 gegenüber 25 ändert

Zwei Stellen, an denen die Uhr zwar maß, aber nichts Lesbares daraus machte.

- **Ein gemessener Lauf wird nach seinem Tag datiert, nicht nach dem Alter der
  Zeile.** Der Verlauf stempelte jeden Eintrag mit `1d` — für alles, was
  zwischen 24 und 48 Stunden her war. Niemand fastet in Zeilenaltern. Jetzt
  steht dort `yesterday` und darunter die beiden Enden: `Mon 20:00 → Tue 06:00`.
  Datiert wird nach dem **Ende** des Laufs, nicht nach dem Verbuchen.
- **Die Mitspielerliste ist eine Rangliste geworden.** Sortiert wird nach der
  Woche, mit heute / Woche / Monat unter jedem Namen. Vorher entschied der
  laufende Zeitraum — bei täglicher Quest standen damit um Mitternacht alle
  auf null, und Platz 1 ging an den, der zuerst verbuchte. Der Satz *„Spiel es
  mit Freunden: Wer länger durchhält, steht vorne“* aus den Apple-Texten
  stimmt erst ab diesem Build.

Keine Migration nötig. Die Zeilen waren immer lesbar — `progress_entries` und
`clock_sessions` lassen Questmitglieder einander sehen —, die Abfragen haben
die Geschichte nur weggeworfen, bevor sie auf den Bildschirm kam.

Tagesnamen im Verlauf rechnen in **Ortszeit**, die Summen in **UTC**. Das ist
Absicht: die Summen müssen zu der Aura passen, die der Server ausgezahlt hat,
und der rechnet in UTC. Commit `7ec6318`.

## Apple App Store — English (en-US)

Some habits are measured in time.

- New CLOCK quests: start the timer when you begin and stop it when you stop. Fasting, focused work, time away from a screen - anything counted in hours and minutes.
- See how long you managed today, this week and this month.
- Play it with friends: whoever held out longest leads the party.
- Forgot to start or to stop the timer? Correct both times before you bank the session.
- Fixed: notifications could not be switched on if the very first prompt was missed. You can now allow them at any time from your Profile.

## Apple App Store — Deutsch (de-DE)

Manche Gewohnheiten misst man in Zeit.

- Neue CLOCK-Quests: Uhr starten, wenn du anfängst, stoppen, wenn du aufhörst. Fasten, konzentriertes Arbeiten, Zeit ohne Bildschirm - alles, was sich in Stunden und Minuten zählt.
- Sieh, wie lange du heute, diese Woche und diesen Monat durchgehalten hast.
- Spiel es mit Freunden: Wer länger durchhält, steht vorne.
- Start oder Stopp vergessen? Du kannst beide Zeiten korrigieren, bevor du die Sitzung verbuchst.
- Behoben: Mitteilungen ließen sich nicht mehr einschalten, wenn die allererste Abfrage verpasst wurde. Jetzt kannst du sie jederzeit im Profil erlauben.

## Nicht in den Apple-Texten

Der Android-Fix (der Mitteilungs-Knopf, der nach der zweiten Ablehnung
wirkungslos herumstand) steht bewusst **nicht** in den App-Store-Texten — er
betrifft keinen einzigen Apple-Nutzer. Er gehört in die Play-Store-Notizen,
sobald die Android-Fassung veröffentlicht wird; bis dahin ist er nur hier und
im Commit `4d20199` festgehalten.

## Was diese Fassung NICHT enthält

Ehrlichkeitshalber festgehalten, damit es niemand für geprüft hält:

- **Push-Mitteilungen sind nie auf einem Gerät angekommen.** Die Serverkette ist
  durchgemessen (Outbox, Cron, Edge Function, FCM nimmt an, `push_deliveries`
  zeigt zugestellte iOS-Nachrichten), aber die Erlaubnis war auf keinem Telefon
  je erteilt — genau das repariert diese Fassung. Ob danach wirklich eine
  Mitteilung aufploppt, ist offen und muss am Gerät geprüft werden.
- **Die Uhr lief auf keinem Gerät.** 547 Tests laufen durch; das ist keine
  Benutzung.
- **Kein eigener Weg, eine Sitzung komplett nachträglich einzutragen** — der
  korrigierbare Start deckt den Fall ab, aber es gibt keinen Knopf „Sitzung von
  gestern hinzufügen".
- **Keine Erinnerung, wenn die Uhr zu lange läuft.** Die Warnung ist nur
  sichtbar, solange man die App offen hat. Eine Push-Erinnerung wäre der
  nächste Schritt, sobald Push bewiesen ist.
- **Laufende Uhren der Mitspieler** („Max fastet seit 14h") zeigt die App
  nicht. Die Leserechte dafür stehen.

## Prüfhinweise für Apple

Keine Änderung gegenüber 1.0.3 nötig: CLOCK-Quests verwenden dieselben Konten,
dieselbe Moderation und dieselben Berechtigungen. Die Uhr fordert keine neuen
Systemrechte an — sie misst nur die Zeit zwischen zwei Antippern, serverseitig.
Mitteilungen werden weiterhin erst nach ausdrücklicher Zustimmung verschickt;
diese Fassung macht die Abfrage lediglich wieder erreichbar.
