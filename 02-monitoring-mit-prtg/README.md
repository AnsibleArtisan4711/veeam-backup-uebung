# Modul 02: Monitoring mit PRTG

| Datei | Zweck |
|---|---|
| [02.1-monitoring-der-backup-umgebung-mit-prtg.md](02.1-monitoring-der-backup-umgebung-mit-prtg.md) | Übung mit Hintergrund, Prüfbefehlen, Musterlösung |
| `02.1-monitoring-benutzer.ps1` | Dienstkonto für WMI ohne Administratorrechte (Active Directory, `-WhatIf` möglich) |
| `02.1-snmp-auf-nas.sh` | NAS-VM: SNMPv3-Benutzer, Konto für SSH-Sensoren (nur lesen), Ordner für eigene Sensoren |
| `02.1-prtg-backup-alter.sh` | Eigener PRTG-Sensor (SSH Script Advanced): Alter der neuesten Sicherungsdatei |
| `02.1-prtg-backup-alter.ps1` | Derselbe Sensor für Windows (EXE/Script Advanced) |
| `02.1-ausfall-test.ps1` | Netzausfall einer VM simulieren, Adapter wird immer wieder verbunden (auf dem Hyper-V-Host) |

PowerShell-Skripte sind UTF-8 mit BOM gespeichert (Windows PowerShell 5.1). Shell-Skripte haben Unix-Zeilenenden. Beim Kopieren Kodierung und Zeilenenden beibehalten. PRTG ist Kommerzsoftware von Paessler (Freeware bis 100 Sensoren) und nicht Teil dieses Repositories.
