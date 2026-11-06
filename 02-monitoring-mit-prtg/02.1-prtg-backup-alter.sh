#!/usr/bin/env bash
# Zu Uebung 02.1 (Monitoring der Backup-Umgebung mit PRTG).
# Eigener Sensor fuer PRTG "SSH Script Advanced": meldet das Alter der neuesten Veeam-Sicherungsdatei.
# Ablage auf dem NAS:  /var/prtg/scriptsxml/02.1-prtg-backup-alter.sh   (ausfuehrbar, chmod 755)
# Parameter (alle optional):
#   $1  Ordner mit den Sicherungsdateien   (Standard /srv/backup/veeam)
#   $2  Warnung ab so vielen Stunden       (Standard 26)
#   $3  Fehler ab so vielen Stunden        (Standard 50)
# Ausgabe: XML fuer PRTG auf der Standardausgabe. Fehler werden als <error> gemeldet, der Rueckgabewert ist immer 0.
# Hinweis: Die Grenzwerte (LimitMode, LimitMaxWarning, LimitMaxError) wendet PRTG nur an, wenn der Kanal
# neu angelegt wird. Spaetere Aenderungen im Skript wirken nicht auf einen bestehenden Sensor.
set -u

PFAD="${1:-/srv/backup/veeam}"
WARN="${2:-26}"
FEHLER="${3:-50}"

xml_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
fehler() {
    printf '<prtg><error>1</error><text>%s</text></prtg>\n' "$(printf '%s' "$1" | xml_escape)"
    exit 0
}

case "$WARN$FEHLER" in
    *[!0-9]*) fehler "Warn- und Fehlerwert muessen ganze Zahlen sein." ;;
esac
[ "$WARN" -lt "$FEHLER" ] || fehler "Der Warnwert muss kleiner sein als der Fehlerwert."
[ -d "$PFAD" ] || fehler "Ordner nicht gefunden: $PFAD"

# Neueste Sicherungsdatei (Voll- oder Inkrementdatei) nach Aenderungszeit
neueste="$(find "$PFAD" -type f \( -name '*.vbk' -o -name '*.vib' \) -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1)"
[ -n "$neueste" ] || fehler "Keine .vbk- oder .vib-Datei in $PFAD"

zeit="${neueste%% *}"
datei="${neueste#* }"
jetzt="$(date +%s)"
alter="$(awk -v j="$jetzt" -v z="$zeit" 'BEGIN { a = (j - z) / 3600; if (a < 0) a = 0; printf "%.1f", a }')"
anzahl="$(find "$PFAD" -type f \( -name '*.vbk' -o -name '*.vib' \) 2>/dev/null | wc -l | tr -d ' ')"
name="$(basename "$datei" | xml_escape)"

cat <<XML
<prtg>
  <result>
    <channel>Alter neueste Sicherung</channel>
    <value>${alter}</value>
    <unit>Custom</unit>
    <customunit>h</customunit>
    <float>1</float>
    <limitmode>1</limitmode>
    <limitmaxwarning>${WARN}</limitmaxwarning>
    <limitmaxerror>${FEHLER}</limitmaxerror>
    <limitwarningmsg>Sicherung aelter als ${WARN} Stunden</limitwarningmsg>
    <limiterrormsg>Sicherung aelter als ${FEHLER} Stunden</limiterrormsg>
  </result>
  <result>
    <channel>Anzahl Sicherungsdateien</channel>
    <value>${anzahl}</value>
  </result>
  <text>Neueste Datei: ${name}</text>
</prtg>
XML
exit 0
