# Veeam-Übung: Backup auf NAS und Restore

Praxisübung zu Datensicherung und Wiederherstellung in einer **eigenen, isolierten Test-Umgebung** (vier Hyper-V-VMs, privater Switch): Backup mit Veeam Backup & Replication (Community Edition) auf einen NAS-Nachbau, Restore von Dateien und Active-Directory-Objekten, Konfigurationssicherung, Bericht und Offsite-Kopie. Dazu ein Modul zur Überwachung dieser Umgebung mit PRTG. Alle Namen, Firmen und Domänen sind frei erfunden (`alpenwerk.example`).

## Inhalt

| Modul | Übung | Stufe |
|---|---|---|
| [01-backup-und-restore](01-backup-und-restore/) | 01.1 Backup auf NAS mit Veeam (Einrichten, Restore, Betrieb) | Aufbau |
| [02-monitoring-mit-prtg](02-monitoring-mit-prtg/) | 02.1 Monitoring der Backup-Umgebung mit PRTG (Aufbau, SNMPv3/WMI, eigener Sensor, Ausfalltests) | Aufbau |

## Stand

**Entwurf.** Die Skripte wurden mit nachgebauten Umgebungen getestet (nachgebautes Active Directory, nachgebaute Veeam-Sitzungen). **Veeam und PRTG selbst wurden nicht ausgeführt.** Die Sensor-Skripte (Modul 02) wurden zusätzlich mit echten Testdateien geprüft, ihr XML-Format stammt aus dem PRTG-Handbuch. Menünamen und Abläufe in Veeam und PRTG stammen aus der Praxis (Version 12) und sind in der Übung als „nicht bestätigt“ gekennzeichnet, soweit nicht gegen die Dokumentation geprüft. Abweichungen bitte als Issue melden.

## Sicherheit

- Nur in einer isolierten Testumgebung ausführen, nie in einer produktiven Umgebung.
- Die Skripte enthalten und protokollieren keine Kennwörter.
- `01.1-testdaten-ad.ps1 -Modus Loeschen` löscht eine OU und prüft vorher den Domänennamen und die vorhandene Sicherung.
- Veeam ist Kommerzsoftware. Die Übung setzt die kostenlose Community Edition voraus (Download mit Registrierung bei Veeam, nicht Teil dieses Repositories). PRTG ist Kommerzsoftware von Paessler, die Freeware reicht aus (nicht Teil dieses Repositories).

## Lizenz

Skripte: MIT ([LICENSE](LICENSE)). Texte und Anleitungen: CC BY-NC-SA 4.0 ([LICENSE-DOCS.md](LICENSE-DOCS.md)). Veeam ist eine Marke von Veeam Software, PRTG und Paessler sind Marken der Paessler GmbH, Microsoft, Windows und Active Directory sind Marken der Microsoft-Gruppe, Debian und Samba Marken ihrer Inhaber. Dieses Projekt steht in keiner Verbindung zu diesen Unternehmen.
