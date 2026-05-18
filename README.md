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

---

## Capture Session Workflow

```bash
# 1. Start benign traffic on Ubuntu Server
bash "normal traffic generation scripts/run-benign-all.sh"

# 2. Run all attacks on Kali
sudo bash attack-scripts/run-all-attacks.sh

# 3. Stop benign traffic when attacks finish
bash "normal traffic generation scripts/stop-benign-all.sh"

# 4. Run pipeline on Ubuntu Server
bash pipeline/sync-pcaps.sh
bash pipeline/run-cicflowmeter.sh
python3 pipeline/label-flows.py
```

---

## Milestones

| # | Milestone | Status |
|---|-----------|--------|
| 0 | Repo scaffold + Ubuntu environment setup | ✅ Complete |
| 1 | OPNsense continuous capture + Suricata | ✅ Complete |
| 2 | Attack + benign traffic scripts | ✅ Complete |
| 3 | Ubuntu pipeline — sync, CICFlowMeter, labeling | 🔧 In Progress |
| 4 | First capture session | ⬜ Pending |
| 5 | Preprocessing pipeline | ⬜ Pending |
| 6 | Model training + evaluation | ⬜ Pending |
| 7 | Ollama explainability layer | ⬜ Pending |
| 8 | Notebook + README + writeup | ⬜ Pending |

---

## Background

Built as Project 2 of a cybersecurity/AI portfolio by a graduate student entering Carnegie Mellon University's MSISPM program. CompTIA Security+, Network+, ISC2 CC, Microsoft AI-900 certified.
