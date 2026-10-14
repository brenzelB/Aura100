# Aura Quest: Was vor dem öffentlichen Apple-Start noch fehlt

Stand: 14. Oktober 2026. Die App ist noch nicht öffentlich veröffentlicht und
wurde noch nicht zur App Review eingereicht.

Die [erneute Prüfung vom 14. Oktober](2026-10-14-apple-launch-completion.md)
bestätigt den NAS-Stand, die Backend-Tests und den normalen Review-Zugang.
Neu ist die von Apple verlangte Lizenzvereinbarung **LYL260 vom 13. Oktober**.
Sie wurde nach ausdrücklicher Freigabe am **14. Oktober angenommen** und die
gespeicherte Annahme nach Neuladen bestätigt. Dieser Schritt ist erledigt.

## Bereits vorbereitet

- Apple-Entwicklerteam, App-ID, Signierung und automatischer Upload sind eingerichtet.
- Build **1.0.2 (10)** wurde erfolgreich signiert. Die sichtbare Screenshot-Prüfung
  fand danach einen Kontrastfehler der Activity-Karte beim Wechsel ins dunkle Theme.
  Er ist korrigiert; alle **376 Flutter-Tests** einschließlich der unveränderten
  Theme-Goldens sind erfolgreich. Der neue signierte Build **1.0.2 (11)** hat
  alle vier Release-Prüfungen bestanden.
- Acht geprüfte Apple-Simulatorbilder sind ausgewählt: vier für iPhone und
  vier für iPad, einschließlich Editorial Light/Dark. Sie zeigen Produktions-
  Ansichten mit lokalen Beispielquests. Die neue iPhone-Dark-Aufnahme hat eine
  lesbare Statusleiste: Das Aufnahmeprogramm verwendet jetzt denselben expliziten
  Modus wie die echte App. Die reale Geräteabnahme bleibt trotzdem erforderlich.
  Die Auswahl ist für Deutsch und Englisch (USA) im Store-Entwurf gespeichert
  und nach Neuladen geprüft.
  Die Dateien liegen auch auf dem Desktop unter `AuraQuest_Store_Bilder/Apple_iOS`.
- Der Store-Eintrag enthält deutsche und englische Texte, das Copyright,
  die Datenschutz-URL, den kostenlosen Preis und 175 Länder für den späteren Start.
- Die Kontolöschung mit vorherigem Apple-Widerruf ist implementiert. Ihre
  Backend-Tests und alle acht SQL-Prüfsuiten mit einem wiederhergestellten
  NAS-Backup waren erfolgreich. Auf der aktiven Datenbank ist sie noch nicht aktiviert.

## Bereits angefragte Bestätigungen

| Entscheidung | Wozu sie benötigt wird |
| --- | --- |
| Dedizierten Schlüssel „Aura Quest Account Revocation“ erstellen; ausschließlich Sign in with Apple für diese App | Damit der NAS bei einer Kontolöschung die Apple-Autorisierung widerrufen kann. Der private Schlüssel bleibt geschützt auf dem NAS. |
| Das vorbereitete normale Testkonto auraquest-review@brenzel.uk samt Passwort ausschließlich in Apples App-Review-Zugangsfeldern hinterlegen | Damit Apple die App ohne Zugang zum Betreiberkonto prüfen kann. Der öffentliche und interne Login sind am 14. Oktober erneut bestätigt. |
| Die vorhandenen Apple-Kontaktdaten für App Review bestätigen | Im Apple-Konto ist bereits eine Telefonnummer vorhanden. Ihre Verwendung für Rückfragen wartet noch auf Bestätigung. |
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
6. Privacy, Altersfreigabe, Review-Zugang und Kontakt vollständig speichern.

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
