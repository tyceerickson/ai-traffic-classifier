# AI-Powered Network Traffic Classifier

> Local ML model trained on real malicious and benign network traffic generated in a home cybersecurity lab.

**Status:** Milestones 0–7 complete — Milestone 8 (writeup) in progress

---

## Overview

This project builds an end-to-end machine learning pipeline for network intrusion detection using real traffic generated in a physically segmented home security lab. Unlike projects trained on pre-packaged datasets, all traffic in this dataset was generated, captured, and labeled by hand in a controlled lab environment.

The pipeline covers everything from raw packet capture to a trained classifier with plain-English alert explanations powered by a local LLM.

---

## Results

| Model | Accuracy | Precision | Recall | F1 | ROC-AUC |
|-------|----------|-----------|--------|----|---------|
| Random Forest | 0.9999 | 1.0000 | 1.0000 | 1.0000 | 1.0000 |
| XGBoost | 0.9999 | 1.0000 | 0.9999 | 0.9999 | 1.0000 |
| Decision Tree | 0.9999 | 1.0000 | 0.9999 | 0.9999 | 0.9999 |
| Logistic Regression | 0.8092 | 0.8092 | 1.0000 | 0.8945 | 0.6893 |

**Best model: Random Forest (F1=1.0000)**

Dataset: 1,201,560 flows — 1,056,039 malicious / 145,521 benign
Training set: 610,137 flows | Test set: 152,535 flows | Features: 78

> Note: Near-perfect results are expected for lab-generated traffic with highly distinctive
> attack patterns. Real-world performance on unseen network environments would be lower —
> a known and acknowledged limitation of lab-generated datasets documented in the writeup.

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
  └── Suricata IDS alerts (ET Open ruleset, offline analysis)
        │  rsync hourly
        ▼
Ubuntu Server VM  ← pipeline engine
  ├── pcap_to_csv.py      — CICFlowMeter flow extraction
  └── label_flows.py      — applies labels from session_log.csv
        │  scp on demand
        ▼
Alienware m16 R2  ← training workstation
  ├── preprocessing.py    — clean, scale, balance (3:1 undersample)
  ├── train.py            — Random Forest + XGBoost + DT + LR
  ├── evaluate.py         — metrics and visualizations
  └── explain.py          — Ollama llama3.1:8b LLM explanations
```

---

## Attack Scenarios

| Scenario | Tool | Target | Flows Generated |
|----------|------|--------|-----------------|
| SYN port scan (all 65,535 ports) | Nmap | All VLAN 30 hosts | 525,288 |
| Service + OS detection | Nmap | All VLAN 30 hosts | 526,181 |
| IDS/Firewall evasion (fragmentation, decoys, TTL, badsum) | Nmap | Metasploitable | 156 |
| SSH credential brute force | Hydra | Metasploitable | 2 |
| HTTP form brute force (DVWA, phpMyAdmin) | Hydra | Metasploitable | 546 |
| C2 beaconing simulation (regular, jitter, exfil) | Custom Python | Metasploitable | 53 |
| Slow HTTP DoS (Slowloris) | slowhttptest | Metasploitable | 3,795 |
| EternalBlue MS17-010 exploit attempt | Metasploit | Metasploitable | 18 |

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
| Capture | OPNsense built-in packet capture, Suricata IDS (offline) |
| Feature extraction | CICFlowMeter 0.1.9 (patched for Scapy 2.7 compatibility) |
| Pipeline | Bash, Python 3, rsync |
| ML | scikit-learn, XGBoost (CUDA), pandas, NumPy |
| Visualization | matplotlib, seaborn |
| Explainability | Ollama llama3.1:8b (local, RTX 4070) |
| Notebooks | Jupyter |

---

## Project Structure

```
ai-traffic-classifier/
├── README.md
├── RUNBOOK.md                           ← step-by-step capture session guide
├── config.yaml                          ← central config, all paths and parameters
├── ubuntu_setup.sh                      ← one-shot Ubuntu Server environment setup
├── data/
│   ├── raw/                             ← PCAP files (not committed)
│   ├── processed/                       ← datasets (not committed — too large)
│   └── session_log.csv                  ← ground truth attack timestamps
├── attack-scripts/                      ← Kali attack scripts
│   ├── nmap-syn-scan.sh
│   ├── nmap-service-scan.sh
│   ├── nmap-evasion-scan.sh
│   ├── metasploit-ms17010.sh
│   ├── hydra-ssh-brute.sh
│   ├── hydra-http-brute.sh
│   ├── slowhttptest-dos.sh
│   ├── c2-beacon.py
│   └── run-all-attacks.sh
├── normal traffic generation scripts/   ← Ubuntu Server benign traffic
│   ├── benign-web-traffic.sh
│   ├── benign-dns-queries.sh
│   ├── benign-ssh-session.sh
│   ├── benign-file-transfer.sh
│   ├── benign-ping-sweep.sh
│   ├── run-benign-all.sh
│   └── stop-benign-all.sh
├── pipeline/
│   ├── label_flows.py                   ← timestamp-based labeling
│   └── run_suricata.sh                  ← offline Suricata analysis
├── src/
│   ├── preprocessing.py                 ← clean, scale, balance
│   ├── train.py                         ← train 4 models + evaluation
│   ├── evaluate.py                      ← metrics and plots
│   └── explain.py                       ← Ollama LLM explainability
├── notebooks/
│   └── full_pipeline.ipynb
├── models/                              ← serialized models (not committed)
├── results/
│   ├── evaluation_report.md
│   ├── explanations.md                  ← LLM explanations of flagged flows
│   ├── confusion_matrix_*.png
│   ├── roc_curves.png
│   ├── feature_importance.png
│   └── model_comparison.png
└── writeup/
    └── local_vs_cloud.md
```

---

## Milestones

| # | Milestone | Status |
|---|-----------|--------|
| 0 | Repo scaffold + Ubuntu environment setup | ✅ Complete |
| 1 | OPNsense continuous capture + Suricata | ✅ Complete |
| 2 | Attack + benign traffic scripts | ✅ Complete |
| 3 | Ubuntu pipeline — CICFlowMeter, labeling | ✅ Complete |
| 4 | First capture session (1.2M flows) | ✅ Complete |
| 5 | Preprocessing pipeline | ✅ Complete |
| 6 | Model training + evaluation | ✅ Complete |
| 7 | Ollama explainability layer | ✅ Complete |
| 8 | Notebook + README + writeup | 🔧 In Progress |

---

## Background

Built as Project 2 of a cybersecurity/AI portfolio by a graduate student entering Carnegie Mellon University's MSISPM program. CompTIA Security+, Network+, ISC2 CC, Microsoft AI-900 certified.
