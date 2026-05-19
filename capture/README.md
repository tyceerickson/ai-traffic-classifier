# Capture

This directory documents the OPNsense continuous capture configuration and
the offline Suricata IDS analysis pipeline.

---

## Architecture Overview

```
OPNsense Firewall (192.168.10.1)
  └── Built-in packet capture job → /tmp/captures/*.pcap
  └── tcpdump (manual backup)    → /tmp/live_capture.pcap
        │
        │  rsync hourly (cron)
        ▼
Ubuntu Server VM (192.168.10.4)
  └── /opt/pcaps/                ← all PCAPs land here
  └── ~/pipeline/run_suricata.sh ← offline IDS analysis
  └── ~/pcap_to_csv.py           ← CICFlowMeter conversion
```

---

## OPNsense Packet Capture

**Method:** OPNsense built-in capture job (GUI-based)

**Location in GUI:**
`Interfaces → Diagnostics → Packet Capture → Jobs`

**Job name:** `continuous-vlan20-capture`

**Interface:** `vlan0.20` (VLAN 20 — attackers subnet)

**Storage path on OPNsense:** `/tmp/captures/`

**What gets captured:** All traffic on the attacker VLAN interface,
which includes all traffic flowing between:
- VLAN 20 (192.168.20.0/24) — Kali Linux attacker
- VLAN 30 (192.168.30.0/24) — Victim hosts (Windows 11, Metasploitable, TP-Link)

---

## rsync to Ubuntu Server

OPNsense pushes PCAPs to the Ubuntu Server automatically via cron.

**Cron job location on OPNsense:** `/etc/cron.d/rsync-to-ubuntu`

**Script:** `/usr/local/sbin/rsync-to-ubuntu.sh`

**Schedule:** Every hour (top of the hour)

**What gets synced:**
```bash
# PCAPs → Ubuntu Server
rsync -av /tmp/captures/ terickson@192.168.10.4:/opt/pcaps/
```

**To trigger manually (from OPNsense shell):**
```bash
/usr/local/sbin/rsync-to-ubuntu.sh
```

---

## Suricata IDS — Offline Analysis on Ubuntu Server

> **Important:** Suricata does NOT run live on OPNsense.
> OPNsense 26.1 + Suricata 8.0.3 has a known compatibility issue
> on VLAN interfaces in PCAP mode on FreeBSD — Suricata exits
> silently after "Engine started."
>
> Instead, Suricata runs **offline on the Ubuntu Server** against
> the PCAP files after each capture session.

**Suricata binary:** `/usr/bin/suricata` (v8.0.4, OISF PPA)

**Config:** `/etc/suricata/suricata.yaml`

**Rules:** `/var/lib/suricata/rules/suricata.rules` (50,165 ET Open rules)

**Output:** `/opt/suricata/eve.json`

**HOME_NET:** `192.168.10.0/24, 192.168.30.0/24, 192.168.40.0/24, 192.168.99.0/24`

**EXTERNAL_NET:** `!$HOME_NET` (includes Kali on 192.168.20.x)

### Running Suricata After a Capture Session

```bash
# On Ubuntu Server — process all PCAPs in /opt/pcaps/
bash ~/pipeline/run_suricata.sh /opt/pcaps/

# Or process a single PCAP
bash ~/pipeline/run_suricata.sh /opt/pcaps/file.pcap
```

Output goes to `/opt/suricata/eve.json`. Previous eve.json is
automatically archived as `eve_YYYYMMDD_HHMMSS.json` before each run.

### Updating Suricata Rules

```bash
sudo suricata-update --suricata-conf /etc/suricata/suricata.yaml \
  --output /var/lib/suricata/rules
```

---

## Data Flow Summary

```
1. OPNsense captures traffic on vlan0.20
   → /tmp/captures/*.pcap

2. rsync pushes PCAPs to Ubuntu Server hourly
   → /opt/pcaps/*.pcap

3. After capture session — run CICFlowMeter
   python3 ~/pcap_to_csv.py /opt/pcaps/ /opt/cicflow_output/merged_flows.csv
   → /opt/cicflow_output/merged_flows.csv (1.2M flows, 82 features)

4. After capture session — run Suricata offline
   bash ~/pipeline/run_suricata.sh /opt/pcaps/
   → /opt/suricata/eve.json (727 alerts from May 18 session)

5. Label flows using session_log.csv timestamps
   python3 ~/pipeline/label_flows.py ...
   → /home/terickson/data/features.csv (labeled dataset)

6. Transfer to Alienware for training
   scp terickson@100.82.166.75:/home/terickson/data/features.csv .
```

---

## May 18, 2026 Capture Session Stats

| Metric | Value |
|--------|-------|
| Total PCAP size | ~143 MB |
| CICFlowMeter flows | 1,201,560 |
| Suricata alerts | 727 |
| Malicious flows | 1,056,039 (88%) |
| Benign flows | 145,521 (12%) |
| Capture duration | ~5 hours |
