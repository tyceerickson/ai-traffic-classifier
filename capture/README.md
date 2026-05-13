# Capture

This directory documents the OPNsense continuous capture configuration.
No scripts run here — OPNsense handles capture natively. This README
documents how it is configured for reproducibility.

## OPNsense Capture Setup (Milestone 1)

### Packet Capture
- **Interface:** The interface bridging VLAN 20 (attackers) and VLAN 30 (victims)
- **Method:** OPNsense built-in packet capture or `tcpdump` via SSH
- **Rotation:** Files rotate every 60 minutes or at 500MB, whichever comes first
- **Storage path on OPNsense:** `/var/capturedata/`
- **Retention:** Last 24 hours kept on OPNsense; older files rsync'd to Ubuntu Server

### Suricata IDS
- **Enabled:** Yes — running on the VLAN 20 → VLAN 30 interface
- **Ruleset:** ET Open (Emerging Threats)
- **Alert log path:** `/var/log/suricata/eve.json`
- **Alert log also rsync'd** to Ubuntu Server alongside PCAPs

### rsync Setup
OPNsense pushes files to Ubuntu Server on a schedule:
```bash
# On OPNsense — runs via cron every 60 minutes
rsync -av /var/capturedata/ ubuntu@192.168.10.4:/opt/pcaps/
rsync -av /var/log/suricata/eve.json ubuntu@192.168.10.4:/opt/suricata/
```

## What Gets Captured

All traffic flowing between:
- **VLAN 20 (192.168.20.0/24)** — Kali Linux attacker
- **VLAN 30 (192.168.30.0/24)** — Victim hosts

This includes all attack traffic AND all benign background traffic on VLAN 30.
The `data/session_log.csv` file provides the timestamps needed to distinguish
malicious from benign flows during preprocessing.
