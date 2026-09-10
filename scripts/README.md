# Audit ausführen

**Aktueller Projektweg: Docker ausschließlich auf NAS-BRA.** Flutter, Node und
ADB laufen auf dem PC. Die früheren lokalen Docker-Beispiele weiter unten sind
historisch und werden für dieses Projekt nicht mehr verwendet.

## Aktuelle Balance-Tests auf dem NAS

```powershell
node scripts/balance-db-test.mjs --setup --replay --check
node scripts/balance-db-test.mjs supabase/tests/balance_regressions.sql
node scripts/balance-db-test.mjs supabase/tests/audit_regressions.sql
node scripts/balance-db-test.mjs supabase/tests/push_delivery_regressions.sql
node scripts/balance-db-test.mjs supabase/tests/lifecycle_regressions.sql
node scripts/balance-db-test.mjs supabase/tests/duel_regressions.sql
node scripts/balance-db-test.mjs supabase/tests/privilege_regressions.sql
node scripts/balance-concurrency.mjs
node scripts/balance-db-test.mjs --stop
flutter analyze
flutter test
dart run scripts/simulate_balance.dart
flutter build apk --debug
```

Diese DB-Tests laufen per SSH ausschließlich in `aura100-balance-test` auf dem
NAS, ohne Netzwerk und aktive Cron-Jobs. Das Container-Label wird geprüft.
`--replay` spielt alle Migrationen jeweils atomar ein und protokolliert sie.
Bereits eingespielte Migrationen nicht bearbeiten; für einen anderen historischen
Ausgangsstand einen frischen Testcontainer verwenden. `balance-concurrency.mjs`
entfernt seine reservierten synthetischen Konten im `finally`-Block.

`nas-apply-balance.mjs` prüft ohne `--apply` nur NAS-Ledger und Prüfsummen.
`--apply` erstellt und validiert einen geschützten NAS-Dump und führt Paket 1
atomar mit Prüfungen bestehender Guthaben, Questwerte und Historie aus. Bereits
angewendete, unveränderte Migrationen werden erkannt. Andere Änderungen brauchen
eine neue Migration und einen geprüften Bereitstellungspfad.

Paket-1-Protokolle/Simulation: `build/balance/`. Regeln und Ergebnisse:
`docs/2026-09-08-umsetzungspaket-1.md`.

## Historischer Auditweg vom 07.09.2026

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
