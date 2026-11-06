# Modul 01: Backup und Restore

| Datei | Zweck |
|---|---|
| [01.1-backup-auf-nas-mit-veeam.md](01.1-backup-auf-nas-mit-veeam.md) | Übung mit Hintergrund, Prüfbefehlen, Musterlösung |
| `01.1-nas-einrichten.sh` | Samba-Freigabe als NAS-Nachbau (nicht in der Domäne, lokales Konto) |
| `01.1-testdaten-fileserver.ps1` | Testdateien anlegen, Ausfall simulieren, Wiederherstellung per Prüfsumme prüfen |
| `01.1-testdaten-ad.ps1` | OU und Testbenutzer anlegen, Zustand sichern, löschen, vergleichen |
| `01.1-backup-bericht.ps1` | Täglicher Bericht über die Veeam-Sitzungen (Rückgabewert 0/1/2) |
| `01.1-offsite-kopie.sh` | Kopie auf ein zweites Laufwerk, mit Schutz vor falschem Ziel und laufenden Backups |

PowerShell-Skripte sind UTF-8 mit BOM gespeichert (Windows PowerShell 5.1). Shell-Skripte haben Unix-Zeilenenden. Beim Kopieren Kodierung und Zeilenenden beibehalten.
