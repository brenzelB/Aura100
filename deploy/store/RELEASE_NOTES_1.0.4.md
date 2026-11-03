# Aura Quest 1.0.4 — Build 27

Die beiden Apple-Abschnitte unten sind **wortgleich** mit dem, was am
02.11.2026 in App Store Connect gesichert wurde — inklusive der schlichten
Bindestriche. Wer sie ändert, muss sie dort mitändern, sonst ist diese Datei
kein Abbild mehr, sondern eine Behauptung.

Zwei Dinge: die neue Zielart CLOCK, und die Reparatur der Mitteilungen.

Zur Buildnummer: 1.0.3 lief als Build **24** (freigegeben am 28.10.2026,
14:49 Uhr). `pubspec.yaml` stand zu dem Zeitpunkt noch auf `+20`, weil die
Builds 21–24 über `--build-number` gebaut wurden. Mit 1.0.4 ist die Nummer
wieder im Projekt verankert.

Build **25** wurde am 02.11.2026 hochgeladen, Build **26** am 03.11.2026. Beide
sind der Gruppe „Aura Quest iOS intern“ zugewiesen, und der Testereintrag dort
sagt „Installiert 1.0.4 (26)“ auf einem iPhone 13. Build **27** löst 26 also
nicht ab, weil 26 niemanden erreicht hätte, sondern weil er den Questfix
enthält.

Eine frühere Fassung dieser Datei behauptete, die Builds lägen bei keinem
Tester. Das war falsch; App Store Connect widerlegt es. Festgehalten bleibt
eine Unstimmigkeit, die dort offen ist: die Build-Tabelle führt für 26 null
Installationen, die Testeransicht nennt ihn installiert. Welche der beiden
Zählungen stimmt, ist von hier aus nicht zu entscheiden.

Die Apple-Texte unten bleiben dabei **unverändert**: 27 ändert keine Zusage,
sondern löst eine ein, die 25 nur halb gehalten hat (siehe unten).

**Vor dem Build:** Die Migration `20261102120000_clock_quests.sql` muss auf dem
NAS liegen, sonst bricht die Questliste weg — diese Fassung fragt die Spalte
`challenges.tracking` ab. Angewendet am 02.11.2026, siehe
[NAS-Dokumentation](../nas/README.md#migrationen-einspielen).

## Was Build 27 gegenüber 26 ändert

Eine geschaffte Quest verschwand.

Die Questliste fragte den Server nach Teilnahmen mit dem Status `active`,
`failed` oder `eliminated`. Gewinnen setzt `completed` — das fehlte in der
Aufzählung. Die Wirkung war genau verkehrt herum: eine Quest, die man
**verloren** hatte, blieb einem vor Augen; eine **gewonnene** verschwand
stillschweigend, innerhalb einer Stunde nach dem letzten Abhaken.

Verloren war dabei nichts. Der Eintrag lag die ganze Zeit im Trophäenraum im
Profil — zugeklappt, und bei Leere gar nicht erst sichtbar. Nur hat auf dem
Weg hinaus niemand gesagt, wohin.

Ab Build 27:

- **Die gewonnene Quest behält ihren Platz in der Liste**, bis ihr eigenes
  Enddatum erreicht ist, mit einem grünen DONE-Abzeichen statt der
  Abhaken-Aufforderung.
- **Antippen zeigt die Auswertung**: Ergebnis, ausgezahlte Aura, geschaffte
  Tage, längste Serie, verbrauchte Strikes — und sobald mehr als einer
  mitgespielt hat, die Endrangliste.
- **Ein Knopf nimmt sie aus der Liste.** Er räumt sie zugleich aus dem
  Trophäenraum, weil es dasselbe Kennzeichen ist, und der Bestätigungsdialog
  sagt das auch so. Behalten braucht keinen Knopf: Nichtstun behält sie.

Zur Uhrzeit, an der sich das zuerst gezeigt hat: bei Tages-Quests rechnet der
Motor ab, **sobald der Sieg feststeht** — am letzten Tag also direkt nach dem
Abhaken, gebucht vom stündlichen Cron. Das bleibt so. Es war nie das Problem;
das Problem war, dass die Belohnung als Verschwinden ankam.

Keine Migration. Jede Spalte und jede Funktion dafür liegt seit Juli in der
Datenbank — `hide_trophy` eingeschlossen. Der Client hat den Sieg bei der
Ankunft weggeworfen. Commit `136d72c`.

### Nicht in den Apple-Texten

Die beiden Apple-Abschnitte unten sind **unverändert**. Wer Testern diesen Fix
ankündigen will, muss die Zeile in App Store Connect selbst nachtragen — die
Texte hier sind ein Abbild dessen, was dort steht, und dürfen nicht
auseinanderlaufen.

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

## Google Play — geschlossener Test (Build 27)

Play erlaubt 500 Zeichen je Sprache. Diese beiden Texte sind dafür gezählt
(de-DE 494, en-US 474) und tragen zwei Zeilen, die in den Apple-Texten bewusst
fehlen: den Android-only Mitteilungs-Fix und den Questfix aus Build 27.

### de-DE

- Neue CLOCK-Quests: Uhr starten und stoppen statt abhaken. Fasten, Fokus, Bildschirmpause.
- Sieh, wie lange du heute, diese Woche und diesen Monat durchgehalten hast.
- Wer länger durchhält, steht vorne.
- Start oder Stopp vergessen? Beide Zeiten lassen sich vor dem Verbuchen korrigieren.
- Behoben: Mitteilungen ließen sich nicht einschalten, wenn die Abfrage verpasst oder zweimal abgelehnt wurde.
- Behoben: Eine geschaffte Quest verschwand. Sie bleibt jetzt mit Auswertung und Rangliste.

### en-US

- New CLOCK quests: start and stop a timer instead of ticking a box. Fasting, focus, screen-free time.
- See how long you managed today, this week and this month.
- Whoever holds out longest leads the party.
- Forgot to start or stop? Both times can be corrected before you bank the session.
- Fixed: notifications could not be switched on if the prompt was missed or refused twice.
- Fixed: a completed quest used to vanish. It now stays, with a summary and final standing.

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
- **Die Uhr ist installiert, aber ungeprüft benutzt.** Build 27 liegt seit dem
  03.11.2026 auf einem iPhone 13. Ob damit je ein Lauf gemessen wurde, steht
  hier nicht — 561 Tests laufen durch, und das ist keine Benutzung.
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
