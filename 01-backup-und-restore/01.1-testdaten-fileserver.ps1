<#
.SYNOPSIS
    Legt Testdaten auf dem Dateiserver an und prueft sie nach einer Wiederherstellung.

.DESCRIPTION
    Modus Anlegen : Erzeugt Ordner und Dateien mit festem Inhalt und schreibt eine Pruefliste
                    (Pfad und SHA-256-Pruefsumme) nach -Pruefliste.
    Modus Pruefen : Liest die Pruefliste und meldet je Datei OK, FEHLT oder ABWEICHEND.
                    Rueckgabewert 0 = alles in Ordnung, 1 = mindestens eine Abweichung.
    Modus Loeschen: Loescht eine Datei (-Datei, relativ zum Datenordner), um einen Ausfall zu simulieren.

.PARAMETER Modus
    Anlegen, Pruefen oder Loeschen.

.PARAMETER Pfad
    Datenordner (Standard C:\Daten).

.PARAMETER Pruefliste
    CSV mit den Pruefsummen (Standard C:\Uebung\pruefliste.csv).

.PARAMETER Datei
    Nur fuer Loeschen: relativer Pfad, z. B. Vertrieb/Angebot-2026-001.txt.

.EXAMPLE
    .\01.1-testdaten-fileserver.ps1 -Modus Anlegen
    .\01.1-testdaten-fileserver.ps1 -Modus Loeschen -Datei Vertrieb/Angebot-2026-001.txt -WhatIf
    .\01.1-testdaten-fileserver.ps1 -Modus Pruefen

.NOTES
    Zu Uebung 01.1 (Backup auf NAS mit Veeam). Nur in der Test-Umgebung verwenden.
    Die Dateien sind frei erfunden.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('Anlegen', 'Pruefen', 'Loeschen')][string]$Modus,
    [string]$Pfad = 'C:\Daten',
    [string]$Pruefliste = 'C:\Uebung\pruefliste.csv',
    [string]$Datei
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-Relativ {
    # Relativer Pfad mit / als Trenner (unabhaengig vom Betriebssystem)
    param([string]$Voll, [string]$Basis)
    $b = (Resolve-Path -LiteralPath $Basis).Path.TrimEnd('\', '/')
    $Voll.Substring($b.Length).TrimStart('\', '/') -replace '\\', '/'
}

switch ($Modus) {
    'Anlegen' {
        $ordner = 'Vertrieb', 'Produktion', 'IT', 'Verwaltung'
        $zaehler = 0
        foreach ($o in $ordner) {
            $dir = Join-Path $Pfad $o
            if ($PSCmdlet.ShouldProcess($dir, 'Ordner anlegen')) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            1..3 | ForEach-Object {
                $name = '{0}-2026-{1:000}.txt' -f $(switch ($o) { 'Vertrieb' { 'Angebot' } 'Produktion' { 'Auftrag' } 'IT' { 'Notiz' } default { 'Vorgang' } }), $_
                $inhalt = (1..20 | ForEach-Object { 'Zeile {0} von {1}/{2}: erfundener Beispielinhalt fuer die Backup-Uebung.' -f $_, $o, $name }) -join "`r`n"
                $ziel = Join-Path $dir $name
                if ($PSCmdlet.ShouldProcess($ziel, 'Datei schreiben')) {
                    Set-Content -LiteralPath $ziel -Value $inhalt -Encoding UTF8
                    $zaehler++
                }
            }
        }
        if ($WhatIfPreference) { return }
        $liste = Get-ChildItem -LiteralPath $Pfad -Recurse -File | Sort-Object FullName | ForEach-Object {
            [pscustomobject]@{
                Pfad   = Get-Relativ -Voll $_.FullName -Basis $Pfad
                SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            }
        }
        $dirListe = Split-Path -Parent $Pruefliste
        if ($dirListe -and -not (Test-Path -LiteralPath $dirListe)) { New-Item -ItemType Directory -Path $dirListe -Force | Out-Null }
        $liste | Export-Csv -LiteralPath $Pruefliste -NoTypeInformation -Delimiter ';' -Encoding UTF8
        '{0} Dateien angelegt, Pruefliste: {1}' -f $zaehler, $Pruefliste
    }
    'Loeschen' {
        if (-not $Datei) { throw 'Bitte -Datei angeben, z. B. Vertrieb/Angebot-2026-001.txt' }
        $ziel = Join-Path $Pfad $Datei
        if (-not (Test-Path -LiteralPath $ziel)) { throw "Datei nicht gefunden: $ziel" }
        if ($PSCmdlet.ShouldProcess($ziel, 'Datei loeschen (Ausfall simulieren)')) {
            Remove-Item -LiteralPath $ziel
            'Geloescht: {0}' -f $ziel
        }
    }
    'Pruefen' {
        if (-not (Test-Path -LiteralPath $Pruefliste)) { throw "Pruefliste fehlt: $Pruefliste" }
        $fehler = 0
        foreach ($z in (Import-Csv -LiteralPath $Pruefliste -Delimiter ';')) {
            $voll = Join-Path $Pfad $z.Pfad
            if (-not (Test-Path -LiteralPath $voll)) { $status = 'FEHLT' }
            elseif ((Get-FileHash -LiteralPath $voll -Algorithm SHA256).Hash -ne $z.SHA256) { $status = 'ABWEICHEND' }
            else { $status = 'OK' }
            if ($status -ne 'OK') { $fehler++ }
            '{0,-11} {1}' -f $status, $z.Pfad
        }
        if ($fehler -gt 0) { '{0} Abweichung(en).' -f $fehler; exit 1 } else { 'Alle Dateien stimmen mit der Pruefliste ueberein.' }
    }
}
