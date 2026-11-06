#!/usr/bin/env bash
# Zu Uebung 01.1 (Backup auf NAS mit Veeam).
# Kopiert die Backup-Freigabe auf ein zweites Laufwerk (Nachbau der "USB-Platte").
# Sicherungen, damit nichts Falsches passiert:
#  1. Das Ziel muss ein eingehaengtes Laufwerk sein (sonst wuerde die Systemplatte vollgeschrieben).
#  2. Solange ueber Samba Dateien in der Freigabe geoeffnet sind, wird nicht kopiert.
#  3. Es wird nichts geloescht (kein --delete). Geloeschte Dateien bleiben auf dem Offsite-Laufwerk.
# Aufruf:  sudo bash 01.1-offsite-kopie.sh [--dry-run]
set -euo pipefail

QUELLE="${QUELLE:-/srv/backup/veeam}"
ZIEL="${ZIEL:-/mnt/offsite}"
PROTOKOLL="${PROTOKOLL:-/var/log/offsite-kopie.log}"
DRY=""
[ "${1:-}" = "--dry-run" ] && DRY="--dry-run"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$PROTOKOLL"; }

[ -d "$QUELLE" ] || { log "FEHLER: Quelle $QUELLE fehlt."; exit 1; }
if ! mountpoint -q "$ZIEL"; then
    log "FEHLER: $ZIEL ist kein eingehaengtes Laufwerk. Abbruch."
    exit 1
fi
if command -v smbstatus >/dev/null 2>&1 && smbstatus -L 2>/dev/null | grep -qF "$QUELLE"; then
    log "ABBRUCH: Es sind noch Dateien in der Freigabe geoeffnet (laeuft ein Backup?)."
    exit 2
fi

log "Start ${DRY:+(Probelauf) }$QUELLE -> $ZIEL"
rsync -a $DRY --stats "$QUELLE"/ "$ZIEL"/ >>"$PROTOKOLL" 2>&1
log "Ende"
