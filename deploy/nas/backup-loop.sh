#!/bin/sh
# =================================================================
#  Aura Quest - taegliche Datensicherung
#
#  Laeuft IM Sicherungs-Container, nicht auf dem NAS.
#
#  WARUM EIN CONTAINER UND KEIN CRON-EINTRAG:
#  Die Benutzer-Crontab auf dem NAS ist nicht beschreibbar. Die
#  Alternativen brauchten entweder sudo oder den Docker-Socket -
#  letzterer ist auf einem oeffentlich erreichbaren Rechner faktisch
#  ein Root-Zugang, und den fuer ein Backup zu vergeben waere ein
#  schlechter Tausch. Dieser Container spricht Postgres nur ueber das
#  Netz an und kann sonst nichts.
#
#  WARUM pg_dump UND KEINE DATEIKOPIE:
#  Eine Kopie des laufenden Datenverzeichnisses ist nicht garantiert
#  wiederherstellbar - mittendrin geschriebene Seiten ergeben eine
#  Datenbank, die vielleicht startet und vielleicht nicht. pg_dump
#  liest einen konsistenten Schnappschuss.
# =================================================================
set -u

ZIEL=/backups
BEHALTEN=14
STUNDE=03
MINUTE=15

melde() {
  echo "$(date '+%Y-%m-%d %H:%M:%S')  $*" | tee -a "$ZIEL/backup.log"
}

sichern() {
  STEMPEL=$(date +%Y%m%d-%H%M)
  DATEI="$ZIEL/auraquest-$STEMPEL.dump"

  if ! pg_dump -Fc > "$DATEI" 2>>"$ZIEL/backup.log"; then
    melde "FEHLER: pg_dump fehlgeschlagen - unvollstaendige Datei verworfen"
    rm -f "$DATEI"
    return 1
  fi

  # Ein Abzug, den man nicht lesen kann, ist keiner. pg_restore -l geht
  # das Inhaltsverzeichnis durch und scheitert an einer kaputten Datei.
  ANZAHL=$(pg_restore -l "$DATEI" 2>/dev/null | grep -c '^[0-9]')
  if [ "$ANZAHL" -lt 50 ]; then
    melde "FEHLER: Abzug wirkt unvollstaendig ($ANZAHL Eintraege) - verworfen"
    rm -f "$DATEI"
    return 1
  fi

  melde "OK: auraquest-$STEMPEL.dump - $(du -h "$DATEI" | cut -f1), $ANZAHL Eintraege"

  # Rotation: nur die juengsten Abzuege behalten.
  ls -1t "$ZIEL"/auraquest-*.dump 2>/dev/null | tail -n +$((BEHALTEN + 1)) |
    while read -r ALT; do
      rm -f "$ALT"
      melde "Rotation: $(basename "$ALT") entfernt"
    done
}

melde "Sicherungsdienst gestartet - taeglich $STUNDE:$MINUTE, $BEHALTEN Abzuege"

# Beim ersten Start sofort einmal sichern. Sonst gaebe es nach einem
# Neuaufbau des Stacks bis zu 24 Stunden lang gar keine Sicherung.
if [ ! -f "$ZIEL/.erstlauf" ]; then
  sichern && touch "$ZIEL/.erstlauf"
fi

# Die Wartezeit wird aus der Uhrzeit gerechnet, nicht mit
# date -d "tomorrow". BusyBox in Alpine kennt diese GNU-Erweiterung
# nicht - der erste Entwurf schlief daher mit einer negativen Zahl und
# lief in einer Endlosschleife heiss.
#
# 10# erzwingt Dezimalinterpretation: Ohne das waere "08" eine
# ungueltige Oktalzahl, und die Sicherung bliebe zwischen 08:00 und
# 09:59 taeglich haengen.
while true; do
  H=$(date +%H)
  M=$(date +%M)
  S=$(date +%S)
  JETZT_SEK=$((10#$H * 3600 + 10#$M * 60 + 10#$S))
  ZIEL_SEK=$((10#$STUNDE * 3600 + 10#$MINUTE * 60))
  WARTEN=$((ZIEL_SEK - JETZT_SEK))
  [ "$WARTEN" -le 0 ] && WARTEN=$((WARTEN + 86400))
  sleep "$WARTEN"
  sichern
done
