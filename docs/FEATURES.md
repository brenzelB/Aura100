# Aura Quest — Vollständige Feature-Dokumentation

**Stand:** 5. August 2026 · Geprüft gegen Quellcode (74 Dart-Dateien) und die
laufende Produktionsdatenbank (18 Tabellen, 47 Server-Funktionen, 39 Migrationen).

Dieses Dokument hat zwei Aufgaben. Es beschreibt erstens jede Funktion so genau,
dass man sie ohne Blick in den Code verstehen, testen oder erklären kann.
Zweitens liefert es zu jeder Funktion einen **Verkaufswinkel** — den Satz, der
erklärt, warum sie jemanden interessieren sollte. Wer Marketingmaterial baut,
kann die Winkel direkt übernehmen; wer entwickelt, hält sich an die Mechanik.

> **Sprachhinweis:** Die App spricht durchgehend Englisch. Alle Bezeichnungen in
> Anführungszeichen sind wörtlich das, was der Nutzer sieht. Im Code heißen
> Quests weiterhin `challenges` (Tabellen, Routen, Provider) — das ist Absicht
> und für niemanden außerhalb des Teams sichtbar.

---

## Inhalt

1. [Was Aura Quest ist](#1-was-aura-quest-ist)
2. [Das Grundprinzip: Aura](#2-das-grundprinzip-aura)
3. [Quest-Typen — was zählt als Erfolg](#3-quest-typen--was-zählt-als-erfolg)
4. [Quest-Modi — wer gegen wen](#4-quest-modi--wer-gegen-wen)
5. [Zeitstruktur](#5-zeitstruktur)
6. [Der Abrechnungsmotor](#6-der-abrechnungsmotor)
7. [Der Quest-Shop](#7-der-quest-shop)
8. [Angriffs-Mechaniken](#8-angriffs-mechaniken)
9. [Würfelduelle](#9-würfelduelle)
10. [Soziales](#10-soziales)
11. [Rückblick und Statistik](#11-rückblick-und-statistik)
12. [Zuschauer-Modus](#12-zuschauer-modus)
13. [Sicherheit und Fairness](#13-sicherheit-und-fairness)
14. [Personalisierung](#14-personalisierung)
15. [Konto und Zugang](#15-konto-und-zugang)
16. [Technischer Unterbau](#16-technischer-unterbau)
17. [Marketing-Baukasten](#17-marketing-baukasten)
18. [Bekannte Lücken und Grenzen](#18-bekannte-lücken-und-grenzen)

---

## 1. Was Aura Quest ist

Ein Habit-Tracker, der aufhört, ein Habit-Tracker zu sein, sobald ein zweiter
Mensch dazukommt.

Klassische Gewohnheits-Apps belohnen dich mit einem Haken und einer Zahl, die
nur du siehst. Aura Quest macht aus derselben Handlung eine Währung, die
zwischen Freunden zirkuliert: Du verdienst **Aura** durch Erledigen, verlierst
sie durch Auslassen, und kannst sie ausgeben, um dir Vorteile zu kaufen — oder
um deinen Freunden das Leben schwer zu machen.

Der entscheidende Unterschied zu „Freunde sehen deine Streak": Hier greifen
Freunde **aktiv ein**. Sie können deine Aura stehlen, dir einen Spruch auf den
Bildschirm legen oder dich für zwei Stunden aussperren. Disziplin wird zum
Spielfeld statt zum Tagebuch.

**Der Pitch in einem Satz:**
> Gewohnheiten aufbauen, indem man Freunde herausfordert — und sabotiert.

---

## 2. Das Grundprinzip: Aura

Aura ist die einzige Währung und existiert **pro Quest**, nicht global. Wer in
einer Quest reich ist, startet in der nächsten wieder bei null. Das hält jede
Quest für sich spannend und verhindert, dass ein Vielspieler neue Mitspieler
sofort überrollt.

| Ereignis | Wirkung |
|---|---|
| Check-in erledigt | **+ Aura-Gewinn** (Standard 100) |
| Periode verpasst | **− Aura-Strafe** (Standard 50) + 1 Strike |
| Strikes aufgebraucht | Quest gilt als **verloren** |
| Quest abgeschlossen | Abschlussbonus |

**Standardwerte beim Anlegen:** 100 Aura pro Check-in, 50 Aura Strafe,
1 Strike, 7 Tage Laufzeit, 3 Check-ins pro Periode. Alles frei einstellbar.

### Aura-Multiplikatoren

Zwei Shop-Titel wirken dauerhaft auf **jeden** Check-in:

| Titel | Multiplikator |
|---|---|
| Title Badge | ×1,2 |
| Aura Lord | ×2,0 |

Sie stapeln nicht — der höhere gewinnt.

**Verkaufswinkel:** Deine Disziplin bekommt einen Kurswert. Und dieser Kurs ist
in jeder Quest ein anderer, also fängt jede neue Runde bei Gleichstand an.

---

## 3. Quest-Typen — was zählt als Erfolg

Beim Anlegen wird festgelegt, **wie** eine Periode erfüllt wird. Drei Typen,
und der dritte ist der, den kaum eine andere App hat.

### 3.1 Check — abhaken

Einmal pro Periode antippen, fertig. Für alles, was man entweder tut oder nicht
tut: meditieren, Tagebuch schreiben, joggen.

> *Beispiel: „10 Minuten Meditation", täglich.*

### 3.2 Progress — sammeln

Ein frei definiertes Ziel mit frei definierter Einheit wird in Teilbeträgen
gefüllt. Mehrere Einträge pro Tag sind möglich, nachträgliches Bearbeiten und
Löschen ebenfalls. Ein Fortschrittsbalken zeigt Stand, Prozent und Übererfüllung.

> *Beispiel: „100 Liegestütze", Einheit „Reps" — 30 morgens, 40 mittags,
> 30 abends.*

### 3.3 Avoid — nicht tun

Der umgekehrte Fall: Man gewinnt, indem man **etwas unterlässt**. Jeder
Rückfall wird als „Slip" protokolliert. Ein Tagesbudget (`daily_allowance`)
erlaubt eine definierte Anzahl Ausrutscher, ohne dass die Periode verloren ist —
bei Budget 0 zählt jeder Slip sofort. Der letzte Slip lässt sich rückgängig
machen, falls man sich vertippt hat.

Am Periodenende bucht der Server automatisch einen Erfolg, wenn das Budget
gehalten wurde. **Man muss nichts tun, um zu gewinnen** — was genau der Punkt
ist.

> *Beispiel: „Nicht rauchen", Budget 0. Oder „Höchstens 2 Kaffee", Budget 2.*

**Verkaufswinkel:** Die meisten Tracker können nur „hab ich gemacht". Aura Quest
kann auch „hab ich gelassen" — und das ist die Hälfte aller Vorsätze, die
Menschen überhaupt fassen.

---

## 4. Quest-Modi — wer gegen wen

Der Modus wird beim Anlegen festgelegt und ist danach fix.

### 4.1 FREE FOR ALL

Keine Teams. Jeder wird für sich bewertet. Allein spielbar, aber mit
eingeladenen Freunden entsteht ein Wettrennen auf der Aura-Rangliste.

*Der Standardmodus und der Einstieg für alle, die nur ihre Gewohnheit
verfolgen wollen.*

### 4.2 CO-OP

**Einer für alle.** Verpasst ein einziges Mitglied eine Periode, zahlt die
**gesamte Gruppe** Strafe und Strike. Ein einzelner Streak Shield schützt alle.
Fällt einer, fallen alle.

*Erzeugt den stärksten sozialen Druck von allen Modi — und die stärkste
Verbundenheit, wenn es klappt.*

### 4.3 TEAM BATTLE

Zwei Teams, Rot und Blau. Neu Beitretende füllen automatisch die kleinere
Seite. Am Ende gewinnt das Team mit den meisten Check-ins **pro Mitglied** —
so entscheidet die Disziplin, nicht die Gruppengröße. Die Verlierer zahlen
25 % ihrer Aura als Tribut an die Gewinner.

### 4.4 LAST STANDING

Ausscheidungsmodus. Wer seine Strikes aufbraucht, ist **raus**. Der Ersteller
lädt ein und drückt START; danach kommt niemand mehr dazu. Wer am längsten
durchhält, bekommt einen Bonus für jeden überlebten Rivalen. Von Natur aus
endlos — die Quest läuft, bis nur noch einer steht.

**Verkaufswinkel:** Vier Modi bedeuten vier komplett verschiedene soziale
Dynamiken aus derselben Mechanik. Dieselbe Gewohnheit fühlt sich als CO-OP
völlig anders an als im Last Standing.

---

## 5. Zeitstruktur

### Perioden

Eine Quest fordert **n Check-ins pro Periode**. Perioden sind `daily`,
`weekly` oder `monthly` — Wochen- und Monatsperioden sind 7- bzw. 30-Tage-Blöcke,
verankert am Startdatum der Quest, nicht am Kalender.

### Aktive Wochentage

Beim Anlegen lässt sich auswählen, an welchen Wochentagen die Quest überhaupt
aktiv ist — voreingestellt sind alle sieben. Inaktive Tage:

- fordern nichts
- erzeugen keinen Strike
- zählen nicht als verpasst
- werden aus allen Statistiken herausgerechnet

Serverseitig verhindern Trigger sogar, dass an einem inaktiven Tag überhaupt
etwas eingetragen wird. Bestehende Quests laufen unverändert weiter, weil das
Standardfeld alle sieben Tage enthält.

> *Beispiel: „Gym", Mo–Fr. Am Wochenende passiert nichts — kein Strike,
> keine Lücke in der Statistik.*

### Endlose Quests

Quests können ohne Enddatum laufen. Last Standing ist immer endlos.

**Verkaufswinkel:** Ein Trainingsplan, der am Sonntag nach dir schreit, ist
kaputt. Aura Quest kennt Ruhetage.

---

## 6. Der Abrechnungsmotor

Das Herzstück, und es läuft vollständig auf dem Server — nicht in der App.

Zwei Cron-Jobs in der Datenbank:

| Zeitplan | Aufgabe |
|---|---|
| stündlich zur Minute 5 | `settle_periods()` — abgelaufene Perioden abrechnen |
| stündlich zur Minute 10 | `expire_duels()` — unbeantwortete Duelle auflösen |

`settle_periods()` geht jede Quest und jeden Teilnehmer durch, bestimmt die
fälligen Perioden, zählt Check-ins, Fortschritt oder Slips, wendet gekaufte
Schutzgegenstände an, bucht Aura, setzt Strikes und beendet Quests. Jede
Buchung erzeugt ein nachvollziehbares Ereignis:

`completed` · `failed` · `penalty` · `strike` · `shield_saved` ·
`half_damage` · `strike_repaired` · `bonus` · `milestone` ·
`duel_won` · `duel_lost` · `versus_won` · `versus_lost`

Diese Ereignisse speisen die Aktivitätsliste, die Startseiten-Meldungen und den
Wochenrückblick.

**Warum das wichtig ist:** Weil die Abrechnung auf dem Server passiert, ist es
egal, ob die App offen war. Wer eine Woche nicht hineinschaut, findet trotzdem
korrekte Strikes, Strafen und Ergebnisse vor. Und es ist die Grundlage dafür,
dass die App nicht manipulierbar ist.

---

## 7. Der Quest-Shop

Jede Quest hat ihren **eigenen** Shop, bezahlt wird mit der Aura **dieser**
Quest. Acht Gegenstände in drei Kategorien.

### Schutz

| Gegenstand | Preis | Wirkung |
|---|---|---|
| **Streak Shield** | 300 | Ein verpasster Tag wird verziehen — kein Strike. |
| **Strike Repair** | 500 | Kauft einen bereits verbrauchten Strike sofort zurück. |

### Verstärkung

| Gegenstand | Preis | Wirkung |
|---|---|---|
| **Double Down** | 100 | Der nächste Check-in bringt doppelte Aura. |
| **Title Badge** | 50 | Goldenes Emblem am Namen **und** +20 % Aura auf jeden Check-in. |
| **Aura Lord** | 1000 | Krone am Namen **und** doppelte Aura auf jeden Check-in. |

Titel sind Einmalkäufe und werden neben dem Namen in der Party angezeigt.
Verbrauchsgegenstände lassen sich stapeln.

### Angriff — siehe [Abschnitt 8](#8-angriffs-mechaniken)

| Gegenstand | Preis |
|---|---|
| **Targeted Roast** | 120 / 200 |
| **Aura Heist** | 150 / 300 / 500 |
| **Blackout** | 250 |

**Verkaufswinkel:** Aura ist keine Punktzahl zum Anschauen. Sie ist Budget —
und jede Ausgabe ist eine Entscheidung zwischen sich selbst absichern und den
anderen ärgern.

---

## 8. Angriffs-Mechaniken

Nur in Mehrspieler-Quests verfügbar. Alle drei werden **serverseitig**
durchgesetzt: Ein manipulierter Client kann sie weder auslösen noch abwehren.

### 8.1 Aura Heist — Raubzug

Stiehlt einem Quest-Kameraden die Aura seines nächsten Check-ins. Der Preis
bestimmt die Erfolgswahrscheinlichkeit:

| Einsatz | Chance |
|---|---|
| 150 | 25 % |
| 300 | 50 % |
| 500 | 75 % |

Der Würfelwurf passiert auf dem Server. Das Opfer erfährt beim nächsten Öffnen
der App, dass es bestohlen wurde — **auch wenn es zum Zeitpunkt des Raubs
offline war.**

### 8.2 Targeted Roast — Spruch aufs Gesicht

Legt dem Ziel einen Spruch bildschirmfüllend über die App, den es aussitzen muss.

| Preis | Dauer |
|---|---|
| 120 | 3 Sekunden |
| 200 | 5 Sekunden |

Die App bringt eine Sammlung von **297 Sprüchen** mit. Einen Schutz dagegen
gibt es nicht — ein Roast trifft immer.

### 8.3 Blackout — Aussperrung

Der strategisch schärfste Gegenstand. Für 250 Aura wird ein Quest-Kamerad
**zwei Stunden lang** ausgesperrt: Er kann in dieser Zeit weder einchecken noch
Fortschritt eintragen noch Slips melden.

Der Angreifer wählt eine Tageszeit:

| Fenster | Zeitraum (Ortszeit des Opfers) |
|---|---|
| 🌅 Morgen | 07:00 – 09:00 |
| ☀️ Mittag | 12:00 – 14:00 |
| 🌙 Abend | 20:00 – 22:00 |

Zwei Details, die den Unterschied machen:

- **Ortszeit des Opfers.** Die App meldet die Zeitzone jedes Nutzers an den
  Server. Ein Blackout um 20 Uhr trifft das Opfer um 20 Uhr — nicht um 20 Uhr
  beim Angreifer.
- **Sofortstart.** Liegt der gewählte Zeitraum gerade jetzt, beginnt die
  Sperre augenblicklich statt am nächsten Tag.

Das Ziel sieht während der Sperre klar, dass es gesperrt ist, und wie lange
noch. Wer währenddessen offline war, bekommt es hinterher gesagt.

**Verkaufswinkel:** Das ist der Moment, in dem eine Gewohnheits-App zum Spiel
wird. Man plant nicht mehr nur seinen eigenen Tag, sondern auch den Angriff auf
den Tag des anderen.

---

## 9. Würfelduelle

Zwei Mitglieder derselben Quest setzen Aura gegeneinander. Jeder würfelt zwei
Würfel, die höhere Summe gewinnt den Topf.

| Regel | Wert |
|---|---|
| Mindesteinsatz | 10 Aura |
| Höchsteinsatz | 25 % der eigenen Quest-Aura |
| Topf | Einsatz × 2 |
| Annahmefrist | 48 Stunden |

Der Einsatz des Herausforderers wird sofort **einbehalten** (Escrow) — man kann
nicht mehr setzen, als man hat, und nicht nachträglich abhauen. Die Würfel
fallen auf dem Server; die App zeigt das Ergebnis nur an. Unbeantwortete Duelle
löst der stündliche Cron-Job auf und gibt den Einsatz zurück.

Die 25-%-Grenze verhindert, dass ein einziges Duell eine Quest entscheidet.

---

## 10. Soziales

### Freundschaften

Anfragen mit Bestätigung in beide Richtungen. Freundesliste mit
Benutzernamen-Suche.

### Quest-Einladungen

Freunde lassen sich direkt beim Anlegen einer Quest oder später einladen.
Einladungen erscheinen im Freundes-Tab und werden angenommen oder abgelehnt.

### Pokes — Anstupsen

Ein Mitglied, das heute noch nichts eingetragen hat, lässt sich anstupsen. Der
Empfänger kann mit einem Emoji zurückreagieren. Ein Poke pro Tag und Person.

*Die freundliche Variante des Drucks — für alle, denen ein Blackout zu grob ist.*

### Party-Ansicht

In jeder Quest sieht man alle Mitglieder mit Avatar, Titeln, Aura-Stand,
Fortschrittsbalken und **dem Zeitpunkt der letzten Aktivität** („Last check-in:
Today, 08:14"). In Team-Modi zusätzlich die Teamzugehörigkeit.

### Head-to-Head — Bilanz gegen jeden Freund

Tippt man einen Freund an, öffnet sich die persönliche Bilanz: Check-ins,
Aura und Duellergebnisse — **ausschließlich über gemeinsame Quests gerechnet**.
Wer nur mehr Quests beitritt, sieht dadurch nicht besser aus.

**Verkaufswinkel:** Zwischen dir und jedem Freund läuft eine ewige Tabelle mit.
Niemand musste sie anlegen, sie zählt sich selbst.

---

## 11. Rückblick und Statistik

### Wochenrückblick

Jeden Montag eine Karte auf der Startseite mit der abgelaufenen Woche:
Check-ins, aktive Tage, Aura-Bilanz, bester Tag, Strikes, abgeschlossene Quests
und Duellbilanz — plus dem Vergleich zur Vorwoche. Sie erscheint einmal pro
Woche und verschwindet danach, bleibt also ein Ereignis und wird kein Möbel.

### Das Jahr in Kästchen

Eine Heatmap über 53 Wochen im Profil, die jeden Tag als Kästchen zeigt, je
nach Aktivität eingefärbt, automatisch zum heutigen Tag gescrollt.

*Der Blick, der ohne Worte zeigt, ob das Jahr gelaufen ist oder nicht.*

### Spielerstatistik

Beigetretene Quests, aktive Quests, Check-ins gesamt, Aura gesamt, besessene
Ausrüstung, Anzahl Freunde.

### Trophäenraum

Abgeschlossene Quests als Sammlung, standardmäßig eingeklappt. Einzelne
Trophäen lassen sich ausblenden.

### Aktivitätsliste je Quest

Chronologie aus sechs Quellen: Abrechnungsereignisse, Check-ins,
Fortschrittseinträge, Shop-Käufe, Roasts und Blackouts. Zeigt zunächst die
letzten Einträge, per „mehr" den vollen Verlauf.

---

## 12. Zuschauer-Modus

Wer eine Quest verliert, **fliegt nicht raus**. Er bleibt Mitglied, sieht alles
weiter und ist für alle sichtbar als ausgeschieden markiert (☠️ OUT).

Was er nicht mehr kann, und zwar serverseitig gesperrt:

- einchecken
- Fortschritt eintragen oder bearbeiten
- Slips melden oder zurücknehmen
- Shop-Gegenstände einsetzen
- das Ergebnis in irgendeiner Form beeinflussen

Freiwillig verlassen darf er jederzeit.

**Verkaufswinkel:** Rausfliegen und aus der Gruppe verschwinden sind zwei
verschiedene Dinge. Wer ausscheidet, bleibt Teil der Geschichte — und schaut
zu, wie sie ausgeht.

---

## 13. Sicherheit und Fairness

Das ist kein Nebenschauplatz, sondern die Voraussetzung dafür, dass
Wettbewerb überhaupt Sinn ergibt.

### Serverseitige Durchsetzung

**Jede** spielrelevante Regel liegt in der Datenbank, nicht in der App:

- Check-ins, Fortschritt, Slips laufen über abgesicherte Server-Funktionen
- Datenbank-Trigger weisen Einträge während eines Blackouts ab
- Trigger weisen Einträge an inaktiven Wochentagen ab
- Ausgeschiedene Teilnehmer werden bei jeder Aktion geprüft
- Würfel, Diebstahls-Chancen und Abrechnungen passieren serverseitig

Ein veränderter Client kann nichts erzwingen, was die Datenbank nicht erlaubt.
Row Level Security regelt zusätzlich, wer welche Zeile überhaupt sieht.

### Schutz vor Mitspielern

| Funktion | Wirkung |
|---|---|
| **Blockieren** | Verhindert wechselseitig jede Interaktion — Angriffe, Pokes, Einladungen |
| **Melden** | Meldung mit Grund und Beschreibung, optional an eine Quest gekoppelt |
| **Quest verlassen** | Jederzeit, auch als Zuschauer |

### Datenhoheit

| Funktion | Wirkung |
|---|---|
| **Statistik zurücksetzen** | Löscht Check-ins und Käufe, setzt Aura auf 0 |
| **Konto löschen** | Vollständige Löschung; eigene Quests gehen an ein anderes Mitglied über, Quests ohne weitere Mitglieder werden gelöscht |

Die gesamte Infrastruktur läuft **selbst gehostet** auf eigener Hardware. Keine
Nutzerdaten bei Dritten, kein Tracking, keine Werbe-SDKs.

**Verkaufswinkel:** Deine Daten liegen auf einem Gerät, das du anfassen kannst.

---

## 14. Personalisierung

### Drei Designsysteme, je hell und dunkel

| Thema | Charakter |
|---|---|
| **Kinetic Neo-Brutalist** | Harte Kanten, kräftige Flächen, laut |
| **Editorial Growth** | Ruhig, typografisch, wie ein gutes Magazin |
| **Auralis** | Reduziert, dunkel, konzentriert |

Sechs vollständige Farbpaletten. Alle Text-Hintergrund-Kombinationen sind auf
Kontrast geprüft und erfüllen die WCAG-Anforderungen — der schwächste Wert im
gesamten System liegt bei 4,51:1.

### Avatare

Emoji statt Fotoupload. Kein Bilderhosting, keine Moderation, keine
Datenschutzfragen — und es passt zum Ton der App.

---

## 15. Konto und Zugang

- Registrierung mit E-Mail und Passwort
- **Bestätigung der Mailadresse verpflichtend** — per sechsstelligem Code
  oder Link
- **Passwort vergessen** — ebenfalls per sechsstelligem Code
- Google-Anmeldung vorbereitet
- Mailversand über eigene Domain, DKIM-signiert, mit SPF und DMARC

Der Code-Weg ist bewusst der Hauptweg: Er funktioniert unabhängig davon, auf
welchem Gerät die Mail gelesen wird. Ein Bestätigungslink erreicht die App nur
auf dem Telefon selbst.

Aus Sicherheitsgründen meldet die Passwort-Zurücksetzung immer Erfolg — auch
für Adressen ohne Konto. Sonst wäre der Knopf ein Werkzeug, um herauszufinden,
wer registriert ist.

---

## 16. Technischer Unterbau

| Ebene | Technik |
|---|---|
| App | Flutter 3.44, Riverpod, go_router |
| Backend | Supabase, selbst gehostet auf NAS |
| Datenbank | PostgreSQL mit `pg_cron` |
| Logik | 47 abgesicherte Server-Funktionen, Trigger, Row Level Security |
| Echtzeit | Postgres-Änderungen auf 8 Tabellen, plus 45-Sekunden-Fallback |
| Erreichbarkeit | Cloudflare Tunnel, HTTPS, **kein offener Port am Router** |
| Mail | Resend über eigene Domain, EU-Region |

### Echtzeit-Verhalten

Die App abonniert Änderungen an Check-ins, Fortschritt, Slips,
Abrechnungsereignissen, Duellen, Raubzügen, Roasts, Blackouts und Pokes. Was ein
Mitspieler tut, erscheint ohne Neuladen. Ein Wiederholungsintervall von 45
Sekunden fängt verlorene Verbindungen ab.

---

## 17. Marketing-Baukasten

### Positionierung

**Kategorie:** Sozialer Habit-Tracker mit Spielmechanik.

**Abgrenzung nach oben** (Habitica, Finch): Dort ist das Spiel eine Verkleidung
für Einzelarbeit. Hier ist das Spiel der Punkt, und es braucht andere Menschen.

**Abgrenzung nach unten** (Streaks, Loop, Apple Health): Dort protokolliert man.
Hier tritt man an.

**Der eine Satz, der die Kategorie erklärt:**
> Der erste Habit-Tracker, in dem deine Freunde dich sabotieren dürfen.

### Zielgruppen

| Gruppe | Warum es zieht | Aufhänger |
|---|---|---|
| Freundeskreise mit gemeinsamem Vorsatz | Nebeneinander-Tracken langweilt nach zwei Wochen | „Wer zuerst aufgibt, zahlt." |
| Fitness-Duos | Progress-Quests bilden echte Trainingsziele ab | „100 Liegestütze. Er hat 60. Du hast 90." |
| Menschen, die etwas lassen wollen | Avoid-Quests gibt es fast nirgends | „Gewinnen, indem du nichts tust." |
| WGs, Teams, Kurse | CO-OP und Team Battle skalieren auf Gruppen | „Einer verpennt, alle zahlen." |
| Datenschutzbewusste | Selbst gehostet, kein Tracking | „Läuft auf einem Rechner, den du anfassen kannst." |

### Feature zu Nutzen

| Feature | Was man nennt |
|---|---|
| Blackout | Zwei Stunden Funkstille — zur Tageszeit seiner Wahl. |
| Aura Heist | Sein nächster Check-in zahlt auf dein Konto ein. |
| Targeted Roast | 297 Sprüche. Einer davon klebt jetzt auf seinem Bildschirm. |
| Avoid-Quests | Der Tracker, der auch zählt, was du gelassen hast. |
| Aktive Wochentage | Ruhetage, die nicht bestraft werden. |
| Zuschauer-Modus | Raus heißt nicht weg. |
| Head-to-Head | Die Tabelle, die sich selbst führt. |
| Wochenrückblick | Montags acht Sekunden Wahrheit. |
| Jahr in Kästchen | Ein Jahr Disziplin auf einen Blick. |
| Würfelduell | Aura setzen. Zwei Würfel. Kein Zurück. |
| Serverseitige Regeln | Schummeln ist nicht schwer — es ist unmöglich. |
| Vier Modi | Dieselbe Gewohnheit, vier verschiedene Spiele. |

### Textbausteine

**Store-Kurzbeschreibung (unter 80 Zeichen):**
> Gewohnheiten als Wettkampf. Aura verdienen, Freunde sabotieren.

**Store-Langtext (Einstieg):**
> Du kennst das: Am 3. Januar seid ihr zu viert im Fitnessstudio, am 20. bist
> du allein. Aura Quest ändert nicht deine Motivation — es ändert, was
> Aufgeben kostet.
>
> Jeder erledigte Tag bringt Aura. Jeder verpasste kostet welche. Und mit dem,
> was du sammelst, kaufst du dir entweder Schutz — oder du sperrst deinen
> besten Freund zwei Stunden lang aus, genau dann, wenn er trainieren wollte.

**Drei Zeilen für einen Trailer:**
> 1. „Ihr habt euch alle etwas vorgenommen."
> 2. „Einer von euch wird zuerst aufgeben."
> 3. „Sorg dafür, dass er es nicht ist."

**Der ehrliche Satz** — für Leute, die Marketing riechen:
> Es ist ein Habit-Tracker. Der Unterschied ist, dass er Spaß macht, weil deine
> Freunde drin sind und dir das Leben schwer machen dürfen.

### Was man **nicht** behaupten sollte

Ehrlichkeit hält länger als eine Kampagne. Diese Dinge kann die App heute nicht:

- keine Wearable- oder Health-Anbindung (alles wird von Hand eingetragen)
- **keine Push-Benachrichtigungen** — die App muss geöffnet werden, damit man
  von Angriffen, Pokes oder Einladungen erfährt
- ausgeliefert wird für Android und iOS; Web und Desktop sind nur
  Flutter-Gerüst und ungetestet
- keine Foto-Avatare, keine Chat-Funktion
- keine Sprachen außer Englisch

---

## 18. Bekannte Lücken und Grenzen

Ehrliche Bestandsaufnahme, damit niemand etwas bewirbt oder einplant, was es
nicht gibt.

### Push-Benachrichtigungen fehlen

Die größte Lücke im Spielgefühl. Ein Blackout, ein Raubzug oder ein Duell
entfaltet seine Wirkung erst, wenn das Opfer davon erfährt — heute erst beim
nächsten Öffnen der App. Solange das so ist, verlieren die Angriffs-Mechaniken
einen Teil ihrer Schärfe.

### Betrieb

- **Keine Datensicherung eingerichtet.** In der Datenbank stehen echte Konten
  und Spielstände, es existiert kein Abzug. Der dringendste offene Punkt.
- **Studio erreichbar.** Die Supabase-Oberfläche hängt am selben öffentlichen
  Hostnamen, geschützt nur durch Basic-Auth.
- **Keine Rechtstexte.** Datenschutzerklärung und Impressum fehlen; beides ist
  Voraussetzung, bevor die App an Dritte geht.
- **Standard-App-Icon.** Noch das Flutter-Logo.
- **Kein Release-Keystore.** Ohne ihn keine Store-Veröffentlichung.

### Ungeprüft

- Verhalten der Wochentagsauswahl über einen echten Wochenwechsel hinweg
- Wochenrückblick über einen Jahreswechsel
- Live-Abgleich eines Blackouts zwischen zwei Geräten gleichzeitig

---

## Anhang: Zahlen auf einen Blick

| | |
|---|---|
| Quest-Typen | 3 |
| Quest-Modi | 4 |
| Shop-Gegenstände | 8 pro Quest |
| Angriffs-Mechaniken | 3 |
| Sprüche | 297 |
| Designsysteme | 3 (je hell und dunkel = 6 Paletten) |
| Datenbank-Tabellen | 18 |
| Server-Funktionen | 47 |
| Echtzeit-Tabellen | 8 |
| Geringster Kontrastwert | 4,51:1 (WCAG AA erfüllt) |
