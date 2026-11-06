<#
.SYNOPSIS
    Legt das Dienstkonto fuer die WMI-Abfragen von PRTG an (ohne Administratorrechte).

.DESCRIPTION
    - erstellt ein Domaenenkonto (Standard svc_prtg_wmi) in der angegebenen OU bzw. im Container "Users",
    - setzt Kennwort (wird abgefragt), "Kennwort laeuft nie ab" und "darf Kennwort nicht aendern",
    - nimmt das Konto in die Gruppen "Performance Log Users" und "Distributed COM Users" auf.
    Auf Mitgliedsservern gelten diese Gruppen lokal. Dort muss das Konto per Gruppenrichtlinie
    (eingeschraenkte Gruppen) oder von Hand aufgenommen werden (siehe Uebung).
    Das Recht auf den WMI-Namespace wird NICHT gesetzt, dafuer gibt es in der Uebung eine Anleitung.
    Voraussetzung: PowerShell-Modul ActiveDirectory (RSAT), Rechte zum Anlegen von Konten.

.PARAMETER Benutzer
    Kontoname (Standard svc_prtg_wmi).

.PARAMETER Pfad
    Distinguished Name der Ziel-OU (Standard: Container "Users" der Domaene).

.EXAMPLE
    .\02.1-monitoring-benutzer.ps1 -WhatIf

.NOTES
    Zu Uebung 02.1. Das Skript gibt das Kennwort nirgends aus und speichert es nicht.
    Nicht bestaetigt: Gruppennamen auf einer nicht englischen Windows-Version (dort heissen die Gruppen anders).
    Getestet mit einem nachgebauten ActiveDirectory-Modul, nicht in einer echten Domaene.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Benutzer = 'svc_prtg_wmi',
    [string]$Pfad
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$domain = Get-ADDomain
if (-not $Pfad) { $Pfad = "CN=Users,$($domain.DistinguishedName)" }
$gruppen = @('Performance Log Users', 'Distributed COM Users')

foreach ($g in $gruppen) {
    if (-not (Get-ADGroup -Filter "Name -eq '$g'" -ErrorAction SilentlyContinue)) {
        throw "Gruppe '$g' nicht gefunden. Auf einer deutschen Windows-Version heisst sie anders (Gruppennamen in AD pruefen)."
    }
}

$vorhanden = Get-ADUser -Filter "SamAccountName -eq '$Benutzer'" -ErrorAction SilentlyContinue
if ($vorhanden) {
    Write-Host "Konto $Benutzer existiert bereits, wird nicht veraendert. Nur die Gruppenmitgliedschaft wird geprueft."
}
else {
    if ($PSCmdlet.ShouldProcess("$Benutzer in $Pfad", 'Dienstkonto anlegen')) {
        $pw = Read-Host -Prompt "Kennwort fuer $Benutzer (Uebungskennwort)" -AsSecureString
        New-ADUser -Name $Benutzer -SamAccountName $Benutzer `
            -UserPrincipalName "$Benutzer@$($domain.DNSRoot)" `
            -Description 'PRTG-Dienstkonto, nur Lesezugriff (Uebung 02.1)' `
            -Path $Pfad -AccountPassword $pw -Enabled $true `
            -PasswordNeverExpires $true -CannotChangePassword $true
    }
}

foreach ($g in $gruppen) {
    $mitglieder = @(Get-ADGroupMember -Identity $g -ErrorAction SilentlyContinue | ForEach-Object { $_.SamAccountName })
    if ($mitglieder -contains $Benutzer) {
        Write-Host "$Benutzer ist schon Mitglied in '$g'."
    }
    elseif ($PSCmdlet.ShouldProcess("$Benutzer", "Zu Gruppe '$g' hinzufuegen")) {
        Add-ADGroupMember -Identity $g -Members $Benutzer
        Write-Host "$Benutzer zu '$g' hinzugefuegt."
    }
}
Write-Host 'Fertig. Weiter: WMI-Namespace-Recht (siehe Uebung) und Eintrag in PRTG auf Gruppenebene.'
