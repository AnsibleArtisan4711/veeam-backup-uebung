<#
.SYNOPSIS
    Simuliert einen Netzausfall: trennt den Netzwerkadapter einer VM und verbindet ihn nach einer Zeit wieder.

.DESCRIPTION
    Merkt sich den Switch des Adapters, trennt ihn, wartet -Sekunden und verbindet ihn wieder mit demselben Switch.
    Die Wiederverbindung steht in einem finally-Block und passiert auch bei Abbruch (Strg+C).
    Start- und Endzeit werden ausgegeben, damit man sie im PRTG-Protokoll wiederfindet.
    Muss in einer administrativen PowerShell auf dem Hyper-V-Host laufen.

.PARAMETER VMName
    Name der VM (Standard NAS01).

.PARAMETER Sekunden
    Dauer des Ausfalls (Standard 180, erlaubt 30 bis 1800).

.PARAMETER AdapterName
    Name des Adapters, falls die VM mehrere hat.

.EXAMPLE
    .\02.1-ausfall-test.ps1 -VMName NAS01 -Sekunden 180 -WhatIf

.NOTES
    Zu Uebung 02.1. Nicht auf einem Host mit produktiven VMs verwenden. Die Cmdlets stammen aus dem Hyper-V-Modul.
    Getestet nur mit nachgebauten Cmdlets.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$VMName = 'NAS01',
    [ValidateRange(30, 1800)][int]$Sekunden = 180,
    [string]$AdapterName
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$adapter = @(Get-VMNetworkAdapter -VMName $VMName)
if ($AdapterName) { $adapter = @($adapter | Where-Object { $_.Name -eq $AdapterName }) }
if ($adapter.Count -ne 1) {
    throw "Erwartet genau einen Adapter, gefunden: $($adapter.Count). Bei mehreren Adaptern -AdapterName angeben."
}
$a = $adapter[0]
$switch = $a.SwitchName
if (-not $switch) { throw "Der Adapter '$($a.Name)' ist mit keinem Switch verbunden. Nichts zu trennen." }

if (-not $PSCmdlet.ShouldProcess("$VMName / $($a.Name)", "Fuer $Sekunden Sekunden vom Switch '$switch' trennen")) { return }

$start = Get-Date
Write-Host ("Ausfall beginnt: {0:yyyy-MM-dd HH:mm:ss}" -f $start)
try {
    Disconnect-VMNetworkAdapter -VMNetworkAdapter $a
    Start-Sleep -Seconds $Sekunden
}
finally {
    Connect-VMNetworkAdapter -VMNetworkAdapter $a -SwitchName $switch
    Write-Host ("Ausfall beendet: {0:yyyy-MM-dd HH:mm:ss}  (Adapter wieder mit '{1}' verbunden)" -f (Get-Date), $switch)
}
