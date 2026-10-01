# Android-Push: NAS-Versand repariert (16.09.2026)

## Befund

Der interne Play-Test meldet keine Push-Benachrichtigungen. Auf NAS-BRA
waren vier FCM-Geräte registriert. Alle 37 vorhandenen FCM-Zustellungen in
`push_deliveries` waren mit HTTP 401 fehlgeschlagen. Zwölf erfolgreiche
Zustellungen gehörten ausschließlich zu UnifiedPush. Die jüngsten
`pg_net`-Antworten enthielten `message: Unauthorized` vom Gateway.

Die konfigurierte Versandadresse war
`http://kong:8000/functions/v1/push-fcm`. Die installierte App konnte ihre
Geräte registrieren; der Versand scheiterte vor dem Firebase-Dienst.

## Reparatur auf NAS-BRA

`push_config.fcm_function_url` wurde auf den im selben Docker-Netz erreichbaren
Worker `http://functions:9000/push-fcm` gesetzt. Der Worker prüft unverändert
`x-push-secret`; die öffentlichen Gateway-Regeln wurden nicht geändert.
`VERIFY_JWT=false` ist die bestehende Worker-Konfiguration, keine Änderung
dieser Reparatur. Das NAS-Backend verwendet für diesen Dienst bereits den
eigenen gemeinsamen Schlüssel zur Authentifizierung.

Vorher wurde ein vollständiger Dump erstellt und mittels `pg_restore -l`
geprüft:
`/volume2/Datenbanken/AuraQuest/backups/before-push-route-20260916203813.dump`.

Es wurden keine vergangenen Benachrichtigungen erneut eingereiht. Dies
verhindert eine Flut veralteter Meldungen. Keine App-Codeänderung und kein
neuer Store-Build sind für diese Reparatur erforderlich.

## Prüfung

- Datenbank → Worker mit richtigem Schlüssel und leerem Payload: HTTP 400
  (Authentifizierung akzeptiert, Payload erwartungsgemäß abgelehnt).
- Derselbe Aufruf ohne Schlüssel: HTTP 403.
- Datenbank → konfigurierte Worker-Adresse → OAuth → Firebase mit absichtlich
  ungültigem Diagnose-Token: HTTP 400 / FCM `INVALID_ARGUMENT`. Damit ist
  auch der tatsächliche Versandweg inklusive Dienstkonto geprüft, ohne
  Benachrichtigungen an Nutzer zu senden.
- Firebase `validate_only` mit den vier registrierten Tokens: drei HTTP 200,
  ein HTTP 404 mit ausdrücklichem FCM `UNREGISTERED`. Der vorhandene Reaper
  entfernt ungültige Registrierungen bei einem regulären Zustellversuch.
- Sichtbare Zustellung auf dem Nutzerhandy ist noch nicht bestätigt.
  Benutzername wurde angefragt, um eine Testmeldung gezielt zu senden.

Ein Firebase-HTTP-200 bestätigt Annahme/Validierung durch Firebase, nicht
die Anzeige im Android-Benachrichtigungsbereich.

## Wiederholbare Diagnose

`node scripts/nas-fix-push-route.mjs` prüft Routing und Authentifizierung.
Mit `--apply` wird nur die bekannte alte Adresse nach validiertem Backup
geändert. Ein bereits reparierter Zustand bleibt unverändert.

`scripts/nas-validate-fcm.py` wird per SSH mit `python3 -` auf NAS-BRA
ausgeführt. Es verwendet ausschließlich FCM `validate_only`; private
Schlüssel und Tokens bleiben auf dem NAS und werden nicht protokolliert.
Exitcode 1 bedeutet mindestens eine ungültige Registrierung oder einen
Prüffehler; die Ausgabe unterscheidet die FCM-Fehlercodes.

Zusätzlicher Befund: Zwei historische Deadlocks zwischen Versand und
Reaper sind protokolliert (10./13.09.). Das erklärt nicht die durchgängigen
401-Antworten; Änderungen an deren Sperrreihenfolge sind nicht Teil dieser
gezielten Konfigurationsreparatur.
