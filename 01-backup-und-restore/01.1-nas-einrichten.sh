#!/usr/bin/env bash
# Zu Uebung 01.1 (Backup auf NAS mit Veeam).
# Richtet auf einer Debian- oder Ubuntu-VM eine Samba-Freigabe als NAS-Nachbau ein.
#  - Die VM wird NICHT in die Active-Directory-Domaene aufgenommen.
#  - Zugriff hat nur ein lokales Konto (Standard: vbr_backup).
#  - Das Kennwort wird interaktiv abgefragt, es steht nicht im Skript.
# Aufruf als root:  sudo bash 01.1-nas-einrichten.sh
# Anderes Konto, Pfad oder Freigabename:  sudo BACKUP_USER=x SHARE_PATH=/srv/x bash 01.1-nas-einrichten.sh
set -euo pipefail

SHARE_NAME="${SHARE_NAME:-VeeamBackups}"
SHARE_PATH="${SHARE_PATH:-/srv/backup/veeam}"
BACKUP_USER="${BACKUP_USER:-vbr_backup}"
BACKUP_GROUP="${BACKUP_GROUP:-vbrbackup}"
SMB_CONF="${SMB_CONF:-/etc/samba/smb.conf}"
MARKER="# --- Uebung 01.1: ${SHARE_NAME} ---"

if [ "$(id -u)" -ne 0 ]; then
    echo "Bitte als root ausfuehren (sudo)." >&2
    exit 1
fi

echo "1/5 Samba installieren"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq samba

echo "2/5 Lokales Konto und Gruppe anlegen (ohne Login-Shell, ohne Home)"
getent group "$BACKUP_GROUP" >/dev/null || groupadd --system "$BACKUP_GROUP"
if ! id "$BACKUP_USER" >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin -G "$BACKUP_GROUP" "$BACKUP_USER"
fi

echo "3/5 Ordner anlegen, nur fuer die Gruppe zugaenglich"
mkdir -p "$SHARE_PATH"
chown root:"$BACKUP_GROUP" "$SHARE_PATH"
chmod 2770 "$SHARE_PATH"

echo "4/5 Freigabe in ${SMB_CONF} eintragen"
if grep -qF "$MARKER" "$SMB_CONF"; then
    echo "    Eintrag ist schon vorhanden, nichts geaendert."
else
    cp -n "$SMB_CONF" "${SMB_CONF}.vor-uebung" || true
    cat >> "$SMB_CONF" <<EOF

${MARKER}
[${SHARE_NAME}]
   path = ${SHARE_PATH}
   valid users = ${BACKUP_USER}
   read only = no
   browseable = no
   create mask = 0660
   directory mask = 0770
   force group = ${BACKUP_GROUP}
EOF
fi
testparm -s >/dev/null

echo "5/5 SMB-Kennwort fuer ${BACKUP_USER} setzen"
if pdbedit -L 2>/dev/null | cut -d: -f1 | grep -qx "$BACKUP_USER"; then
    echo "    Konto hat schon ein SMB-Kennwort. Neu setzen mit: smbpasswd ${BACKUP_USER}"
else
    smbpasswd -a "$BACKUP_USER"
fi
systemctl restart smbd

echo
echo "Fertig. Freigabe: \\\\<IP dieser VM>\\${SHARE_NAME}  Konto: ${BACKUP_USER}"
echo "Pruefen:  smbclient -L localhost -N   und   testparm -s"
