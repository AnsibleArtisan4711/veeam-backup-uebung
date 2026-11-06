#!/usr/bin/env bash
# Zu Uebung 02.1 (Monitoring der Backup-Umgebung mit PRTG).
# Bereitet die NAS-VM (Debian/Ubuntu) fuer PRTG vor:
#  1. SNMP-Dienst (snmpd) mit einem SNMPv3-Benutzer (SHA/AES), nur Lesezugriff
#  2. lokales Konto fuer SSH-Sensoren (Standard prtgmon), darf die Sicherungsordner nur lesen
#  3. Ordner /var/prtg/scriptsxml fuer eigene SSH-Sensoren
# Kennwoerter werden abgefragt (mindestens 8 Zeichen) und stehen nicht im Skript.
# Aufruf als root:  sudo bash 02.1-snmp-auf-nas.sh
# Optional: SNMP_USER, MON_USER, SHARE_PATH, SNMP_LISTEN (Standard udp:161) als Umgebungsvariablen.
set -euo pipefail

SNMP_USER="${SNMP_USER:-prtgmon}"
MON_USER="${MON_USER:-prtgmon}"
SHARE_PATH="${SHARE_PATH:-/srv/backup/veeam}"
SNMP_LISTEN="${SNMP_LISTEN:-udp:161}"
SNMPD_CONF="${SNMPD_CONF:-/etc/snmp/snmpd.conf}"
SNMPD_VAR="${SNMPD_VAR:-/var/lib/snmp/snmpd.conf}"
SCRIPT_DIR="${SCRIPT_DIR:-/var/prtg/scriptsxml}"
MARKER="# --- Uebung 02.1 ---"

if [ "$(id -u)" -ne 0 ]; then
    echo "Bitte als root ausfuehren (sudo)." >&2
    exit 1
fi
case "$SNMP_USER$MON_USER" in
    *[!A-Za-z0-9_-]*) echo "Benutzernamen duerfen nur Buchstaben, Ziffern, _ und - enthalten." >&2; exit 1 ;;
esac

frage_kennwort() {
    local frage="$1" a b
    while true; do
        read -r -s -p "$frage: " a; echo
        if [ "${#a}" -lt 8 ]; then echo "    Mindestens 8 Zeichen (Vorgabe von SNMPv3)."; continue; fi
        case "$a" in *\"*|*\\*) echo "    Bitte kein Anfuehrungszeichen und keinen Backslash verwenden."; continue ;; esac
        read -r -s -p "    Zur Kontrolle nochmal: " b; echo
        [ "$a" = "$b" ] && { REPLY_PW="$a"; return; }
        echo "    Eingaben unterschiedlich."
    done
}

echo "1/4 Pakete installieren (snmpd, acl)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq snmpd acl

if grep -qF "$MARKER" "$SNMPD_CONF" 2>/dev/null; then
    echo "2/4 SNMP ist schon eingerichtet (Marker gefunden), uebersprungen."
else
    echo "2/4 SNMPv3-Benutzer ${SNMP_USER} anlegen"
    frage_kennwort "SNMP-Authentifizierungskennwort (SHA)"; AUTH_PW="$REPLY_PW"
    frage_kennwort "SNMP-Verschluesselungskennwort (AES)"; PRIV_PW="$REPLY_PW"
    systemctl stop snmpd
    # net-snmp liest "createUser" beim Start, wandelt es in Schluessel um und entfernt die Zeile wieder
    umask 077
    printf 'createUser %s SHA "%s" AES "%s"\n' "$SNMP_USER" "$AUTH_PW" "$PRIV_PW" >> "$SNMPD_VAR"
    unset AUTH_PW PRIV_PW
    chmod 600 "$SNMPD_VAR"
    cp -n "$SNMPD_CONF" "${SNMPD_CONF}.vor-uebung" 2>/dev/null || true
    umask 022
    cat >> "$SNMPD_CONF" <<EOF

${MARKER}
agentaddress ${SNMP_LISTEN}
rouser ${SNMP_USER} priv
sysLocation Backup-Labor (Uebung)
sysContact admin@alpenwerk.example
EOF
    systemctl enable snmpd >/dev/null 2>&1 || true
    systemctl restart snmpd
fi

echo "3/4 Konto ${MON_USER} fuer SSH-Sensoren (nur lesen)"
if ! id "$MON_USER" >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash "$MON_USER"
    echo "    Kennwort fuer ${MON_USER} setzen (fuer die SSH-Anmeldung von PRTG):"
    passwd "$MON_USER"
fi
if [ -d "$SHARE_PATH" ]; then
    setfacl -R -m "u:${MON_USER}:rX" "$SHARE_PATH"
    setfacl -R -d -m "u:${MON_USER}:rX" "$SHARE_PATH"
else
    echo "    Hinweis: ${SHARE_PATH} existiert nicht, ACL nicht gesetzt."
fi

echo "4/4 Ordner fuer eigene Sensoren"
mkdir -p "$SCRIPT_DIR"
chmod 755 "$SCRIPT_DIR"

echo
echo "Fertig. Pruefen (von einem anderen Rechner mit dem Paket 'snmp'):"
echo "  snmpget -v3 -l authPriv -u ${SNMP_USER} -a SHA -A '<auth>' -x AES -X '<priv>' <IP dieser VM> 1.3.6.1.2.1.1.1.0"
echo "Eigenen Sensor ablegen:  install -m 755 02.1-prtg-backup-alter.sh ${SCRIPT_DIR}/"
