# Paket 1: verständliche Balance und dauerhafte XP

Umsetzung: 08.09.2026; Abschlussprüfung: 09.09.2026. NAS-Datenbank migriert, Debug-App auf beiden Emulatoren
installiert. Paket 2 bleibt enthalten. Noch kein neuer Commit/Push.

## Vorlagen und Preise

| Vorlage | Aura je Einheit | Strafe je verpasster Periode | Erlaubte Fehler | Angriffe |
|---|---:|---:|---:|---|
| Chill | 100 | −10 | 5 | aus |
| Classic, Standard | 100 | −25 | 3 | begrenzt |
| Chaos | 100 | −50 | 1 | begrenzt |

Classic endet beim **vierten** Fehler. Eigene Werte stehen unter „Advanced“ /
„Use custom balance“. Die bestehende Verlustregel bleibt: Eine gescheiterte
normale Quest behält ein Viertel der Aura nach der letzten Strafe. Im Formular
wird das ausdrücklich erklärt. Last Standing behält seine Eliminierungsregeln.
Permanente XP bleiben in beiden Fällen.

Bestehende Quests behalten Belohnung, Strafe und Fehlergrenze. Shoppreise werden
an deren Basisbelohnung angepasst. Guthaben und vorhandene Käufe bleiben erhalten.

| Artikel | Basisbelohnungen | Classic-Preis |
|---|---:|---:|
| Heist, 25 / 50 / 75 % | 0,20 / 0,40 / 0,60 | 20 / 40 / 60 |
| Aura Ward | 0,25 | 25 |
| Roast, 3 / 5 Sekunden | 0,50 / 0,75 | 50 / 75 |
| Double Down | 0,80 | 80 |
| Streak Shield | 1 | 100 |
| Blackout | 1,50 | 150 |
| Title Badge / Strike Repair | 2 | 200 |
| Aura Lord | 10 | 1000 |

Preise werden auf ganze Aura aufgerundet, mindestens 1. Basisbelohnung 0 sperrt
Käufe und Angriffe. Sehr kleine eigene Belohnungen können dadurch relativ teuer
sein: Bei 1 Aura Basis sind alle Heist-Stufen erwartbar verlustreich.
Streak Shield verhindert einen Strike, nicht die Aura-Strafe; die Beschreibung
sagt das jetzt ausdrücklich. Titel können serverseitig nur einmal gekauft werden.

## Dauerhafte XP

100 XP pro bestätigter Einheit, höchstens 500 je Konto und UTC-Aktivitätstag.
Teilfortschritt zählt erst beim erfüllten Ziel; Avoid-Erfolge bei Bestätigung
durch die Abrechnung. Ein leerer Resetstand ist Level 0; danach gilt die
bisherige Skala mit Level 1 ab den ersten verdienten XP und je 500 XP pro Stufe.
Das Profil zeigt XP, Level und verbleibende XP zum nächsten Level.

XP sind unabhängig von Aura-Werten, Multiplikatoren, Käufen und Duellen.
Verlassen/Löschen einer Quest sowie „Reset stats“ löschen keine XP.
Account-Löschung entfernt auch dessen XP. Das private, serververwaltete Ledger
verhindert Doppelvergaben auch nach Löschen/Neuanlegen eines Check-ins.
Clients haben ausschließlich Leserechte auf eigene Einträge. Neue Quests dürfen
nicht rückdatiert werden; Bestätigungen vor Erstellung von Quest/Mitgliedschaft
erzeugen keine neuen XP.

Die neun vorhandenen Check-ins wurden als 900 XP übernommen: 600 bei brenzel.ai,
300 bei bra_b. Nicht mehr vorhandene Historie wird nicht rekonstruiert.

## Angriffe und Comeback

Maximal drei ausgehende Angriffe pro Konto und UTC-Tag, zusammen über alle
Quests sowie Heists, Roasts und Blackouts. Höchstens ein erfolgreicher eingehender
Heist pro Ziel/UTC-Tag und kein Stapeln wartender Treffer. Auch alte wartende
Heists können bei Auszahlung nicht mehrmals am selben Tag stehlen.

Treffer verfallen nach 24 Stunden und stehlen höchstens eine Basisbelohnung.
Multiplikator-Bonus und XP bleiben beim Opfer. Aura Ward blockiert den nächsten
auszahlbaren Heist in dieser Quest und wird einmal verbraucht. Abwehr und Verfall
erhalten Aktivitätsmeldungen. Versuchskosten werden bei Fehlschlag, Schutz oder
Verfall nicht erstattet. Chill sperrt Angriffe; Heists/Blackouts gibt es nicht
für Avoid-Quests. Alle Tagesgrenzen sind serverseitig gegen gleichzeitige Anfragen
geschützt.

Home zeigt nach abgerechneten Fehlern ein Comeback-Ziel zur nächsten geplanten
Einheit. Ruhetage und verlorene Avoid-Perioden werden berücksichtigt. Bestätigung
entfernt das Ziel auch bei erreichtem XP-Tageslimit. Ausgeschiedene Spieler sehen
den Hinweis auf eine neue Quest und erhaltene XP.

## Prüfung und Bereitstellung

- 93 bestehende Flutter-Tests und 7 neue Balance-/Formular-Tests bestanden.
- 68 bestehende pgTAP-Tests und 54 neue Balance-Tests bestanden.
- Gleichzeitige Bestätigungen halten das XP-Limit ein; gleichzeitige Angriffe
  verbrauchen den letzten Tagesplatz und Aura nur einmal.
- PL/pgSQL-Schema ohne Fehler; `flutter analyze` ohne Befunde; Debug-APK gebaut.
- Bekannte Gradle-Vorwarnung zum künftigen Built-in-Kotlin-Support von
  unifiedpush_android/webcrypto; kein Buildfehler.
- Vollständige NAS-Kopie separat geprüft: Migration, XP-Backfill und unveränderte
  Aura/Historie bestätigt. Netzwerk und aktive Cron-Jobs waren ausgeschaltet.
- Emulator 5554: Classic erstellt, +100 Aura/+100 XP, Ward für 25 Aura gekauft;
  700 XP/Level 2 trotz gesunkenem Guthaben erhalten.
- Emulator 5556: Chill erstellt, Angriffe ausgeblendet; synthetischen Fehler
  vorbereitet, Comeback sichtbar, nächste Bestätigung entfernt das Ziel und
  erhöht XP von 300 auf 400.
- Beide UI-Fixtures einschließlich ausschließlich ihrer Test-XP entfernt.
  Danach wieder 5 Quests, 2 Mitgliedschaften, 9 Check-ins, 400 Aura und 900 XP.

Alle DB-Tests liefen auf dem **NAS**, nicht in lokalem Docker. Beide zusätzlichen
Testcontainer einschließlich der NAS-Kopie wurden entfernt. Am 09.09. wurde
der komplette Migrationslauf nochmals aus einem frischen NAS-Testcontainer
geprüft; Schema, 54 Balance-Tests und beide Paralleltests bestanden. Der
Teststarter wartet auf TCP-Bereitschaft des endgültigen PostgreSQL-Prozesses,
damit er nicht versehentlich den temporären Bootstrap-Prozess verwendet.
Der letzte Build einschließlich der Erklärung zur Aura-Verlustregel wurde auf
beiden Emulatoren erneut installiert. Inzwischen neu angelegte Nutzer-Testquests
und Check-ins wurden nicht verändert; die obigen Datenzahlen dokumentieren den
abgeschlossenen Fixture-Abbau vom 08.09.

Migration: `20260908121725_fair_balance_and_permanent_xp.sql`, zehnter Eintrag
im geprüften NAS-Ledger. Backup vor Änderung:
`/volume2/Datenbanken/AuraQuest/backups/balance-before-20260908173550.dump`.

## Simulation und weitere Spieltests

`dart run scripts/simulate_balance.dart`, Seed 20260908, 100.000 Versuche je
Szenario, Preise direkt aus dem App-Modell. Classic-Heist-Erwartungswerte vor
Abwehr/Verfall: **+5 / +10 / +15 Aura**, alter Einstieg **−125 Aura**.
Simulation: +5,034 / +10,001 / +14,926.

Bei unabhängiger 90-%-Erfolgswahrscheinlichkeit je Tag schaffen ohne Shopitems
30 Tage etwa 92,7 % der Chill-, 64,7 % der Classic- und 18,4 % der Chaos-Läufe.
Das ist keine Vorhersage von Nutzerbindung. Laufzeiten, Ruhetage, Schutz und
tatsächliches Verhalten brauchen weitere Spieltests. Classic bleibt bewusst
der angeforderte erste Testwert; die Balance ist noch nicht abschließend validiert.
