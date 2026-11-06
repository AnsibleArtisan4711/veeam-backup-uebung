<#
.SYNOPSIS
    Taeglicher Bericht ueber die Veeam-Backup-Sitzungen der letzten Stunden.

.DESCRIPTION
    Liest die Backup-Sitzungen der letzten -Stunden, schreibt eine CSV-Datei und eine Zusammenfassung
    und liefert einen Rueckgabewert, den eine Aufgabenplanung oder eine Ueberwachung auswerten kann:
      0 = alle Sitzungen erfolgreich und jeder erwartete Job hat gelaufen
      1 = mindestens eine Sitzung mit Warnung oder Fehler
      2 = ein erwarteter Job hat im Zeitraum gar nicht gelaufen (auch das ist ein Fehler)
    Muss auf dem Veeam-Server laufen.

.PARAMETER Stunden
    Zeitraum rueckwaerts ab jetzt (Standard 24).

.PARAMETER ErwarteteJobs
    Namen der Jobs, die im Zeitraum mindestens einmal laufen muessen.

.PARAMETER Ausgabe
    Pfad der CSV-Datei (Standard C:\Uebung\veeam-bericht.csv).

.EXAMPLE
    .\01.1-backup-bericht.ps1 -ErwarteteJobs 'Job_FS01','Job_DC01'

.NOTES
    Zu Uebung 01.1 (Backup auf NAS mit Veeam).
    NICHT BESTAETIGT: Der Modulname 'Veeam.Backup.PowerShell' und die Eigenschaften JobName, Result,
    CreationTime und EndTime der Sitzungen stammen aus der Praxis, nicht aus der Dokumentation.
    Bei Abweichungen:  Get-VBRBackupSession | Select-Object -First 1 | Get-Member
    Das Skript wurde nur mit nachgebauten Sitzungsobjekten getestet.
#>
[CmdletBinding()]
param(
    [int]$Stunden = 24,
    [string[]]$ErwarteteJobs = @(),
    [string]$Ausgabe = 'C:\Uebung\veeam-bericht.csv'
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if (-not (Get-Command -Name Get-VBRBackupSession -ErrorAction SilentlyContinue)) {
    Import-Module -Name Veeam.Backup.PowerShell -ErrorAction Stop
}

$grenze = (Get-Date).AddHours(-$Stunden)
$sitzungen = @(Get-VBRBackupSession | Where-Object { $_.CreationTime -ge $grenze } | Sort-Object CreationTime)

$zeilen = foreach ($s in $sitzungen) {
    $ende = if ($s.EndTime -and $s.EndTime -gt $s.CreationTime) { $s.EndTime } else { $null }
    [pscustomobject]@{
        Job         = $s.JobName
        Ergebnis    = [string]$s.Result
        Start       = $s.CreationTime.ToString('yyyy-MM-dd HH:mm')
        DauerMinuten = if ($ende) { [math]::Round(($ende - $s.CreationTime).TotalMinutes, 1) } else { '' }
    }
}
$zeilen = @($zeilen)

$dir = Split-Path -Parent $Ausgabe
if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$zeilen | Export-Csv -LiteralPath $Ausgabe -NoTypeInformation -Delimiter ';' -Encoding UTF8

'Veeam-Bericht, Zeitraum: letzte {0} Stunden, erstellt {1}' -f $Stunden, (Get-Date -Format 'yyyy-MM-dd HH:mm')
foreach ($z in $zeilen) {
    '{0,-8} {1,-24} {2}  {3} Min' -f $z.Ergebnis.ToUpper(), $z.Job, $z.Start, $z.DauerMinuten
}

$rueckgabe = 0
if (@($zeilen | Where-Object { $_.Ergebnis -in 'Warning', 'Failed' }).Count -gt 0) { $rueckgabe = 1 }
foreach ($job in $ErwarteteJobs) {
    if (-not ($zeilen | Where-Object { $_.Job -eq $job })) {
        'FEHLT    {0,-24} im Zeitraum kein Lauf' -f $job
        $rueckgabe = 2
    }
}
$text = switch ($rueckgabe) { 0 { 'Alles in Ordnung.' } 1 { 'Mindestens eine Sitzung mit Warnung oder Fehler.' } default { 'Ein erwarteter Job hat nicht gelaufen.' } }
'Ergebnis: {0} (Rueckgabewert {1}). CSV: {2}' -f $text, $rueckgabe, $Ausgabe
exit $rueckgabe
