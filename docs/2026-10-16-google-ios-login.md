# Google-Anmeldung: iOS-Browser bleibt offen

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

## Änderung

Nur beim Start des Google-Browser-Logins auf iOS wird vor dem Öffnen ein
kurzlebiger Listener eingerichtet. Nach einem `signedIn`-Ereignis mit gültiger
Sitzung schließt `closeInAppWebView` den vorhandenen Safari-Controller.
Der Listener wird bei Erfolg, Fehler, abgelehntem Browserstart, Wiederholung,
Wechsel des Anmeldewegs, Abmeldung, Provider-Abbau oder Ablauf beendet.
Initiale Sitzungen und Token-Refreshs schließen keinen Browser.
Ein Fehler beim nativen Schließen verwirft keine bereits gültige Sitzung.

Android und Web behalten ihre bisherigen Startmodi; Apples nativer Login und
die Kontolöschung ändern sich funktional nicht. Keine neue Abhängigkeit oder
Google-OAuth-Berechtigung ist erforderlich.

## Prüfung und Veröffentlichung

Die sechs gezielten Regressionstests bestehen. Der Flutter-Analyzer meldet keine
Probleme. Weitere gesamte App-Prüfungen und der Ersatz-TestFlight-Build werden
im aktuellen Arbeitsablauf verifiziert. Der vollständige iPhone-Google-Login
einschließlich automatischem Schließen muss mit dem Ersatzbuild bestätigt werden.

Build 11 darf nicht ohne diese Geräteprüfung als behobene Version eingereicht
werden. Der Apple-Übermittlungsentwurf ist noch nicht abgeschickt.

Quellen:

- [Supabase OAuth-Start und LaunchMode](https://supabase.com/docs/reference/dart/auth-signinwithoauth)
- [Supabase-Issue zum offen bleibenden iOS-Browser](https://github.com/supabase/supabase-flutter/issues/1402)
- [Offizielle Browser-Schließfunktion](https://pub.dev/documentation/url_launcher/latest/url_launcher/closeInAppWebView.html)
