# AI-Powered Network Traffic Classifier

> Local ML model trained on real malicious and benign network traffic generated in a home cybersecurity lab.

**Status:** 🔧 In Progress — Milestone 0 complete (repo scaffold + environment setup)

---

## Overview

This project builds an end-to-end machine learning pipeline for network intrusion detection using real traffic generated in a physically segmented home security lab. Unlike projects trained on pre-packaged datasets, all traffic in this dataset was generated, captured, and labeled by hand in a controlled lab environment.

The pipeline covers everything from raw packet capture to a trained classifier with plain-English alert explanations powered by a local LLM.

---

## Lab Architecture

| Component | Details |
|-----------|---------|
| Firewall | OPNsense — continuous packet capture + Suricata IDS |
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
  ├── sync_pcaps.sh       — pulls PCAPs from OPNsense
  ├── run_cicflowmeter.sh — extracts flow features
  └── label_flows.py      — applies labels from session_log.csv
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
| SYN port scan | Nmap | All VLAN 30 hosts |
| OS/service fingerprint | Nmap | All VLAN 30 hosts |
| Exploit attempt (ms17-010) | Metasploit | Metasploitable |
| SSH brute force | Hydra | Metasploitable |
| HTTP brute force | Hydra | iMac Ubuntu Server |
| Slow HTTP DoS | slowhttptest | iMac Ubuntu Server |
| C2-style beacon | Custom Python | Configurable |

---

## Technical Stack

| Layer | Tools |
|-------|-------|
| Capture | OPNsense built-in, tcpdump, Suricata |
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
├── config.yaml              # Central config — all paths and parameters
├── data/
│   ├── raw/                 # PCAP files (not committed — regenerate with pipeline)
│   ├── processed/           # Labeled CSV dataset
│   └── session_log.csv      # Ground truth — manually logged attack sessions
├── capture/                 # OPNsense capture configuration docs
├── attack-scripts/          # Kali attack scripts (run manually)
├── pipeline/                # Ubuntu Server automation scripts
│   ├── sync_pcaps.sh        # Pull PCAPs from OPNsense
│   ├── run_cicflowmeter.sh  # Extract flow features
│   └── label_flows.py       # Apply labels from session log
├── src/
│   ├── preprocessing.py     # Clean and prepare dataset for training
│   ├── train.py             # Train and serialize models
│   ├── evaluate.py          # Generate metrics and visualizations
│   └── explain.py           # Ollama LLM explainability
├── notebooks/
│   └── full_pipeline.ipynb  # End-to-end walkthrough for reproducibility
├── models/                  # Serialized trained models
├── results/                 # Evaluation plots and reports
└── writeup/
    └── local_vs_cloud.md    # Local ML vs cloud AI deployment comparison
```

---

## Reproducing the Dataset

Raw PCAP files are not committed to this repo. To regenerate the dataset:

1. Set up a lab matching the architecture described above (or adapt `config.yaml` for your network)
2. Configure OPNsense continuous capture on the VLAN 20/30 interface
3. SSH into Ubuntu Server and run `./pipeline/sync_pcaps.sh` after running attack scripts
4. Run `./pipeline/run_cicflowmeter.sh` to extract features
5. Fill in `data/session_log.csv` with your attack session timestamps
6. Run `python3 pipeline/label_flows.py` to generate the labeled dataset

---

## Milestones

| # | Milestone | Status |
|---|-----------|--------|
| 0 | Repo scaffold + Ubuntu environment setup | ✅ Complete |
| 1 | OPNsense continuous capture + Suricata | ✅ Complete |
| 2 | Attack scripts on Kali | ✅ Complete |
| 3 | Ubuntu pipeline — sync, CICFlowMeter, labeling | 🔧 In Progress |
| 4 | First capture session | ⬜ Pending |
| 5 | Preprocessing pipeline | ⬜ Pending |
| 6 | Model training + evaluation | ⬜ Pending |
| 7 | Ollama explainability layer | ⬜ Pending |
| 8 | Notebook + README + writeup | ⬜ Pending |

---

## Background

Built as Project 2 of a cybersecurity/AI portfolio by a graduate student entering Carnegie Mellon University's MSISPM program. CompTIA Security+, Network+, ISC2 CC, Microsoft AI-900 certified.
