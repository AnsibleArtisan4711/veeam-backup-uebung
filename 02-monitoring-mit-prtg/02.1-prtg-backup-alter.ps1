<#
.SYNOPSIS
    PRTG-Sensor (EXE/Script Advanced): Alter der neuesten Veeam-Sicherungsdatei.

.DESCRIPTION
    Sucht im angegebenen Ordner die neueste .vbk- oder .vib-Datei und meldet ihr Alter in Stunden
    sowie die Anzahl der Dateien als XML fuer PRTG. Fehler (Ordner fehlt, keine Datei, falsche Grenzwerte)
    werden als <error> gemeldet. Der Rueckgabewert ist immer 0.
    Ablage auf dem PRTG-Server:  <PRTG-Programmordner>\Custom Sensors\EXEXML\

.PARAMETER Pfad
    Ordner mit den Sicherungsdateien, lokal oder als Netzwerkpfad.

.PARAMETER WarnStunden
    Warnung ab so vielen Stunden (Standard 26).

.PARAMETER FehlerStunden
    Fehler ab so vielen Stunden (Standard 50).

.EXAMPLE
    .\02.1-prtg-backup-alter.ps1 -Pfad 'D:\Test' -WarnStunden 26 -FehlerStunden 50

.NOTES
    Zu Uebung 02.1. Das Skript laeuft auf dem PRTG-Server (bzw. der Probe), nicht auf dem Zielgeraet.
    Ein Netzwerkpfad muss fuer das Konto erreichbar sein, unter dem der PRTG-Sondendienst laeuft.
    PRTG wendet die Grenzwerte nur beim Anlegen des Kanals an.
    Das Format der Ausgabe stammt aus dem PRTG-Handbuch (Custom Sensors).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Pfad,
    [int]$WarnStunden = 26,
    [int]$FehlerStunden = 50
)
$ErrorActionPreference = 'Stop'

function ConvertTo-XmlText([string]$Text) {
    return [System.Security.SecurityElement]::Escape($Text)
}
function Write-PrtgError([string]$Text) {
    Write-Output ('<prtg><error>1</error><text>{0}</text></prtg>' -f (ConvertTo-XmlText $Text))
    exit 0
}

try {
    if ($WarnStunden -ge $FehlerStunden) { Write-PrtgError 'Der Warnwert muss kleiner sein als der Fehlerwert.' }
    if (-not (Test-Path -LiteralPath $Pfad -PathType Container)) { Write-PrtgError "Ordner nicht gefunden: $Pfad" }

    $dateien = @(Get-ChildItem -LiteralPath $Pfad -File -Recurse -ErrorAction Stop |
        Where-Object { $_.Extension -in '.vbk', '.vib' })
    if ($dateien.Count -eq 0) { Write-PrtgError "Keine .vbk- oder .vib-Datei in $Pfad" }

    $neueste = $dateien | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    $alterH = [math]::Max(0, ((Get-Date).ToUniversalTime() - $neueste.LastWriteTimeUtc).TotalHours)
    $alterText = $alterH.ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)

    $xml = @"
<prtg>
  <result>
    <channel>Alter neueste Sicherung</channel>
    <value>$alterText</value>
    <unit>Custom</unit>
    <customunit>h</customunit>
    <float>1</float>
    <limitmode>1</limitmode>
    <limitmaxwarning>$WarnStunden</limitmaxwarning>
    <limitmaxerror>$FehlerStunden</limitmaxerror>
    <limitwarningmsg>Sicherung aelter als $WarnStunden Stunden</limitwarningmsg>
    <limiterrormsg>Sicherung aelter als $FehlerStunden Stunden</limiterrormsg>
  </result>
  <result>
    <channel>Anzahl Sicherungsdateien</channel>
    <value>$($dateien.Count)</value>
  </result>
  <text>Neueste Datei: $(ConvertTo-XmlText $neueste.Name)</text>
</prtg>
"@
    Write-Output $xml
}
catch {
    Write-PrtgError ("Skriptfehler: " + $_.Exception.Message)
}
exit 0
