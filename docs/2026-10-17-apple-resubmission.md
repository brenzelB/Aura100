# Apple: Build 16 erneut eingereicht

Am **17. Oktober 2026 um 11:28 Uhr Europe/Berlin** bestätigte App Store Connect
die erneute Einreichung von **Aura Quest 1.0.2 (16)** mit **Warten auf Prüfung**.
Apple verwendet weiterhin Übermittlung
`eaa11e08-627f-4c8e-8e4c-3b67607eb19f`.

## Gespeicherte Änderungen

- Der alte Build 14 wurde durch Build 16 ersetzt, Build-ID
  `b1e8af43-6025-4013-9de5-df59e9937348`. Build 16 enthält ausschließlich englische
  Ego-Duell-Sprüche und die kostenlose Schere-Stein-Papier-Mechanik ohne
  Aura-/XP-Einsätze, Gewinne oder Transfers. Die signierte IPA und CI sind in
  `docs/2026-10-17-ego-duels.md` dokumentiert.
- Simuliertes Glücksspiel: **Nie**. Alle übrigen Fragebogen-Antworten und die
  bestehende Anhebung auf **16+** bleiben erhalten. Apple zeigt 16+ für
  173 Länder/Regionen, einschließlich Australien, sowie regionale Entsprechungen.
- Deutsche und englische Store-Beschreibungen wurden korrigiert: keine Werbung
  mehr für Würfelwetten, Aura Heist oder den ausgemusterten Aura Ward. Die
  Beschreibungen erklären kostenlose Ego-Duelle, drei Rundensiege und den
  Verliererspruch bei unveränderter Aura und XP.
- Englische Review-Hinweise erklären ausdrücklich die Entfernung der alten
  Wetten und Server-Endpunkte. SHA256 des bei Apple gespeicherten Hinweistexts:
  `fb3a1cf761025b20fe10ff89c37368c213fb4bf3e5488e8c6eb3f180815b7dac`.
- Vorhandene Review-Zugangsdaten und Kontaktdaten wurden beibehalten.
  Öffentlicher Test-Login, drei Beispielquests und die neuen Spiel-API-Schutzprüfungen
  waren am 17. Oktober um **09:19:30 UTC** erfolgreich. Keine Zugangsdaten in den
  Prüfprotokollen oder diesem Dokument.

Der Entwickler-API-Schlüssel darf die Review-Metadaten nicht ändern (HTTP 403).
Deshalb wurden die Änderungen und die erneute Übermittlung im angemeldeten
Apple-Browser vorgenommen; keine Schlüssel oder Rollen erweitert. Die gespeicherte
Build-Zuordnung, Review-Hinweise und beide Beschreibungssprachen wurden vor dem
Absenden unabhängig per lesender API geprüft.

## Nachweise und verbleibender Schritt

- `build/audit/apple-build16-review-preparation.json`: gespeicherter Build 16,
  übereinstimmende Review-Hinweise, de-DE und en-US bestätigt.
- `build/audit/proofs/apple-build-16-waiting-for-review-2026-10-17.png`:
  Apples tatsächlicher Status **Warten auf Prüfung**, Build 16 und neues Datum.

Apple hat die App noch nicht genehmigt. Die Veröffentlichung bleibt **manuell**;
die erneute Prüfung veröffentlicht die App nicht automatisch. Die Länderauswahl
wurde in diesem Schritt nicht bearbeitet; die bestätigte Nutzerpräferenz für den
ersten Start ist weiterhin ohne Frankreich. Der echte
Zwei-Geräte-Spieltest wurde nicht als durchgeführt behauptet; der Nutzer hat die
erneute Einreichung ausdrücklich angefordert. Keine Änderung an App-Code, NAS,
TestFlight-Testern oder Google Play in diesem Schritt.
