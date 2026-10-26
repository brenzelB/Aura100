# Apple-Start: Stand 16. Oktober 2026

**1.0.2 (14) ist zur App Review eingereicht.** Apple bestätigt auf der
Übermittlungsdetailseite **Warten auf Prüfung**, übermittelt am **16. Oktober
2026 um 20:31 Uhr** durch Denis Brandt. Die App ist damit noch nicht genehmigt
und noch nicht öffentlich verfügbar. Die Veröffentlichung bleibt **manuell**;
Frankreich bleibt entsprechend der bestätigten Länderauswahl ausgeschlossen.

Der Nutzer bestätigt nach der ausdrücklichen Testaufforderung für Build 14:
„das hat wunderbar mit der google anmeldung funktioniert“. Damit sind Anmeldung
und automatisches Schließen des nativen iPhone-Fensters abgenommen. Der
fehlgeschlagene Schließversuch in Build 13 bleibt im Verlauf dokumentiert.
Die erfolgreiche Kontolöschung ist aus Nutzersicht bestätigt; weitere
Geräteprüfungen einschließlich des gesonderten Apple-Widerrufnachweises sind
weiterhin offen und werden nicht aus diesem Google-Test abgeleitet.

Unmittelbar vor der Einreichung wurden der öffentliche Review-Login und alle
drei Beispielquests erneut erfolgreich geprüft (18:30:39 UTC). Apples bereits
genehmigte Review-Zugangs-, Kontakt- und Hinweisfelder sind weiterhin ausgefüllt.
Build 13 wurde ausschließlich aus dem ungesendeten Entwurf und der
Versionszuordnung gelöst, Build 14 gespeichert und zur Prüfung hinzugefügt.
Nach der Validierung wurde **Zur Prüfung übermitteln** betätigt. Apple bestätigt
ein übermitteltes Element **1.0.2 (14)** und keinen verbleibenden Entwurf.

- Übermittlungskennung: `eaa11e08-627f-4c8e-8e4c-3b67607eb19f`.
- [Apple-Übermittlungsdetail](https://appstoreconnect.apple.com/apps/6821149239/distribution/reviewsubmissions/details/eaa11e08-627f-4c8e-8e4c-3b67607eb19f).
- Nachweis: `build/audit/proofs/apple-build-14-submitted-review-2026-10-16.png`.

## Abgeschlossen und geprüft

- Der Nutzer hat am 16. Oktober den dedizierten Apple-Schlüssel, den Review-Zugang
  ausschließlich für Apple und die verlinkten Datenschutz-/Alters-/Inhaltsangaben
  samt Veröffentlichung der Datenschutzerklärung ausdrücklich freigegeben.
- Schlüssel **Aura Quest Account Revocation**, ID `LBB29KAAMN`, Team `W558BUSST2`:
  ausschließlich Sign in with Apple für `com.auraquest.auraQuest`, ohne gruppierte
  weitere App-IDs. Auf dem NAS geschützt eingerichtet. Die lokale private Kopie
  ist Git-ignoriert und nur für den Eigentümer, SYSTEM und Administratoren lesbar;
  die identische Download-Kopie wurde nach Prüfsummenvergleich entfernt.
- Der Apple-Worker läuft auf dem NAS. GET ergibt 405, unauthentifizierte Löschung
  401. Der vorhandene Push-Worker behält seine Schutzprüfungen (400/403).
  Konfigurationssicherung:
  `/volume2/Datenbanken/AuraQuest/backups/apple-account-before-20261016072811`.
- Vor der aktiven Migration wurde ein frischer NAS-Dump isoliert wiederhergestellt;
  alle acht SQL-Suiten bestanden. Migration
  `20261010150000_apple_account_revocation.sql` ist aktiv, Hash
  `13c467b8d56e7588a1cc83cd7bc5344601a48833de895524f107da38b691c272`.
  Das Deployment prüft unveränderte Konto-/Profil-/Quest-/Check-in-Zähler und
  Aura-Summe. Backup:
  `/volume2/Datenbanken/AuraQuest/backups/apple-revocation-before-20261016072825.dump`.
  Docker wurde ausschließlich auf dem NAS benutzt.
- Die elf Apple-Handler-Tests und sechs iOS-Signierungsprüfungen bestanden.
  Das tatsächliche IPA wurde erneut auf Identität, SDKs und Privacy-Manifeste
  geprüft. Der später auf dem iPhone bestätigte native Google-Fix ist in Build 14 enthalten.
- Der normale Review-Login funktioniert intern und über die öffentliche HTTPS-API.
  Drei Solo-Beispielquests sind vorhanden. Zugang, vorhandene Apple-Kontaktdaten
  und Review-Hinweise wurden ausschließlich in Apples App-Review-Feldern gespeichert.
  Zugangsdaten gehören weder in diese Dokumentation noch ins Repository.
- Die bestätigte Datenschutzerklärung mit Datum 16. Oktober ist öffentlich unter
  <https://legal.brenzel.uk/aura-quest/> erreichbar. Origin-Hash und öffentliche
  Inhalte wurden geprüft. Vorherige Seite:
  `/volume2/Datenbanken/AuraQuest/backups/legal-before-20261016072929.html`.
- App Privacy ist bei Apple veröffentlicht: zwölf konto-verknüpfte Datentypen
  ausschließlich zur App-Funktionalität, ein nicht verknüpfter Firebase-Datentyp
  für technische Analysen, keine Verwendung für Tracking.
- Altersfragebogen und Inhaltsrechte sind gespeichert. Apple berechnete 13+;
  entsprechend der bestätigten Zielgruppe wurde auf **16+** erhöht. Apple zeigt
  regionale Äquivalente und für ältere Betriebssysteme global 17+ an. Der
  Fragebogen nennt Afghanistan und Marokko als aufgrund lokaler Gesetze gesperrt.
- Der ursprüngliche Upload-Workflow für Build 11 war erfolgreich:
  [38867505026](https://github.com/brenzelB/Aura100/actions/runs/38867505026),
  Job `116863624885`, Apple-Ergebnis `UPLOAD SUCCEEDED with no errors`.
  Verwendet wurde das signierte Artefakt 11 des erfolgreichen Release-Runs
  [38075183018](https://github.com/brenzelB/Aura100/actions/runs/38075183018),
  Quellstand `423dad4`. Kein neuer Build wurde nur für den Upload erzeugt.
- Frühere Apple-Build-ID 11: `ae823e83-d3a0-4f61-bec2-2169d2e5acab`.
  Dieser Build wurde inzwischen im Versionsentwurf durch Build 13 ersetzt;
  er bleibt als ältere interne TestFlight-Fassung erhalten.
  IPA-SHA256: `ad07dccbd697fcfda5439edeea0e4086ee929f9a4ae5c4283ac7650fbc33cca5`.
- Die am 15. Oktober überprüften neuen deutschen und englischen iPhone-/iPad-
  Storebilder bleiben erhalten. Die Lizenzvereinbarung wurde bereits am
  14. Oktober mit gesonderter Zustimmung angenommen.
- Nach ausdrücklicher Nutzerentscheidung wurde ausschließlich Frankreich aus der
  Länderauswahl entfernt. Apple zeigt **174 ausgewählte Länder oder Regionen**;
  der Vergleich aller Länderzeilen zeigt nur Frankreich als Änderung zu
  „Nicht verfügbar“. Alters-/Inhaltsbeschränkungen einzelner Länder gelten
  weiterhin unabhängig von der Auswahl.
- Für Build 11 wurden die Angaben **Standardverschlüsselung außerhalb bzw.
  zusätzlich zum Apple-Betriebssystem** und **kein Vertrieb in Frankreich**
  gespeichert. Danach zeigte Apple „Bereit zur Übermittlung“ ohne fehlende
  Compliance. Es wurde keine französische Genehmigung oder reine OS-Kryptografie
  behauptet und kein Info.plist-Schlüssel verändert.
- Build 13 ist der bestehenden Gruppe **Aura Quest iOS intern** zugeordnet;
  diese zeigt **Im Test**, einen bestehenden Tester und drei Builds (13, 11, 9).
  Kein neuer Nutzer wurde hinzugefügt. Für die Abnahme muss auf Build 13
  aktualisiert werden. Der Nutzer hat inzwischen auf die ausdrückliche Frage nach
  Version 1.0.2 (13) die Anmeldung bestätigt, jedoch seine Aussage zum automatischen
  Browser-Schließen korrigiert: Das Fenster bleibt offen.
- Apples Funktion „Zur Prüfung hinzufügen“ hat die Version ohne weitere
  Pflichtfeld-Fehler in einen Übermittlungsentwurf aufgenommen. Die Seitenleiste
  zeigt „1.0.2 Bereit zur Prüfung“, der Entwurf „Element bereit zur Übermittlung“
  mit **1.0.2 (13)**. Dies ist noch keine Einreichung und keine Apple-Genehmigung.
- Der vollständige Google-Login-Fix aus `1c4dc06` ist auf GitHub `main` und in
  Build 13 enthalten. Alle vier Jobs des
  [Release-Laufs 38877197982](https://github.com/brenzelB/Aura100/actions/runs/38877197982)
  bestanden, darunter 376 Unit-/Widgettests und acht exakte Theme-Goldens.
  Apple-Upload erfolgreich um 09:09:18 UTC, Verarbeitung `VALID`.
  Apple-Build-ID: `53ee2983-6ce4-478d-8e63-6063304d59fc`.
  IPA-SHA256: `0e497935f5304809c78b3df715ca292a0a7911d4282b9c47b90bfaaf366ac087`.
  Die tatsächliche IPA bestätigt Version, Build, Bundle und unveränderte
  Privacy-Angaben (22 Manifeste, 13 Datentypen, kein Tracking).
  Nach der konkreten Anfrage und Nutzerbestätigung „mach weiter“ wurde Build 11
  aus dem noch nicht abgesendeten Prüfentwurf gelöst und durch Build 13 ersetzt, gespeichert und
  erneut zur Prüfung hinzugefügt. Die Exportangabe für Build 13 entspricht Build
  11: Standardverschlüsselung außerhalb bzw. zusätzlich zu Apple, ohne Frankreich.

## Verlauf vor der Einreichung

**Geräteergebnis nach dem Google-Fix:** Die Google-Anmeldung ließ in Build 11 den
Safari-Controller offen. Der vollständige Fix ist als Build 13 aus `1c4dc06`
intern verfügbar und im noch nicht abgeschickten Übermittlungsentwurf ausgewählt.
Der Nutzer korrigiert für Version 1.0.2 (13): Google-Anmeldung funktioniert, das
Browserfenster schließt aber nicht automatisch. Der Fehler besteht weiter und
die Einreichung bleibt gestoppt. Auch die Kontolöschung wurde aus
Nutzersicht erfolgreich getestet; Anbieter und serverseitiger Widerruf wurden
dabei nicht gesondert bestätigt.
Siehe [Fehlerbefund und Korrektur](2026-10-16-google-ios-login.md).

**Ersatzbuild 14 erstellt und hochgeladen:** Commit `0171058` ersetzt ausschließlich Googles
iOS-Browserablauf durch `ASWebAuthenticationSession`, behält Supabase-PKCE und
iOS 15 bei und enthält keine neue Laufzeitabhängigkeit. Lokal bestehen 384
Unit-/Widgettests sowie die statische Analyse. Der signierte
[Release-Lauf 38907755246](https://github.com/brenzelB/Aura100/actions/runs/38907755246)
ist in allen vier Jobs erfolgreich, einschließlich acht Theme-Goldens, nativer
Kompilierung, Signierung und Upload. Trotz mehrfacher interner Apple-Serverfehler
beendete der vorhandene Uploader den Upload um 13:39:20 UTC erfolgreich.
Das tatsächliche IPA ist geprüft; unveränderte Privacy-Angaben, SHA256
`111153701ceedb07eb42bb96e92c2af64348f356eaaf58b8baeaace33a1dba18`.
Daraus folgt noch keine interne Verfügbarkeit in TestFlight und keine erfolgreiche
Geräteabnahme. Der Apple-Prüfentwurf wurde nach der
Nutzerkorrektur erneut gelesen: weiterhin **Übermittlungsentwurf, Build 13**,
keine Einreichung.
Anschließend zeigte App Store Connect auch nach erneutem Laden einen eigenen
Serverfehler; zwei read-only API-Prüfungen endeten nach 20 Sekunden im Timeout.
Die Verarbeitung und interne Gruppenfreigabe von Build 14 sind deshalb noch
nicht bestätigt. Es wurde kein weiterer Upload gestartet und Build 14 wurde
nicht in den öffentlichen Prüfentwurf übernommen. Nachweis:
`build/audit/proofs/apple-build-14-processing-server-error-2026-10-16.png`.

**Aktualisierte Freigabegrenze:** Apple bestätigt Build 14 inzwischen als `VALID`,
ID `8832e3cb-a8e4-4d14-9ad1-841ab13dad98`. Die Browser-Sitzung ist abgelaufen.
Der vorhandene Entwickler-API-Schlüssel kann Build/Gruppe/Version lesen, darf den
bereits für Build 13 bestätigten effektiven Exportstatus aber nicht auf Build 14
übernehmen (`PATCH` 403 `FORBIDDEN_ERROR`). Deshalb wurde die anschließende
Gruppenzuordnung nicht ausgeführt. Die read-only Kontrolle bestätigt unverändert:
fehlende Exportbestätigung bei Build 14, drei bestehende Gruppenbuilds (9/11/13),
öffentlicher Prüfentwurf weiterhin Build 13 `READY_FOR_REVIEW`, Release `MANUAL`.
Für die interne Freigabe wurde die erneute Anmeldung direkt bei Apple angefragt.

**Inzwischen abgeschlossen:** Nach der vom Nutzer bestätigten erneuten Anmeldung
wurden im bestehenden Apple-Browserkonto die bekannten Exportangaben für Build 14
gespeichert: Standardverschlüsselung außerhalb bzw. zusätzlich zum Apple-System,
kein Vertrieb in Frankreich. Apple zeigt danach „Bereit zur Übermittlung“.
Die vorhandene Gruppe **Aura Quest iOS intern** wurde Build 14 hinzugefügt;
deren Builds-Ansicht bestätigt **1.0.2 (14): Im Test**, einen Tester und vier
Builds (14, 13, 11, 9). Keine neuen Tester oder Rechte, kein öffentlicher Test
und keine öffentliche Einreichung. Der Versionsentwurf blieb unverändert.
Nachweis: `build/audit/proofs/apple-build-14-internal-test-2026-10-16.png`.
Offen bleibt der erneute echte iPhone-Google-Test mit Build 14 samt automatisch
geschlossenem Anmeldefenster. Der erfolgreiche Kontolöschungstest bleibt dokumentiert.

## Noch offen nach der Einreichung

1. [Weitere echte iPhone-Prüfungen](ios-testflight-acceptance.md): Apple-Anmeldung,
   Widerruf bei Kontolöschung, Push und Android-/iOS-Zusammenspiel. Automatisierte
   Prüfungen und Simulatoraufnahmen bestätigen diese Punkte nicht.
2. Apples Prüfung abwarten und mögliche Rückfragen oder Ablehnungsgründe bearbeiten.
   Die Einreichung von Build 14 ist abgeschlossen. Nach Apples Genehmigung folgt
   die manuelle Veröffentlichung; kein öffentlicher Release erfolgte bisher.
3. Für eine spätere Ergänzung Frankreichs zuerst die erforderlichen
   Verschlüsselungsunterlagen klären und genehmigen lassen; erst danach
   Verfügbarkeit und Exporterklärung passend aktualisieren.

Lokale Nachweise liegen Git-ignoriert unter `build/audit/`, insbesondere das
Deploymentprotokoll und die Screenshots in `build/audit/proofs/`.
