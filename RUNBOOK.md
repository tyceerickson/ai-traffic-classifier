# Capture Session Runbook

Complete step-by-step guide to generating a labeled dataset from scratch.
Follow this exactly and you will have a labeled `features.csv` ready for model training.

---

## Prerequisites Checklist

Before starting, confirm these are ready:

```bash
# 1. Suricata is installed on Ubuntu Server (runs offline after capture)
which suricata
# Should return /usr/bin/suricata
# If not: sudo apt install suricata && sudo suricata-update

# 2. OPNsense capture job is active
# Go to OPNsense GUI → Interfaces → Diagnostics → Packet Capture → Jobs
# Confirm "continuous-vlan20-capture" shows as running (green)
# If not: click the play button to start it

# 3. rsync cron is configured on OPNsense
ssh opnsense   # from Ubuntu Server, type 8 for shell
cat /etc/cron.d/rsync-to-ubuntu
# Should show: 0 * * * * /usr/local/sbin/rsync-to-ubuntu.sh
exit

# 4. All VMs are powered on — ping from Ubuntu Server
ping -c 2 192.168.30.20   # Metasploitable
ping -c 2 192.168.30.10   # Windows 11
ping -c 2 192.168.20.20   # Kali
```

---

## Step 1 — Clear Old PCAP Data (Optional)

If you want a clean dataset with no old captures mixed in:

```bash
# On Ubuntu Server
mkdir -p /opt/pcaps/archive
mkdir -p /opt/cicflow_output/archive
mv /opt/pcaps/*.pcap /opt/pcaps/archive/ 2>/dev/null
mv /opt/cicflow_output/merged_flows.csv /opt/cicflow_output/archive/ 2>/dev/null
```

---

## Step 2 — Start Benign Traffic (Ubuntu Server)

Open a tmux session so benign traffic keeps running even if your SSH drops:

```bash
# SSH into Ubuntu Server from Alienware
ssh homeserver

# Start tmux session
tmux new -s capture

# Start all 5 benign traffic scripts (they loop continuously)
cd /home/terickson/traffic-generation-scripts
bash run-benign-all.sh
```

You should see:
```
[+] Started benign-web-traffic.sh (PID: XXXX)
[+] Started benign-dns-queries.sh (PID: XXXX)
[+] Started benign-ssh-session.sh (PID: XXXX)
[+] Started benign-file-transfer.sh (PID: XXXX)
[+] Started benign-ping-sweep.sh (PID: XXXX)
```

**Leave this terminal running.** Detach from tmux with `Ctrl+B then D`.

---

## Step 3 — Record Session Start Time (UTC)

```bash
# On Ubuntu Server
date -u
```

Write this down — you'll need it if anything goes wrong with the automatic session log.

---

## Step 4 — Run All Attack Scripts (Kali)

RDP into Kali Linux (192.168.20.20), open a terminal:

```bash
cd /home/attacker/attack-scripts
sudo bash run-all-attacks.sh
```

When prompted: **Press Enter to begin.**

The script runs all 8 attacks sequentially:
```
[1/8] Nmap SYN Scan           — scans all 65,535 ports × 3 targets (~2-3 hrs)
[2/8] Nmap Service Scan       — service + OS detection × 3 targets (~2-3 hrs)
[3/8] Nmap Evasion Scan       — fragmentation, decoys, TTL, badsum (~15 min)
[4/8] Hydra SSH Brute Force   — SSH credential brute force (~5 min)
[5/8] Hydra HTTP Brute Force  — DVWA + phpMyAdmin form brute force (~5 min)
[6/8] C2 Beacon Simulation    — regular, jitter, exfil modes (~12 min)
[7/8] Slow HTTP DoS           — Slowloris 500 connections (~5 min)
[8/8] Metasploit MS17-010     — EternalBlue SMB exploit (~5 min)
      + 60 second pause between each attack
Total runtime: ~4-5 hours (due to full port scan on all targets)
```

**Walk away and come back when complete.**

---

## Step 5 — Copy Session Log Entries

When `run-all-attacks.sh` finishes it prints a session log at the bottom:

```
---- SESSION LOG ENTRIES ----
timestamp_start,timestamp_end,scenario,targets,label,notes
2026-05-18 13:24:59,2026-05-18 15:15:11,nmap_syn_scan,...
```

**Important:** These timestamps are in local time (MDT, UTC-6).
**You must add 6 hours** before pasting into session_log.csv which uses UTC.

On the Ubuntu Server:

```bash
nano /home/terickson/data/session_log.csv
```

Paste the entries with +6 hours applied. Save with `Ctrl+O` → Enter → `Ctrl+X`.

Verify UTC conversion:
```bash
date -u   # check current UTC time to confirm offset
```

---

## Step 6 — Stop Benign Traffic (Ubuntu Server)

```bash
cd /home/terickson/traffic-generation-scripts
bash stop-benign-all.sh
```

---

## Step 7 — Sync PCAPs from OPNsense (Ubuntu Server)

The OPNsense rsync runs on the hour automatically. To trigger immediately:

```bash
ssh opnsense
# type 8 for shell
/usr/local/sbin/rsync-to-ubuntu.sh
exit
exit
```

Verify PCAPs arrived:
```bash
ls -lh /opt/pcaps/
# Should show .pcap files from today with significant file sizes
```

---

## Step 8 — Convert PCAPs to Flow Features (Ubuntu Server)

```bash
python3 ~/pcap_to_csv.py /opt/pcaps/ /opt/cicflow_output/merged_flows.csv
```

Processes every PCAP in `/opt/pcaps/` into one merged CSV.
Expect 2-10 minutes depending on capture size.

Verify:
```bash
wc -l /opt/cicflow_output/merged_flows.csv
# First capture session produced 1,201,560 flows
```

---

## Step 9 — Run Suricata Offline IDS Analysis (Ubuntu Server)

```bash
sudo bash ~/pipeline/run_suricata.sh /opt/pcaps/
```

Suricata processes all PCAPs and generates an alert log.
Expect ~19 seconds per session.

Verify:
```bash
grep -c '"event_type":"alert"' /opt/suricata/eve.json
# First capture session produced 727 alerts
```

---

## Step 10 — Label the Flows (Ubuntu Server)

```bash
python3 ~/pipeline/label_flows.py \
  --cicflow-dir /opt/cicflow_output \
  --session-log /home/terickson/data/session_log.csv \
  --output /home/terickson/data/features.csv
```

Expected output:
```
[+] Loaded 8 attack sessions from session log
[+] Found merged CSV: /opt/cicflow_output/merged_flows.csv
    nmap_syn_scan: 525,288 flows labeled malicious
    nmap_service_scan: 526,181 flows labeled malicious
    ...
[+] Labeling complete:
    Malicious (1): 1,056,039
    Benign    (0): 145,521
    Total:         1,201,560
[+] Master dataset saved to: /home/terickson/data/features.csv
```

**If malicious count is 0:** Timestamps in session_log.csv don't match PCAP
timestamps. Check that session_log.csv uses UTC (add 6 hours to Kali MDT times).

---

## Step 11 — Transfer Dataset to Alienware

From Alienware PowerShell:
```powershell
scp terickson@100.82.166.75:/home/terickson/data/features.csv C:\Users\tycee\Downloads\
```

---

## Step 12 — Train the Model (Alienware)

```powershell
cd C:\TyceErickson\Projects\ai-traffic-classifier
copy C:\Users\tycee\Downloads\features.csv data\processed\features.csv
python src/preprocessing.py
python src/train.py
python src/explain.py
```

Results saved to `results/` folder.

---

## Troubleshooting

**Suricata on Ubuntu Server not working:**
```bash
# Check it's installed
which suricata
suricata --version

# Check rules are loaded
wc -l /var/lib/suricata/rules/suricata.rules

# Update rules if needed
sudo suricata-update --suricata-conf /etc/suricata/suricata.yaml \
  --output /var/lib/suricata/rules

# Test manually
sudo suricata -c /etc/suricata/suricata.yaml \
  -r /opt/pcaps/test.pcap -l /opt/suricata/ --runmode=single
```

**OPNsense capture job not running:**
```bash
# Check via GUI
# Interfaces → Diagnostics → Packet Capture → Jobs
# Click play button if stopped

# Verify via tcpdump on OPNsense
ssh opnsense  # type 8
tcpdump -i vlan0.20 -c 10
```

**No PCAPs in /opt/pcaps/:**
```bash
ssh opnsense
# type 8
/usr/local/sbin/rsync-to-ubuntu.sh
```

**CICFlowMeter produces empty CSV:**
```bash
# Check the PCAP is valid
tshark -r /opt/pcaps/<file>.pcap -c 5

# Check CICFlowMeter is patched (Scapy 2.7 compatibility)
cicflowmeter --help   # should show usage without errors

# Re-run with verbose
cicflowmeter -f /opt/pcaps/<file>.pcap -c /tmp/test.csv -v
```

**Benign scripts not stopping:**
```bash
bash /home/terickson/traffic-generation-scripts/stop-benign-all.sh
# If that fails:
pkill -f "benign-"
pkill -f "sshpass"
pkill -f "curl.*192.168"
```

**OPNsense VLAN 20 shows wrong IP (0.0.0.0):**
```bash
ssh opnsense
# type 2 → select vlan_20_attackers → set 192.168.20.1 / 24
```

**Tailscale SSH times out:**
```bash
# On Ubuntu Server via VNC console on Mac Server
sudo systemctl restart tailscaled
sudo tailscale up --ssh
```

**Session log timezone mismatch (all flows labeled benign):**
```bash
# Kali timestamps are MDT (UTC-6) — add 6 hours when writing session_log.csv
# Example: Kali shows 13:24 → write 19:24 in session_log.csv
# Or use this Python one-liner to convert an existing session_log:
python3 -c "
import pandas as pd
df = pd.read_csv('/home/terickson/data/session_log.csv')
df['timestamp_start'] = pd.to_datetime(df['timestamp_start']) + pd.Timedelta(hours=6)
df['timestamp_end'] = pd.to_datetime(df['timestamp_end']) + pd.Timedelta(hours=6)
df.to_csv('/home/terickson/data/session_log.csv', index=False)
print('Converted to UTC')
"
```

---

## Key File Locations Reference

| File | Location | Purpose |
|------|----------|---------|
| Attack scripts | Kali: `/home/attacker/attack-scripts/` | Generate malicious traffic |
| Benign scripts | Ubuntu: `/home/terickson/traffic-generation-scripts/` | Generate benign traffic |
| Session log | Ubuntu: `/home/terickson/data/session_log.csv` | Attack timestamps in UTC (ground truth) |
| Raw PCAPs | Ubuntu: `/opt/pcaps/` | Synced from OPNsense hourly via rsync |
| Suricata alerts | Ubuntu: `/opt/suricata/eve.json` | Offline IDS analysis output |
| CICFlowMeter CSV | Ubuntu: `/opt/cicflow_output/merged_flows.csv` | 82-feature flow data |
| Labeled dataset | Ubuntu: `/home/terickson/data/features.csv` | Ready for Alienware training |
| pcap_to_csv | Ubuntu: `/home/terickson/pcap_to_csv.py` | PCAP → CSV converter (CICFlowMeter wrapper) |
| label_flows | Ubuntu: `/home/terickson/pipeline/label_flows.py` | Applies labels from session log |
| run_suricata | Ubuntu: `/home/terickson/pipeline/run_suricata.sh` | Offline Suricata IDS analysis |
| SSH config | Ubuntu: `~/.ssh/config` | `ssh opnsense` alias |
| OPNsense SSH key | Ubuntu: `~/.ssh/opnsense_key` | Key-only auth to OPNsense |
| Suricata config | Ubuntu: `/etc/suricata/suricata.yaml` | IDS configuration |
| Suricata rules | Ubuntu: `/var/lib/suricata/rules/suricata.rules` | 50,165 ET Open rules |
| OPNsense PCAPs | OPNsense: `/tmp/captures/` | Raw captures before rsync |
| rsync script | OPNsense: `/usr/local/sbin/rsync-to-ubuntu.sh` | Pushes PCAPs to Ubuntu Server |
| rsync cron | OPNsense: `/etc/cron.d/rsync-to-ubuntu` | Runs rsync hourly |
| Suricata watchdog | OPNsense: `/usr/local/sbin/suricata-watchdog.sh` | Not used (Suricata moved to Ubuntu) |
| ML source code | Alienware: `C:\TyceErickson\Projects\ai-traffic-classifier\src\` | Training scripts |
| Trained models | Alienware: `ai-traffic-classifier\models\` | Serialized models (not in git) |
| Results | Alienware: `ai-traffic-classifier\results\` | Plots, evaluation report, explanations |
