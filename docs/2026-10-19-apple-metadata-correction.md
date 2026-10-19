# Apple: Korrektur zu Guideline 2.3.10

Apple hat Version **1.0.2 (16)** am **19. Oktober 2026** auf einem
**iPad Air 11 Zoll (M3)** geprüft und wegen eines Android-Verweises in der
App-Beschreibung abgelehnt. Übermittlung:
`eaa11e08-627f-4c8e-8e4c-3b67607eb19f`.

## Gespeicherte Änderung

Der lesende API-Abgleich vom 19. Oktober um **13:36:59 UTC** bestätigt Build 16,
Status `REJECTED`, manuelle Veröffentlichung und genau einen Plattformverweis in
den vorhandenen deutschen und englischen Store-Metadaten:

> Android and iPhone players share the same quests.

Der Satz steht in der englischen Beschreibung unter **BETTER WITH FRIENDS**.
Die deutsche Beschreibung sowie Werbetexte, Keywords, Versionshinweise und URLs
beider Sprachen enthalten keinen Android-, Google-Play- oder Play-Store-Verweis.
Ausgangsfassung: `build/audit/apple-metadata19-before.json`.

Die englische Store-Vorlage und die bei Apple gespeicherte Beschreibung ersetzen
den Satz durch:

> Build better habits together and cheer each other on.

Die übrige Beschreibung und das gemeinsame Spielen mit Freunden bleiben davon
unberührt. Geändert wurden ausschließlich die Store-Metadaten; App-Code,
Backend, Build 16, Altersfreigabe und die bisher gewählte Veröffentlichungsart
wurden nicht bearbeitet.

## Aktueller Stand

Nach der erneuten Anmeldung des Nutzers wurde die englische Beschreibung im
Browser korrigiert und bei Apple gespeichert. Der unabhängige lesende API-Abgleich
am **19. Oktober um 14:20:46 UTC** bestätigt für **de-DE und en-US** keine weiteren
Android-, Google-Play- oder Play-Store-Verweise in Beschreibungen, Werbetexten,
Keywords, Versionshinweisen und URLs. Nachweis:
`build/audit/apple-metadata19-verified.json`.

Am **19. Oktober 2026 um 16:21 Uhr Europe/Berlin** wurde derselbe Build
**1.0.2 (16)** erneut eingereicht. App Store Connect zeigt für die Übermittlung
und das übermittelte Element ausdrücklich **Warten auf Prüfung**. Die
Übermittlungskennung bleibt `eaa11e08-627f-4c8e-8e4c-3b67607eb19f`.

Bildnachweis:
`build/audit/proofs/apple-build-16-metadata-waiting-for-review-2026-10-19.png`.

Apple hat die App noch nicht genehmigt oder öffentlich veröffentlicht. Die
gespeicherte Veröffentlichungsart bleibt **manuell**. Der vorhandene
Entwickler-API-Schlüssel wurde nur zum Lesen verwendet; keine Schlüssel oder
Rollen erweitert. Keine zusätzliche Antwort an App Review versendet. Für diese
Textkorrektur wurden keine App-, NAS- oder Google-Play-Änderungen vorgenommen.
