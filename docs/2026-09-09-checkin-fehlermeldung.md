# Falsche Fehlermeldung nach erfolgreichem Check-in

Auf Emulator 5554 mit einer temporären NAS-Testquest reproduziert:
`logCheckIn` bestätigt +100 Aura, anschließend zeigt Home trotzdem
„Could not complete this check-in. Please try again.“.

Der Stacktrace zeigt `Bad state: Future already completed` im
`CheckInController`. Die automatische Aktualisierung kann den letzten
Beobachter des automatisch entsorgten Controllers entfernen, bevor die
HTTP-Antwort verarbeitet ist. Der folgende Zustandswechsel schlägt dann fehl.
Die Datenbankbuchung war bereits erfolgreich und wird nicht wiederholt.

Der Controller bleibt jetzt mit einem zeitlich auf die laufende Operation
begrenzten `keepAlive` bis zum Abschluss erhalten. Danach wird die Freigabe
auch bei Fehlern im `finally`-Block geschlossen. Die Prüfung des aktuellen
Kontos erfolgt weiterhin direkt an der Auth-Quelle, jetzt über das vorhandene
Repository. Unerwartete Home-Fehler enthalten einen Debug-Stacktrace.

Prüfung:

- Neuer Regressionstest reproduziert vor der Korrektur denselben Fehler und
  bestätigt danach +100 Aura sowie die anschließende Freigabe des Controllers.
- Zusätzliche Tests: echte Serverablehnung bleibt ein Fehler; eine verspätete
  Antwort nach Abmeldung wird nicht als Erfolg für ein anderes Konto behandelt.
- Diese drei Tests und zwölf bestehende Home-Tests bestehen; Analyse ohne Befunde.
- Neuer Debug-Build auf beiden Emulatoren installiert. Derselbe zuvor fehlerhafte
  Emulator-Ablauf zeigt nun „check-in confirmed“ / „+100 Aura confirmed“.
- NAS-Verifikation: genau ein Check-in, Guthaben 500 → 600. Testquests und
  ausschließlich deren Test-XP anschließend entfernt. Bestehende Nutzerquests
  und Check-ins bleiben erhalten. Keine Schemaänderung erforderlich.
