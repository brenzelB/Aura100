# Apple: Korrektur zu Guideline 2.3.10

Apple hat Version **1.0.2 (16)** am **19. Oktober 2026** auf einem
**iPad Air 11 Zoll (M3)** geprüft und wegen eines Android-Verweises in der
App-Beschreibung abgelehnt. Übermittlung:
`eaa11e08-627f-4c8e-8e4c-3b67607eb19f`.

## Vorbereitete Änderung

Der lesende API-Abgleich vom 19. Oktober um **13:36:59 UTC** bestätigt Build 16,
Status `REJECTED`, manuelle Veröffentlichung und genau einen Plattformverweis in
den vorhandenen deutschen und englischen Store-Metadaten:

> Android and iPhone players share the same quests.

Der Satz steht in der englischen Beschreibung unter **BETTER WITH FRIENDS**.
Die deutsche Beschreibung sowie Werbetexte, Keywords, Versionshinweise und URLs
beider Sprachen enthalten keinen Android-, Google-Play- oder Play-Store-Verweis.
Ausgangsfassung: `build/audit/apple-metadata19-before.json`.

Die lokale englische Store-Vorlage ersetzt den Satz durch:

> Build better habits together and cheer each other on.

Die übrige Beschreibung und das gemeinsame Spielen mit Freunden bleiben davon
unberührt. Es ist eine Änderung der Store-Metadaten vorbereitet; App-Code,
Backend, Build 16, Altersfreigabe und die bisher gewählte Veröffentlichungsart
werden nicht geändert.

## Aktueller Stand

**Nur lokal vorbereitet; noch nicht bei Apple gespeichert oder erneut eingereicht.**
Die vorhandene Chrome-Registerkarte ließ sich nicht verbinden. Eine frische
Registerkarte im selben Profil funktioniert, verlangt aber eine neue
Apple-Anmeldung. Der vorhandene Entwickler-API-Schlüssel darf Metadaten lesen;
seine fehlenden Schreibrechte sind aus dem vorherigen Vorgang bekannt und
werden nicht durch neue Schlüssel oder Rollen erweitert.

Nach der Anmeldung: englische Beschreibung korrigieren, beide Sprachen erneut
auf Plattformverweise prüfen, Änderung speichern und denselben Build 16 erneut
einreichen. Erfolg erst melden, wenn Apple **Warten auf Prüfung** bestätigt.
