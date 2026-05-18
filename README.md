# AI-Powered Network Traffic Classifier

> Local ML model trained on real malicious and benign network traffic generated in a home cybersecurity lab.

**Status:** 🔧 In Progress — Milestones 0, 1, 2 complete — Milestone 3 in progress

---

## Overview

This project builds an end-to-end machine learning pipeline for network intrusion detection using real traffic generated in a physically segmented home security lab. Unlike projects trained on pre-packaged datasets, all traffic in this dataset was generated, captured, and labeled by hand in a controlled lab environment.

The pipeline covers everything from raw packet capture to a trained classifier with plain-English alert explanations powered by a local LLM.

---

## Lab Architecture

| Component | Details |
|-----------|---------|
| Firewall | OPNsense — continuous packet capture + Suricata IDS (28,699 ET rules) |
| Core Switch | Netgear Managed — trunks VLANs 10/20/30/40 |
| Hypervisor | Apple Mac Server running UTM |
| Attacker | Kali Linux (192.168.20.20) — VLAN 20 |
| Victims | Windows 11 (192.168.30.10), Metasploitable (192.168.30.20), TP-Link AP (192.168.30.2) — VLAN 30 |
| Pipeline Server | Ubuntu Server VM (192.168.10.4) — VLAN 10 |
| Training Workstation | Alienware m16 R2 — Intel Ultra 9 185H, 64GB RAM, RTX 4070 |

Full infrastructure documentation: [tyceerickson/home-lab-infrastructure](https://github.com/tyceerickson/home-lab-infrastructure)

---

## Data Flow

```
Kali Linux (manual attack scripts)
        │
        ▼
OPNsense Firewall
  ├── Continuous PCAP capture (VLAN 20 → 30 interface)
  └── Suricata IDS alerts (ET Open ruleset)
        │  rsync hourly
        ▼
Ubuntu Server VM  ← pipeline engine
  ├── sync-pcaps.sh       — pulls PCAPs from OPNsense
  ├── run-cicflowmeter.sh — extracts flow features
  └── label-flows.py      — applies labels from session_log.csv
        │  scp on demand
        ▼
Alienware m16 R2  ← training workstation
  ├── preprocessing.py    — clean, scale, balance
  ├── train.py            — Random Forest + comparisons
  ├── evaluate.py         — metrics and visualizations
  └── explain.py          — Ollama LLM explanations
```

---

## Attack Scenarios

| Scenario | Tool | Target |
|----------|------|--------|
| SYN port scan (all 65535 ports) | Nmap | All VLAN 30 hosts |
| Service + OS detection | Nmap | All VLAN 30 hosts |
| IDS/Firewall evasion (fragmentation, decoys, TTL, badsum) | Nmap | Metasploitable |
| Exploit attempt (EternalBlue ms17-010) | Metasploit | Metasploitable |
| SSH brute force | Hydra | Metasploitable |
| HTTP form brute force (DVWA, phpMyAdmin) | Hydra | Metasploitable |
| Slow HTTP DoS (Slowloris) | slowhttptest | Metasploitable |
| C2 beaconing simulation (regular, jitter, exfil) | Custom Python | Metasploitable |

---

## Benign Traffic Scenarios

| Scenario | Tool | Source |
|----------|------|--------|
| HTTP/HTTPS web browsing | curl | Ubuntu Server |
| DNS queries (A/AAAA, mixed hosts) | dig | Ubuntu Server |
| SSH admin sessions | sshpass/ssh | Ubuntu Server |
| SCP file transfers (10KB–2MB) | scp | Ubuntu Server |
| ICMP ping sweep (periodic) | ping | Ubuntu Server |

---

## Technical Stack

| Layer | Tools |
|-------|-------|
| Capture | OPNsense built-in, Suricata IDS |
| Feature extraction | CICFlowMeter |
| Pipeline | Bash, Python 3, rsync |
| ML | scikit-learn, XGBoost, pandas, NumPy |
| Visualization | matplotlib, seaborn |
| Explainability | Ollama (llama3, local) |
| Notebooks | Jupyter |

---

## Results

*To be populated after Milestone 6.*

| Model | Accuracy | Precision | Recall | F1 | ROC-AUC |
|-------|----------|-----------|--------|----|---------|
| Random Forest | — | — | — | — | — |
| XGBoost | — | — | — | — | — |
| Decision Tree | — | — | — | — | — |
| Logistic Regression | — | — | — | — | — |

---

## Project Structure

```
ai-traffic-classifier/
├── README.md
├── config.yaml                          ← central config, all paths and parameters
├── ubuntu_setup.sh                      ← one-shot Ubuntu Server environment setup
├── data/
│   ├── raw/                             ← PCAP files (not committed — regenerate with pipeline)
│   ├── processed/                       ← labeled CSV dataset
│   └── session_log.csv                  ← ground truth — manually logged attack timestamps
├── capture/                             ← OPNsense capture configuration docs
├── attack-scripts/                      ← Kali attack scripts (run manually)
│   ├── nmap-syn-scan.sh
│   ├── nmap-service-scan.sh
│   ├── nmap-evasion-scan.sh
│   ├── metasploit-ms17010.sh
│   ├── hydra-ssh-brute.sh
│   ├── hydra-http-brute.sh
│   ├── slowhttptest-dos.sh
│   ├── c2-beacon.py
│   └── run-all-attacks.sh               ← master script — runs all 8 sequentially
├── normal traffic generation scripts/   ← Ubuntu Server benign traffic scripts
│   ├── benign-web-traffic.sh
│   ├── benign-dns-queries.sh
│   ├── benign-ssh-session.sh
│   ├── benign-file-transfer.sh
│   ├── benign-ping-sweep.sh
│   ├── run-benign-all.sh                ← start all 5 benign scripts
│   └── stop-benign-all.sh               ← stop all 5 benign scripts
├── pipeline/
│   ├── sync-pcaps.sh                    ← pull PCAPs from OPNsense
│   ├── run-cicflowmeter.sh              ← extract flow features
│   └── label-flows.py                   ← apply labels from session log
├── src/
│   ├── preprocessing.py                 ← clean and prepare dataset
│   ├── train.py                         ← train and serialize models
│   ├── evaluate.py                      ← generate metrics and visualizations
│   └── explain.py                       ← Ollama LLM explainability
├── notebooks/
│   └── full_pipeline.ipynb              ← end-to-end walkthrough
├── models/                              ← serialized trained models
├── results/                             ← evaluation plots and reports
└── writeup/
    └── local_vs_cloud.md                ← local ML vs cloud AI comparison
```

## Milestones

| # | Milestone | Status |
|---|-----------|--------|
| 0 | Repo scaffold + Ubuntu environment setup | ✅ Complete |
| 1 | OPNsense continuous capture + Suricata | ✅ Complete |
| 2 | Attack + benign traffic scripts | ✅ Complete |
| 3 | Ubuntu pipeline — sync, CICFlowMeter, labeling | ✅ Complete |
| 4 | First capture session | 🔧 In Progress |
| 5 | Preprocessing pipeline | ⬜ Pending |
| 6 | Model training + evaluation | ⬜ Pending |
| 7 | Ollama explainability layer | ⬜ Pending |
| 8 | Notebook + README + writeup | ⬜ Pending |

---

# Capture Session Runbook

Complete step-by-step guide to generating a labeled dataset from scratch.
Follow this exactly and you will have a labeled `features.csv` ready for
model training.

---

## Prerequisites Checklist

Before starting, confirm these are running:

```bash
# 1. Suricata is running on OPNsense
ssh opnsense        # from Ubuntu Server
# type 8 for shell
ps aux | grep suricata | grep -v grep
# Should show a suricata process — if not, run: configctl ids start

# 2. OPNsense capture job is active
# Go to OPNsense GUI → Interfaces → Diagnostics → Packet Capture → Jobs
# Confirm the capture job shows as running

# 3. rsync is configured (PCAPs flow automatically)
cat /etc/cron.d/rsync-to-ubuntu    # on OPNsense shell
# Should show: 0 * * * * /usr/local/sbin/rsync-to-ubuntu.sh

# 4. All VMs are powered on
# Metasploitable (192.168.30.20) — ping from Ubuntu Server
ping -c 2 192.168.30.20
# Windows 11 (192.168.30.10)
ping -c 2 192.168.30.10
```

---

## Step 1 — Clear Old PCAP Data (Optional)

If you want a clean dataset with no old captures mixed in:

```bash
# On Ubuntu Server — archive old PCAPs before clearing
mkdir -p /opt/pcaps/archive
mv /opt/pcaps/*.pcap /opt/pcaps/archive/ 2>/dev/null
mv /opt/cicflow_output/merged_flows.csv /opt/cicflow_output/archive/ 2>/dev/null
```

---

## Step 2 — Start Benign Traffic (Ubuntu Server)

Open a tmux session so benign traffic keeps running even if your SSH
connection drops:

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
# On Ubuntu Server — note the current UTC time
date -u
```

Write this down — you'll need it if anything goes wrong with the
automatic session log.

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
[1/8] Nmap SYN Scan           (~5 min)
[2/8] Nmap Service Scan       (~15 min)
[3/8] Nmap Evasion Scan       (~8 min)
[4/8] Hydra SSH Brute Force   (~5 min)
[5/8] Hydra HTTP Brute Force  (~5 min)
[6/8] C2 Beacon Simulation    (~12 min)
[7/8] Slow HTTP DoS           (~5 min)
[8/8] Metasploit MS17-010     (~5 min)
      + 60 second pause between each
Total runtime: ~90 minutes
```

**Walk away and come back in 90 minutes.**

---

## Step 5 — Copy Session Log Entries

When `run-all-attacks.sh` finishes it prints a session log at the bottom:

```
---- SESSION LOG ENTRIES ----
timestamp_start,timestamp_end,scenario,targets,label,notes
2026-05-18 20:00:00,2026-05-18 20:04:00,nmap_syn_scan,...
2026-05-18 20:05:00,2026-05-18 20:18:00,nmap_service_scan,...
...
```

Copy those lines. On the Ubuntu Server, paste them into the session log:

```bash
# SSH back into Ubuntu Server
ssh homeserver

# Open session log and paste entries below the header row
nano /home/terickson/data/session_log.csv
```

The file should look like:
```
timestamp_start,timestamp_end,scenario,targets,label,notes
2026-05-18 20:00:00,2026-05-18 20:04:00,nmap_syn_scan,"192.168.30.10,192.168.30.20,192.168.30.2",malicious,full port range
2026-05-18 20:05:00,2026-05-18 20:18:00,nmap_service_scan,...
```

Save with `Ctrl+O` → Enter → `Ctrl+X`.

**Important:** Timestamps are in UTC. Verify with `date -u` if unsure.

---

## Step 6 — Stop Benign Traffic (Ubuntu Server)

```bash
cd /home/terickson/traffic-generation-scripts
bash stop-benign-all.sh
```

You should see:
```
[-] Stopped PID XXXX
[-] Stopped PID XXXX
...
[+] All benign scripts stopped
```

---

## Step 7 — Wait for Final rsync (Ubuntu Server)

The OPNsense rsync runs on the hour. Wait until the top of the next hour
for all PCAPs to sync, or trigger it manually via SSH to OPNsense:

```bash
ssh opnsense
# type 8 for shell
/usr/local/sbin/rsync-to-ubuntu.sh
exit
```

Verify PCAPs arrived:
```bash
ls -lh /opt/pcaps/
# Should show .pcap files with today's date
```

---

## Step 8 — Convert PCAPs to Flow Features (Ubuntu Server)

```bash
python3 ~/pcap_to_csv.py /opt/pcaps/ /opt/cicflow_output/merged_flows.csv
```

This processes every PCAP in `/opt/pcaps/` and produces one merged CSV.
Expect it to take 2-10 minutes depending on capture size.

Verify output:
```bash
wc -l /opt/cicflow_output/merged_flows.csv
# Should show tens of thousands of lines
```

---

## Step 9 — Label the Flows (Ubuntu Server)

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
[+] Flow timestamps: 2026-05-18 ...
    nmap_syn_scan: XXXX flows labeled malicious
    nmap_service_scan: XXXX flows labeled malicious
    ...
[+] Labeling complete:
    Malicious (1): XXXX
    Benign    (0): XXXX
    Total:         XXXX
[+] Master dataset saved to: /home/terickson/data/features.csv
```

**If malicious count is 0:** The timestamps in `session_log.csv` don't
match the PCAP timestamps. Check that both are in UTC.

---

## Step 10 — Transfer Dataset to Alienware

From your Alienware (PowerShell):

```powershell
scp terickson@100.82.166.75:/home/terickson/data/features.csv C:\Users\tycee\Downloads\
```

Or from the Ubuntu Server:

```bash
scp /home/terickson/data/features.csv terickson@<alienware-tailscale-ip>:~/
```

---

## Step 11 — Train the Model (Alienware)

```bash
cd ai-traffic-classifier
python3 src/preprocessing.py
python3 src/train.py
python3 src/evaluate.py
```

Results saved to `results/` folder.

---

## Troubleshooting

**Suricata not running:**
```bash
ssh opnsense    # from Ubuntu Server
# type 8
rm -f /var/run/suricata.pid
configctl ids start
sleep 10
ps aux | grep suricata | grep -v grep
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
# Re-run with verbose flag
cicflowmeter -f /opt/pcaps/<file>.pcap -c /tmp/test.csv -v
```

**Benign scripts not stopping:**
```bash
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
# On Ubuntu Server via VNC console
sudo ip route add default via 192.168.64.1 dev enp0s1
sudo systemctl restart tailscaled
sudo tailscale up --ssh
```

---

## Key File Locations Reference

| File | Location | Purpose |
|------|----------|---------|
| Attack scripts | Kali: `/home/attacker/attack-scripts/` | Generate malicious traffic |
| Benign scripts | Ubuntu: `/home/terickson/traffic-generation-scripts/` | Generate benign traffic |
| Session log | Ubuntu: `/home/terickson/data/session_log.csv` | Attack timestamps (ground truth) |
| Raw PCAPs | Ubuntu: `/opt/pcaps/` | Synced from OPNsense hourly |
| Suricata alerts | Ubuntu: `/opt/suricata/eve.json` | IDS alert log |
| Flow features CSV | Ubuntu: `/opt/cicflow_output/merged_flows.csv` | CICFlowMeter output |
| Labeled dataset | Ubuntu: `/home/terickson/data/features.csv` | Ready for training |
| pcap_to_csv script | Ubuntu: `/home/terickson/pcap_to_csv.py` | PCAP → CSV converter |
| label_flows script | Ubuntu: `/home/terickson/pipeline/label_flows.py` | Applies labels |
| SSH config | Ubuntu: `~/.ssh/config` | `ssh opnsense` alias |
| OPNsense SSH key | Ubuntu: `~/.ssh/opnsense_key` | Key-only OPNsense access |
| Suricata eve.json | OPNsense: `/var/log/suricata/eve.json` | Raw alerts |
| PCAPs (source) | OPNsense: `/tmp/captures/` | Before rsync |
| rsync script | OPNsense: `/usr/local/sbin/rsync-to-ubuntu.sh` | Pushes files to Ubuntu |
| rsync cron | OPNsense: `/etc/cron.d/rsync-to-ubuntu` | Hourly schedule |
| Suricata watchdog | OPNsense: `/usr/local/sbin/suricata-watchdog.sh` | Auto-restart |
| ML source code | Alienware: `ai-traffic-classifier/src/` | Training scripts |
| Trained models | Alienware: `ai-traffic-classifier/models/` | Serialized models |
| Results | Alienware: `ai-traffic-classifier/results/` | Metrics and plots |


## Background

Built as Project 2 of a cybersecurity/AI portfolio by a graduate student entering Carnegie Mellon University's MSISPM program. CompTIA Security+, Network+, ISC2 CC, Microsoft AI-900 certified.
