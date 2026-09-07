# Audit ausführen

Alle Befehle aus dem Projektordner. Flutter 3.44.6, Node 24 und Docker werden
benötigt. Die SQL-Tests verwenden pgTAP und PostgreSQL mit echtem pg_net/pg_cron.

## Isolierte Datenbank mit synthetischen Daten

```powershell
node scripts/db-audit.mjs --setup --replay --check
node scripts/db-audit.mjs supabase/tests/audit_regressions.sql
node scripts/db-audit.mjs supabase/tests/push_delivery_regressions.sql
node scripts/db-audit.mjs supabase/tests/lifecycle_regressions.sql
node scripts/db-audit.mjs supabase/tests/duel_regressions.sql
node scripts/db-audit.mjs supabase/tests/privilege_regressions.sql
node scripts/db-concurrency-test.mjs
flutter analyze
flutter test
flutter build apk --debug
```

`--setup` erstellt ausschließlich `aura100-audit-db`, ohne Netzwerkanbindung.
Das Passwort ist nur für diesen Testcontainer. `--replay` wendet neue Dateien
in Reihenfolge an. Bei Änderungen an bereits angewendeten Migrationen einen
frischen Testcontainer aufsetzen; die lokale Liste ist keine Prüfsummenprüfung.
Der Schema-Check und fehlgeschlagene pgTAP-Assertions liefern einen Fehlerstatus.
Die fünf SQL-Dateien rollen ihre Fixtures zurück. Der Paralleltest verwendet
eigene reservierte IDs und entfernt seine Fixtures im `finally`-Block.

## NAS untersuchen

```powershell
node scripts/nas-audit.mjs supabase/tests/nas_inspection.sql
node scripts/nas-audit.mjs supabase/tests/nas_consistency.sql
node scripts/nas-audit.mjs supabase/tests/nas_verification.sql
```

Diese Aufrufe nutzen SSH mit bestehendem, geprüftem Hostschlüssel und den
Schlüssel `~/.ssh/auraquest_nas`. SQL läuft in einer READ ONLY-Transaktion.
Die Ausgabe enthält Struktur und aggregierte Zahlen, keine Passwörter,
Push-Tokens oder Nachrichteninhalte. `nas_verification.sql` setzt die bereits
erfolgte September-Bereitstellung voraus.

`--nas-copy` beim DB-Testtool adressiert ausschließlich den lokalen Container
`aura100-nas-restore`. Vorher einen NAS-Dump isoliert wiederherstellen, siehe
`deploy/nas/README.md`. Der Upgrade-Pfad gilt für den überprüften August-Stand
des NAS vom 07.09.2026. Niemals dieses Flag als allgemeine Migrationserkennung
verwenden. Die NAS-Kopie enthält Geheimnisse und muss ohne Netzwerk und mit
abgeschaltetem Cron laufen; nach der Prüfung entfernen.

## Bereits ausgeführte Änderungen am NAS

`nas-apply-verified.mjs --apply` war die gezielte einmalige Migration des
inspizierten NAS-Standes. Es erstellt ein Backup, prüft dessen Inhaltsverzeichnis,
wendet die aufgeführten SQL-Dateien atomar an und protokolliert SHA-256-Prüfsummen in
`aura_admin.applied_migrations`. Ein zweiter Aufruf wird durch die Prüfung des
Ausgangsschemas gestoppt. `--privileges-only --apply` war der separat geprüfte
Übergang von genau acht auf neun protokollierte Migrationen; auch dieser Aufruf
wird danach abgewiesen. Weitere Änderungen brauchen einen neuen geprüften
Migrationspfad. Ohne `--apply` zeigt das Skript nur die geplanten Dateinamen.

`nas-smoke-fixtures.mjs` legt zwei eindeutig benannte Prüfquests für die
vorhandenen Emulator-Testkonten an, prüft ihre Buchungen oder entfernt sie.
Es ist ein Werkzeug für genau diese Testumgebung, kein App-Feature.
`check-nas-backup.mjs` erstellt einen echten neuen Dump mit der Backup-Routine;
beim Prüflauf werden keine alten Dumps rotiert.

Ergebnisse und APK-Sicherungen liegen in `build/audit/`, das nicht in Git
aufgenommen wird. Der neue Android-Build liegt in
`build/app/outputs/flutter-apk/app-debug.apk`.
