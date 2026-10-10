# Aura Quest: Was vor dem öffentlichen Apple-Start noch fehlt

Stand: 10. Oktober 2026. Die App ist noch nicht öffentlich veröffentlicht und
wurde noch nicht zur App Review eingereicht.

## Bereits vorbereitet

- Apple-Entwicklerteam, App-ID, Signierung und automatischer Upload sind eingerichtet.
- Build **1.0.2 (10)** wurde als signierte iOS-IPA und Android-AAB erstellt.
  Die Release-Prüfungen und alle 375 Flutter-Tests waren erfolgreich.
- Der Store-Eintrag enthält deutsche und englische Texte, das Copyright,
  die Datenschutz-URL, den kostenlosen Preis und 175 Länder für den späteren Start.
- Die Kontolöschung mit vorherigem Apple-Widerruf ist implementiert. Ihre
  Backend-Tests und alle acht SQL-Prüfsuiten mit einem wiederhergestellten
  NAS-Backup waren erfolgreich. Auf der aktiven Datenbank ist sie noch nicht aktiviert.

## Bereits angefragte Bestätigungen

| Entscheidung | Wozu sie benötigt wird |
| --- | --- |
| Dedizierten Schlüssel „Aura Quest Account Revocation“ erstellen; ausschließlich Sign in with Apple für diese App | Damit der NAS bei einer Kontolöschung die Apple-Autorisierung widerrufen kann. Der private Schlüssel bleibt geschützt auf dem NAS. |
| Das vorbereitete normale Testkonto samt Passwort ausschließlich in Apples App-Review-Zugangsfeldern hinterlegen | Damit Apple die App ohne Zugang zum Betreiberkonto prüfen kann. |
| Kontakt für App Review bestätigen und eine erreichbare Telefonnummer nennen | Apple verlangt vollständige Kontaktdaten für Rückfragen. |
| Datenschutzangaben und die aktualisierte öffentliche Datenschutzerklärung bestätigen | Die vollständige Zuordnung der 13 Datentypen liegt in `deploy/store/APP_PRIVACY_APPLE.md`. |
| Altersfragebogen und Rechte an den dargestellten Inhalten bestätigen | Der Vorschlag liegt in `deploy/store/APPLE_AGE_AND_CONTENT_DECLARATIONS.md`; Apples tatsächliche Einstufung wird danach geprüft. |

Für Schlüsselkonfiguration und Datenschutzangaben hat die automatische
Freigabeprüfung das Speichern ohne ausdrückliche Bestätigung abgelehnt.
Diese Schritte wurden nicht ausgeführt.

## Technische Arbeiten nach diesen Bestätigungen

1. Apple-Schlüssel fertig erstellen und geschützt auf dem NAS einrichten.
2. Worker bereitstellen, Anmeldungsschutz und den vorhandenen Push-Worker prüfen.
3. Die erneut gesicherte und isoliert geprüfte Datenbankmigration aktivieren.
4. Die passende Datenschutzerklärung veröffentlichen und über die öffentliche URL prüfen.
5. Den finalen Build zu Apple hochladen und für den internen Gerätetest bereitstellen.
6. Echte iPhone-/iPad-Aufnahmen prüfen und in beiden Store-Sprachen hochladen.
7. Privacy, Altersfreigabe, Review-Zugang und Kontakt vollständig speichern.

## Gerätetest und weltweiter Vertrieb

Auf einem echten iPhone müssen Apple-Anmeldung, Konto-Widerruf bei Löschung,
Push bei gesperrtem Bildschirm und das Zusammenspielen mit Android geprüft werden.
Der vollständige Ablauf steht in `ios-testflight-acceptance.md`. Erfolgreiche
Builds oder Simulator-Bilder ersetzen diese Prüfung nicht.

Außerdem ist die Verschlüsselungs-Erklärung für den weltweiten Vertrieb offen.
Frankreich ist in der Länderauswahl enthalten; die dazu passenden Nachweise oder
eine ausdrücklich bestätigte andere Länderauswahl müssen vor der Einreichung
geklärt werden. Der technische Entwurf steht in
`deploy/store/APPLE_EXPORT_TECHNICAL_DRAFT.md`.

Wenn diese Punkte erledigt sind, wird die vollständige Version zur App Review
eingereicht. Erst nach Apples Freigabe kann sie öffentlich veröffentlicht werden.
