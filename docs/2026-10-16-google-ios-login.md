# Google-Anmeldung: iOS-Browser bleibt offen

**Aktueller Stand:** Der Nutzer korrigiert den Test von Build 13 ausdrücklich:
Anmeldung erfolgreich, Fenster bleibt offen. Die öffentliche Einreichung ist
gestoppt. Der nachträgliche `url_launcher`-Schließversuch wird durch Apples
`ASWebAuthenticationSession` ersetzt; ein neuer signierter Testbuild ist erforderlich.

## Befund

Der iPhone-Test mit Build 1.0.2 (11) zeigte nach der Google-Anmeldung eine
Gateway-Fehlerseite. Die NAS-Prüfung am 16. Oktober ergab:

- Google ist aktiviert; der Provider-Callback ist korrekt
  `https://api.brenzel.uk/auth/v1/callback`.
- Die öffentliche Authorize-Route leitet zu Google mit genau diesem Callback.
- Der echte Versuch um 08:33 UTC hat den Callback erfolgreich durchlaufen;
  Auth-Audit-Einträge bestätigen die Anmeldung und eine neue Sitzung.
- Ein zweiter Aufruf des bereits verwendeten Callbacks meldet um 08:33:31 UTC
  „OAuth state not found or expired“. Der Fehler-Fallback führt zur API-Startseite,
  für die das Gateway keine App-Seite anbietet.
- Der bisherige iOS-Ablauf öffnet mit `LaunchMode.platformDefault` einen
  SFSafariViewController. Dieser schließt nach einem App-Deep-Link nicht von selbst.
  Die App kann dadurch bereits angemeldet hinter dem Browser liegen. Die
  Bestätigung dieses konkreten Verhaltens auf dem iPhone wurde angefragt.

Es wurde keine Serverkonfiguration, Redirect-Allowlist oder Google-Berechtigung
verändert und keine zusätzliche öffentliche Gateway-Route geöffnet.

## Erster Änderungsversuch in Build 13 (auf dem iPhone nicht ausreichend)

Nur beim Start des Google-Browser-Logins auf iOS wird vor dem Öffnen ein
kurzlebiger Listener eingerichtet. Nach einem `signedIn`-Ereignis mit gültiger
Sitzung schließt `closeInAppWebView` den vorhandenen Safari-Controller.
Der Listener wird bei Erfolg, Fehler, abgelehntem Browserstart, Wiederholung,
Wechsel des Anmeldewegs, Abmeldung, Provider-Abbau oder Ablauf beendet.
Initiale Sitzungen und Token-Refreshs schließen keinen Browser.
Ein Fehler beim nativen Schließen verwirft keine bereits gültige Sitzung.
Das gilt auch für den belegten schnellen Rückruf vor Abschluss des Browserstarts:
Ein bereits akzeptierter Login bleibt erfolgreich, wenn der Browserstart durch
das rechtzeitige Schließen anschließend `false` oder einen nativen Fehler meldet.

Android und Web behalten ihre bisherigen Startmodi; Apples nativer Login und
die Kontolöschung ändern sich funktional nicht. Keine neue Abhängigkeit oder
Google-OAuth-Berechtigung ist erforderlich.

## Ersatz durch eine native iOS-Web-Anmeldesitzung

Der Google-Login auf iOS erzeugt seine Authorize-URL weiterhin über das vorhandene
Supabase-SDK samt PKCE-Verifier und unveränderter Redirect-URI. Eine kleine native
Flutter-Brücke öffnet diese URL mit `ASWebAuthenticationSession`. iOS fängt den
passenden Callback selbst ab, beendet die Anmeldesitzung und liefert die URL zurück.
Erst danach tauscht das SDK den Code gegen eine App-Sitzung. Der bisherige
Auth-Ereignis-Listener und der nachträgliche Safari-Schließversuch werden entfernt.

- Eigene Registrierung am vorhandenen impliziten Flutter-Engine-Lebenszyklus;
  Präsentation am tatsächlich zugehörigen App-Fenster statt an einem geratenen Fenster.
- Native Rückrufe älterer, abgebrochener Versuche können keinen neu gestarteten
  Versuch abschließen. Doppelte Aufrufe überschreiben den PKCE-Verifier nicht.
- Abbruch erzeugt keine App-Sitzung und kann erneut versucht werden. Beim Wechsel
  des Anmeldewegs wird ein noch ausstehender Rückruf ungültig.
- Der zurückgelieferte Callback muss exakt Scheme, Host und Pfad der bisherigen
  Redirect-URI erfüllen. Fremde Ziele, Port/Userinfo, Tokenfragmente, leere oder
  doppelte Codes werden vor einem Austausch abgelehnt.
- Android, Web, nativer Apple-Login, Push und Themes behalten ihre bisherigen Abläufe.
  Keine neue Laufzeitabhängigkeit; lediglich die bereits vorhandene HTTP-Bibliothek
  ist zusätzlich direkt als Testabhängigkeit deklariert. Keine SDK-Updates.
- iOS 15 bleibt unterstützt; ab iOS 17.4 wird Apples aktueller Callback-Initializer
  verwendet, auf älteren unterstützten Versionen der dort verfügbare Initializer.

16 gezielte Tests prüfen die echte SDK-PKCE-Code-Erzeugung und den Codeaustausch
über simulierte HTTP-Antworten, außerdem Abbruch, erneuten Versuch, doppelte
Aufrufe, verspätete Rückrufe, ungültige Callback-Ziele und Fehler. Sie ersetzen
keinen erneuten Test des nativen Fensters auf dem iPhone.

## Prüfung und Veröffentlichung

Die acht gezielten Regressionstests bestehen. Der Flutter-Analyzer meldet keine
Probleme. Vor der zusätzlichen Absicherung bestanden außerdem 374 Unit-/Widget-
Tests und alle acht exakten Theme-Goldens. Der Gegenbeweis für den schnellen
Rückruf schlug zuvor erwartungsgemäß fehl (erwartet `true`, tatsächlich `false`),
danach bestanden alle acht gezielten Tests. Der vollständige iPhone-Google-Login
einschließlich automatischem Schließen muss mit dem Ersatzbuild bestätigt werden.

Der erste Ersatzbuild 12 aus `22ba015` wurde ohne die zusätzliche Absicherung
erstellt. Sein Abbruch wurde von der automatischen Freigabeprüfung nicht erlaubt;
er ist deshalb vollständig zu Ende gelaufen. Anschließend wurde der vollständige
Fix als **1.0.2 (13)** erstellt und erfolgreich zu Apple hochgeladen:

- Quellstand: `1c4dc069fe955000a24031b38e386e317df4108c`, nach GitHub `main` gepusht.
- [Release-Lauf 38877197982](https://github.com/brenzelB/Aura100/actions/runs/38877197982):
  alle vier Jobs erfolgreich, einschließlich 376 Unit-/Widgettests, acht exakten
  Windows-Theme-Goldens, Signierungsprüfungen und Android-/iOS-Release-Builds.
- Apple-Upload am 16. Oktober um 09:09:18 UTC: `UPLOAD SUCCEEDED with no errors`.
- IPA-SHA256:
  `0e497935f5304809c78b3df715ca292a0a7911d4282b9c47b90bfaaf366ac087`.
- Tatsächliches exportiertes IPA geprüft: Version 1.0.2, Build 13, richtiges Bundle,
  SDK iphoneos26.5, iOS 15 Minimum, keine Store-Demodaten, kein Analytics-/Ads-SDK,
  dieselben 22 Privacy-Manifeste und 13 Datentypen, kein Tracking.
- Herkunftsdatei des signierten Artefakts bestätigt Commit, Build 13 und `signing=true`.

Apple hat Build 13 erfolgreich verarbeitet (`VALID`). Nach der konkreten
Freigabeanfrage bestätigte der Nutzer mit „mach weiter“ den Austausch und die
interne Freigabe. Die Exportangabe mit Standardverschlüsselung außerhalb bzw.
zusätzlich zum Apple-Betriebssystem und ohne Vertrieb in Frankreich ist gespeichert.
Die bestehende Gruppe **Aura Quest iOS intern** zeigt **1.0.2 (13): Im Test**;
ein bestehender Tester und jetzt drei Builds, keine zusätzlichen Tester.
Apple-Build-ID: `53ee2983-6ce4-478d-8e63-6063304d59fc`.

Build 11 wurde ausschließlich aus dem noch nicht abgesendeten Prüfentwurf und
der Versionszuordnung gelöst; in TestFlight bleibt er erhalten. Build 13 wurde
ausgewählt, gespeichert und erneut zur Prüfung hinzugefügt. Apple zeigt im
Übermittlungsentwurf **Element bereit zur Übermittlung — 1.0.2 (13)**.
Der finale Knopf **Zur Prüfung übermitteln** wurde nicht betätigt. Build 11 und
Zwischenbuild 12 werden nicht als vollständig abgenommene Fassung eingereicht.
Die frühere automatische Ablehnung der Entwurfsänderung wurde vor der neuen
Nutzerbestätigung respektiert; es erfolgte keine Umgehung.

Korrigiertes Geräteergebnis am 16. Oktober: Der Nutzer nahm seine ursprüngliche
Antwort „Ja, beides funktioniert“ ausdrücklich zurück: **Die Google-Anmeldung
funktioniert, das Fenster schließt sich aber nicht automatisch.** Build 13 behebt
den Schließfehler auf dem echten iPhone damit nicht. Die App-Review-Einreichung
bleibt gestoppt; der Entwurf wurde nicht übermittelt. Eine robustere native
Web-Authentifizierung wird geprüft. Wiederholung und Abbruch wurden nicht
gesondert berichtet. Die erfolgreiche Kontolöschung bleibt bestätigt; der
Anmeldeanbieter ist nicht angegeben.
Nachweise: `build/audit/proofs/apple-build-13-internal-test-2026-10-16.png` und
`build/audit/proofs/apple-submission-draft-build-13-ready-2026-10-16.png`.

Quellen:

- [Supabase OAuth-Start und LaunchMode](https://supabase.com/docs/reference/dart/auth-signinwithoauth)
- [Supabase-Issue zum offen bleibenden iOS-Browser](https://github.com/supabase/supabase-flutter/issues/1402)
- [Offizielle Browser-Schließfunktion](https://pub.dev/documentation/url_launcher/latest/url_launcher/closeInAppWebView.html)
- [Apple: Web-Authentifizierung mit passendem Callback](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession/init%28url%3Acallback%3Acompletionhandler%3A%29-6nut7)
- [Flutter: Registrierung am impliziten iOS-Engine-Lebenszyklus](https://docs.flutter.dev/platform-integration/ios/platform-views)
