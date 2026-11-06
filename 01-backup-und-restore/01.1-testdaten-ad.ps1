<#
.SYNOPSIS
    Testdaten im Active Directory fuer die Restore-Uebung: anlegen, sichern, vergleichen, loeschen.

.DESCRIPTION
    Modus Anlegen    : Legt die OU "Testbereich" mit einer Gruppe und fuenf Benutzern an (idempotent).
    Modus Sichern    : Schreibt den Ist-Zustand (Name, SID, Abteilung, Gruppen) in eine CSV-Datei.
    Modus Loeschen   : Loescht die OU samt Inhalt, um einen Ausfall zu simulieren. Verlangt vorher eine
                       Sicherung (CSV) und prueft, dass es die Test-Domaene ist.
    Modus Vergleichen: Vergleicht den aktuellen Zustand mit der CSV. Rueckgabewert 0 = alles gleich, 1 = Abweichung.
    Das Kennwort der Testkonten wird abgefragt. Es steht nicht im Skript.
    Vor dem Loeschen fragt das Skript nach, ausser mit -Force.

.PARAMETER Modus
    Anlegen, Sichern, Loeschen oder Vergleichen.

.PARAMETER Datei
    CSV mit dem gesicherten Zustand (Standard C:\Uebung\ad-vorher.csv).

.PARAMETER ErlaubteDomaene
    Nur in dieser Domaene darf geloescht werden (Schutz gegen Verwechslung).

.EXAMPLE
    .\01.1-testdaten-ad.ps1 -Modus Anlegen
    .\01.1-testdaten-ad.ps1 -Modus Sichern
    .\01.1-testdaten-ad.ps1 -Modus Loeschen -WhatIf
    .\01.1-testdaten-ad.ps1 -Modus Vergleichen

.NOTES
    Zu Uebung 01.1 (Backup auf NAS mit Veeam). Nur in der Test-Domaene verwenden.
    Die Namen sind frei erfunden. Die OU wird ohne Schutz vor versehentlichem Loeschen angelegt,
    damit der Ausfall ohne Zusatzschritt simuliert werden kann.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('Anlegen', 'Sichern', 'Loeschen', 'Vergleichen')][string]$Modus,
    [string]$OuName = 'Testbereich',
    [string]$Datei = 'C:\Uebung\ad-vorher.csv',
    [string]$ErlaubteDomaene = 'alpenwerk.example',
    [securestring]$InitialPassword,
    [switch]$Force
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$domaene = Get-ADDomain
$ouDn = 'OU={0},{1}' -f $OuName, $domaene.DistinguishedName
$gruppenName = 'GG_Testbereich'

function Get-Zustand {
    # Liefert je Benutzer der OU: Name, SID, Abteilung, Gruppen (sortiert, mit | getrennt)
    Get-ADUser -Filter * -SearchBase $ouDn -Properties Department, MemberOf | Sort-Object SamAccountName | ForEach-Object {
        $gruppen = @($_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=', '' } | Sort-Object) -join '|'
        [pscustomobject]@{
            SamAccountName = $_.SamAccountName
            SID            = $_.SID.Value
            Abteilung      = $_.Department
            Gruppen        = $gruppen
        }
    }
}

switch ($Modus) {
    'Anlegen' {
        if (-not $InitialPassword) { $InitialPassword = Read-Host -AsSecureString 'Startkennwort fuer die Testkonten (Komplexitaet beachten)' }
        $vorhanden = $null
        try { $vorhanden = Get-ADOrganizationalUnit -Identity $ouDn -ErrorAction Stop } catch { }
        if (-not $vorhanden) {
            if ($PSCmdlet.ShouldProcess($ouDn, 'OU anlegen')) {
                New-ADOrganizationalUnit -Name $OuName -Path $domaene.DistinguishedName -ProtectedFromAccidentalDeletion $false
            }
        }
        if (-not (Get-ADGroup -Filter "Name -eq '$gruppenName'" -SearchBase $ouDn -ErrorAction SilentlyContinue)) {
            if ($PSCmdlet.ShouldProcess($gruppenName, 'Gruppe anlegen')) {
                New-ADGroup -Name $gruppenName -SamAccountName $gruppenName -GroupScope Global -GroupCategory Security -Path $ouDn
            }
        }
        $personen = @(
            @('Berta', 'Kern', 'b.kern', 9001, 'Vertrieb'),
            @('Cem', 'Aydin', 'c.aydin', 9002, 'Produktion'),
            @('Dora', 'Fink', 'd.fink', 9003, 'IT'),
            @('Emil', 'Gruber', 'e.gruber', 9004, 'Verwaltung'),
            @('Fiona', 'Haas', 'f.haas', 9005, 'Vertrieb')
        )
        foreach ($p in $personen) {
            $sam = $p[2]
            if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) { '{0,-12} vorhanden' -f $sam; continue }
            if ($PSCmdlet.ShouldProcess($sam, 'Benutzer anlegen')) {
                New-ADUser -Name ('{0} {1}' -f $p[0], $p[1]) -GivenName $p[0] -Surname $p[1] -SamAccountName $sam `
                    -UserPrincipalName ('{0}@{1}' -f $sam, $domaene.DNSRoot) -EmployeeID ([string]$p[3]) -Department $p[4] `
                    -Path $ouDn -AccountPassword $InitialPassword -Enabled $true -ChangePasswordAtLogon $true
                Add-ADGroupMember -Identity $gruppenName -Members $sam
                '{0,-12} angelegt' -f $sam
            }
        }
    }
    'Sichern' {
        $z = @(Get-Zustand)
        if ($z.Count -eq 0) { throw "In $ouDn wurden keine Benutzer gefunden." }
        $dir = Split-Path -Parent $Datei
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $z | Export-Csv -LiteralPath $Datei -NoTypeInformation -Delimiter ';' -Encoding UTF8
        '{0} Benutzer gesichert: {1}' -f $z.Count, $Datei
    }
    'Loeschen' {
        if ($domaene.DNSRoot -ne $ErlaubteDomaene) { throw "Abbruch: Domaene ist '$($domaene.DNSRoot)', erlaubt ist nur '$ErlaubteDomaene'." }
        if (-not (Test-Path -LiteralPath $Datei)) { throw "Abbruch: Erst '-Modus Sichern' ausfuehren ($Datei fehlt)." }
        if ($PSCmdlet.ShouldProcess($ouDn, 'OU samt Inhalt loeschen (Ausfall simulieren)') -and
            ($Force -or $PSCmdlet.ShouldContinue("Gibt es ein Backup des Domaenencontrollers? $ouDn wird samt Inhalt geloescht.", 'Ausfall simulieren'))) {
            Set-ADOrganizationalUnit -Identity $ouDn -ProtectedFromAccidentalDeletion $false
            Remove-ADOrganizationalUnit -Identity $ouDn -Recursive -Confirm:$false
            'Geloescht: {0}' -f $ouDn
        }
    }
    'Vergleichen' {
        if (-not (Test-Path -LiteralPath $Datei)) { throw "CSV fehlt: $Datei" }
        $jetzt = @{}
        try { Get-Zustand | ForEach-Object { $jetzt[$_.SamAccountName] = $_ } } catch { }
        $fehler = 0
        foreach ($alt in (Import-Csv -LiteralPath $Datei -Delimiter ';')) {
            $neu = $jetzt[$alt.SamAccountName]
            if (-not $neu) { $status = 'FEHLT' }
            else {
                $abw = @()
                if ($neu.SID -ne $alt.SID) { $abw += 'SID' }
                if ($neu.Abteilung -ne $alt.Abteilung) { $abw += 'Abteilung' }
                if ($neu.Gruppen -ne $alt.Gruppen) { $abw += 'Gruppen' }
                $status = if ($abw.Count) { 'ABWEICHEND: ' + ($abw -join ', ') } else { 'OK' }
            }
            if ($status -ne 'OK') { $fehler++ }
            '{0,-12} {1}' -f $alt.SamAccountName, $status
        }
        if ($fehler -gt 0) { '{0} Abweichung(en).' -f $fehler; exit 1 } else { 'Zustand stimmt mit der Sicherung ueberein.' }
    }
}
