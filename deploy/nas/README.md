# Aura Quest auf dem UGREEN NAS (NAS-BRA)

Stand: 28.07.2026 — der Stack **läuft**. Dieses Dokument beschreibt, wie er
tatsächlich aufgesetzt ist, nicht mehr wie er aufgesetzt werden soll.

| Sicht | Pfad |
|---|---|
| NAS-intern (Docker) | `/volume2/Datenbanken/AuraQuest` |
| Von Windows (SMB) | `\\NAS-BRA\Datenbanken\AuraQuest` |

NAS unter `192.168.178.123`, UGOS-Oberfläche auf Port 9999, Supabase-Gateway
auf Port 8000. SSH-Zugang als `denzel` mit dem Schlüssel `~/.ssh/auraquest_nas`.

---

## Die eine Regel, die man nicht brechen darf

Der Stack läuft **auf dem NAS** und bindet den **NAS-internen** Pfad ein. Ein
PostgreSQL-Datenverzeichnis über eine SMB-Freigabe (`\\NAS-BRA\...`, ein
gemapptes Laufwerk, Docker auf dem PC mit CIFS-Mount) führt zu Datenkorruption:
Postgres verlangt fsync-Garantien, File-Locking und atomares Rename, die
SMB/CIFS nicht zusichert.

In den Ordner **hineinschauen** ist in Ordnung. Hineinschreiben oder Dateien
verschieben, während der Stack läuft, nicht.

---

## Aufbau

Eine einzige Datei beschreibt den Stack:

```
/volume2/Datenbanken/AuraQuest/
├── docker-compose.yaml        ← der gesamte Stack (11 Dienste)
├── .env                       ← alle Geheimnisse, chmod 600
├── pgimage/Dockerfile         ← eigenes Postgres-Image, siehe unten
├── volumes/db/data            ← der eigentliche Datenbestand
├── backups/                   ← pg_dump-Abzüge
│   └── compose-original/      ← der frühere Zwei-Datei-Aufbau
└── docker-compose.*.yml       ← ungenutzte Varianten aus dem Supabase-Repo
```

`COMPOSE_FILE=docker-compose.yaml` in der `.env` legt fest, welche Datei gilt.
Ohne diese Zeile würde Compose eine `docker-compose.yml` bevorzugen — und im
Ordner liegen mehrere Varianten aus dem Supabase-Repo herum.

Ursprünglich bestand der Stack aus `docker-compose.yml` (Supabase im Original)
plus `docker-compose.override.yml` (unsere NAS-Anpassungen). Beide liegen zur
Nachvollziehbarkeit in `backups/compose-original/`. Die Override-Datei ist auch
hier im Projekt abgelegt — sie ist die beste Zusammenfassung dessen, was wir
gegenüber dem Supabase-Original geändert haben.

Zusammengeführt wurden sie, weil die UGOS-Docker-App pro Projekt nur **eine**
Konfigurationsdatei verwaltet. Mit zwei Dateien hätte ein Import über die
Oberfläche die Override-Datei übergangen — und damit die beiden folgenden
Anpassungen verloren, was die Datenbank sofort lahmlegt.

---

## Zwei UGOS-Besonderheiten, die abgefangen sind

**1. Die Rechteschicht `ugacl` auf `/volume2`.** Sie lässt nur echte
NAS-Benutzer zu. Der übliche Postgres-UID 999 bekommt dort nichts — nicht
einmal Zugriff auf sein eigenes Datenverzeichnis. Deshalb läuft die Datenbank
als `1000:10` (denzel) aus einem abgeleiteten Image:

```dockerfile
FROM supabase/postgres:17.6.1.136
RUN usermod -u 1000 postgres
```

Gebaut als `auraquest/postgres:17`. Kong läuft als root, weil es zusätzlich in
eigene Verzeichnisse im Image schreiben muss.

Der Ratschlag „`chown -R 999:999`" aus der Supabase-Dokumentation hilft hier
**nicht** — die Sperre liegt nicht an den Dateirechten.

**2. Ein Container fällt aus dem Namensschema.** Zehn Container heißen
`auraquest-*`, einer heißt `realtime-dev.supabase-realtime`. Das ist Absicht:
Realtime leitet aus dem Containernamen seinen Tenant ab, und `kong.yml` spricht
ihn so an. Umbenennen bricht den Push.

---

## Projekt-Gruppierung

Beide Stacks auf dem NAS tragen einen Compose-Projektnamen und bekommen dadurch
ein eigenes Netzwerk:

| Projekt | Container | Netzwerk | Ordner |
|---|---|---|---|
| `auraquest` | 11 | `auraquest_default` | `/volume2/Datenbanken/AuraQuest` |
| `inventar-app` | 5 | `inventar-app_default` | `/volume2/Datenbanken/Inventar App` |

Jeder Container trägt zusätzlich ein Etikett `org.auraquest.rolle` bzw.
`org.inventar.rolle`, das in einem Satz erklärt, wofür er da ist.

**Der Reiter „Projekt" in der UGOS-Docker-App führt eine eigene Liste.** Über
die Kommandozeile gestartete Stacks tauchen dort nicht auf, auch wenn die
Container-Liste den Projektnamen korrekt anzeigt. Um sie einzutragen: Docker-App
→ Projekt → Erstellen → als Speicherpfad den jeweiligen Ordner wählen. UGOS
erkennt die vorhandene Konfiguration und bietet an, sie zu übernehmen.

---

## Backups

Läuft automatisch. Der Container **`auraquest-backup`** legt täglich um **03:15**
einen Abzug in `backups/` ab und behält die **14 jüngsten**. Das Skript dazu ist
[`backup-loop.sh`](backup-loop.sh); es wird schreibgeschützt in den Container
eingehängt.

Ein Dateikopie-Backup einer **laufenden** Datenbank ist nicht garantiert
wiederherstellbar — mittendrin geschriebene Seiten ergeben eine Datenbank, die
vielleicht startet und vielleicht nicht. `pg_dump` liest dagegen einen
konsistenten Schnappschuss.

**Warum ein Container und kein Cron-Eintrag:** Die Benutzer-Crontab auf dem NAS
ist nicht beschreibbar (`/var/spool/cron: Permission denied`). Die Alternativen
bräuchten entweder `sudo` oder den Docker-Socket — letzterer ist auf einem
öffentlich erreichbaren Rechner faktisch ein Root-Zugang. Der Container spricht
Postgres nur über das Netz an und kann sonst nichts.

Jeder Abzug wird direkt nach dem Schreiben mit `pg_restore -l` geprüft; eine
Datei mit weniger als 50 Einträgen gilt als unvollständig und wird verworfen,
damit eine abgebrochene Sicherung keine gute überschreibt.

Nachsehen:

```bash
docker logs auraquest-backup | tail -20
ls -lht /volume2/Datenbanken/AuraQuest/backups/*.dump | head
```

---

## Wiederherstellung

**Getestet am 06.08.2026:** Abzug in eine leere Datenbank zurückgespielt, alle
Zeilenzahlen stimmten überein — 6 Konten, 7 Quests, 27 Check-ins, und die Summe
aller Aura-Stände exakt gleich (12325).

### In eine frische Datenbank

```bash
docker exec -i auraquest-db pg_restore -U postgres -d postgres \
  --no-owner --no-privileges < backups/auraquest-JJJJMMTT-HHMM.dump
```

### Erwartbare Fehlermeldungen, die keine sind

Beim Zurückspielen in eine **andere** Datenbank als `postgres` erscheinen acht
Fehler. Sie betreffen ausschließlich Infrastruktur, nie Spieldaten:

| Meldung | Grund |
|---|---|
| `can only create extension in database postgres` | `pg_cron` lässt sich nur in der Datenbank `postgres` anlegen |
| `extension "pg_cron" does not exist` | Folge davon |
| `schema "cron" does not exist` (2×) | Folge davon |
| `permission denied to set parameter log_min_messages` | Realtime-Funktion, braucht Superuser |
| `permission denied for table secrets` | Vault-Tabelle |

### Danach unbedingt prüfen

Die **Cron-Jobs** kommen bei einem Restore in eine andere Datenbank **nicht**
mit. An ihnen hängt die gesamte Spiel-Ökonomie:

```sql
select jobname, schedule, command from cron.job;
```

Erwartet werden fünf Einträge: `aura-settlement` (`5 * * * *`), `duel-expiry`
(`10 * * * *`), `deliver-notifications` (`* * * * *`), `reap-push-failures`
(`*/15 * * * *`) und `prune-notification-outbox` (`30 4 * * *`). Fehlen sie,
müssen sie mit `cron.schedule(...)` neu angelegt werden — sonst laufen Strafen,
Strikes und Quest-Abschlüsse stillschweigend nicht mehr.

---

## Erreichbarkeit von außen — Cloudflare Tunnel

Die öffentliche Adresse ist **`https://api.brenzel.uk`**. Am Router ist **kein
Port freigegeben**: der Container `auraquest-tunnel` (Image
`cloudflare/cloudflared`) baut die Verbindung von innen nach außen auf und
Cloudflare reicht Anfragen darüber zurück. Das funktioniert deshalb auch hinter
CGNAT, verbirgt die Heim-IP und bringt das TLS-Zertifikat mit.

Die Weiterleitung selbst (`api.brenzel.uk` → `http://auraquest-gateway:8000`)
steht **nicht** in diesem Repo, sondern in der Cloudflare-Oberfläche unter
Zero Trust → Networks → Tunnels → Public Hostname. Der Container kennt nur
`CLOUDFLARED_TOKEN` aus der `.env` und holt sich den Rest von dort.

Drei Werte in der `.env` müssen zur Domain passen, sonst baut GoTrue falsche
Links in Bestätigungs-Mails und OAuth-Rückläufe:

```
SUPABASE_PUBLIC_URL=https://api.brenzel.uk
API_EXTERNAL_URL=https://api.brenzel.uk
SITE_URL=https://api.brenzel.uk
```

Läuft der Tunnel?

```bash
docker logs auraquest-tunnel 2>&1 | grep "Registered tunnel connection"
# vier Verbindungen zu zwei Rechenzentren = normal (Redundanz)
```

---

## Prüfen, ob alles läuft

```bash
docker compose ps                                    # 12× healthy
curl -s -o /dev/null -w "%{http_code}\n" -H "apikey: $ANON_KEY" \
  "https://api.brenzel.uk/rest/v1/profiles?select=id&limit=1"
```

Antwortet die Domain nicht, grenzt der direkte Weg im LAN ein, ob es am Tunnel
oder am Stack liegt:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -H "apikey: $ANON_KEY" \
  "http://192.168.178.123:8000/rest/v1/profiles?select=id&limit=1"
```

Erwartet: HTTP 200. Der Wurzelpfad `/rest/v1/` liefert dagegen absichtlich 403
(„You cannot consume this service") — das ist kein Fehler, den Pfad gibt Kong
nur an `service_role` frei.

Die Cron-Jobs, an denen die gesamte Spiel-Ökonomie hängt:

```sql
select jobid, schedule, command from cron.job;
--  1 | 5 * * * *  | select public.settle_periods()
--  2 | 10 * * * * | select public.expire_duels()
```
