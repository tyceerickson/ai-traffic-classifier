# AI-Powered Network Traffic Classifier

> Local ML model trained on real malicious and benign network traffic generated in a home cybersecurity lab.

**Status:** Completed

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
Training set: 610,137 flows | Test set: 152,535 flows | Features: 78 (CICFlowMeter produces 82 raw flow columns; 4 non-feature identifier columns plus any zero-variance columns are dropped during preprocessing, leaving 78 training features)

> Note: Near-perfect results are expected for lab-generated traffic with highly distinctive
> attack patterns. Real-world performance on unseen network environments would be lower —
> a known and acknowledged limitation of lab-generated datasets documented in the writeup.

---

## Lab Architecture

| Component | Details |
|-----------|---------|
| Firewall | OPNsense 26.1 — continuous PCAP capture on vlan0.20 |
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
Kali Linux — attack scripts
        │
        ▼
OPNsense Firewall (192.168.10.1)
  └── Built-in packet capture → /tmp/captures/*.pcap
        │  rsync hourly cron
        ▼
Ubuntu Server VM (192.168.10.4)  ← pipeline engine
  ├── /opt/pcaps/                ← raw PCAPs land here
  ├── pcap_to_csv.py             ← CICFlowMeter flow extraction
  ├── pipeline/run_suricata.sh   ← offline IDS analysis (NOT on OPNsense)
  └── pipeline/label_flows.py   ← timestamp-based labeling
        │  scp on demand
        ▼
Alienware m16 R2  ← training workstation
  ├── src/preprocessing.py      ← clean, scale, balance (3:1 undersample)
  ├── src/train.py              ← Random Forest + XGBoost (CUDA) + DT + LR
  ├── src/evaluate.py           ← metrics and visualizations
  └── src/explain.py            ← Ollama llama3.1:8b LLM explanations
```

> **Note on Suricata:** Suricata IDS runs offline on the Ubuntu Server against PCAP
> files — NOT live on OPNsense. OPNsense 26.1 + Suricata 8.0.3 has a known
> compatibility issue on VLAN interfaces in PCAP mode on FreeBSD. Running offline
> on Ubuntu Server is more reliable and produces identical alert output.

---

## Attack Scenarios

| Scenario | Tool | Target | Flows Generated |
|----------|------|--------|-----------------|
| SYN port scan (all 65,535 ports) | Nmap | All VLAN 30 hosts | 525,288 |
| Service + OS detection (-sV -O -sC) | Nmap | All VLAN 30 hosts | 526,181 |
| IDS/Firewall evasion (fragmentation, decoys, TTL, badsum) | Nmap | Metasploitable | 156 |
| SSH credential brute force | Hydra | Metasploitable | 2 |
| HTTP form brute force (DVWA, phpMyAdmin) | Hydra | Metasploitable | 546 |
| C2 beaconing simulation (regular, jitter, exfil) | Custom Python | Metasploitable | 53 |
| Slow HTTP DoS (Slowloris) | slowhttptest | Metasploitable | 3,795 |
| EternalBlue MS17-010 exploit attempt | Metasploit | Metasploitable | 18 |

---

## Benign Traffic Scenarios

| Scenario | Tool | Runs From |
|----------|------|-----------|
| HTTP/HTTPS web browsing | curl | Ubuntu Server |
| DNS queries (A/AAAA, mixed hosts) | dig | Ubuntu Server |
| SSH admin sessions | sshpass/ssh | Ubuntu Server |
| SCP file transfers (10KB–2MB) | scp | Ubuntu Server |
| ICMP ping sweep (periodic) | ping | Ubuntu Server |

---

## Technical Stack

| Layer | Tools |
|-------|-------|
| Capture | OPNsense built-in packet capture (vlan0.20) |
| IDS | Suricata 8.0.4 offline on Ubuntu Server (50,165 ET Open rules) |
| Feature extraction | CICFlowMeter 0.1.9 Python (patched for Scapy 2.7 compatibility) |
| Pipeline | Bash, Python 3, rsync |
| ML | scikit-learn, XGBoost (CUDA/RTX 4070), pandas, NumPy |
| Visualization | matplotlib, seaborn |
| Explainability | Ollama llama3.1:8b (local, RTX 4070 GPU) |
| Notebooks | Jupyter |

---

## Project Structure

```
ai-traffic-classifier/
├── README.md
├── RUNBOOK.md                              ← step-by-step capture session guide
├── .gitignore                              ← excludes large datasets and models
├── data/
│   ├── raw/                                ← PCAP files (not committed)
│   ├── processed/                          ← datasets (not committed — too large)
│   └── session_log.csv                     ← ground truth attack timestamps (UTC)
├── capture/
│   └── README.md                           ← OPNsense capture + Suricata docs
├── pipeline/
│   ├── config.yaml                         ← central config, all paths and parameters
│   ├── ubuntu_setup.sh                     ← one-shot Ubuntu Server environment setup
│   ├── label_flows.py                      ← timestamp-based flow labeling
│   └── run_suricata.sh                     ← offline Suricata PCAP analysis
├── attack-scripts/                         ← Kali attack scripts (run manually)
│   ├── nmap-syn-scan.sh
│   ├── nmap-service-scan.sh
│   ├── nmap-evasion-scan.sh
│   ├── metasploit-ms17010.sh
│   ├── hydra-ssh-brute.sh
│   ├── hydra-http-brute.sh
│   ├── slowhttptest-dos.sh
│   ├── c2-beacon.py
│   ├── run-all-attacks.sh                  ← master script — runs all 8 sequentially
│   └── README.md
├── normal traffic generation scripts/      ← Ubuntu Server benign traffic
│   ├── benign-web-traffic.sh
│   ├── benign-dns-queries.sh
│   ├── benign-ssh-session.sh
│   ├── benign-file-transfer.sh
│   ├── benign-ping-sweep.sh
│   ├── run-benign-all.sh                   ← start all 5 benign scripts
│   ├── stop-benign-all.sh                  ← stop all 5 benign scripts
│   └── README.md
├── src/
│   ├── preprocessing.py                    ← clean, scale, balance dataset
│   ├── train.py                            ← train 4 models + evaluation plots
│   ├── evaluate.py                         ← detailed metrics and visualizations
│   └── explain.py                          ← Ollama LLM explainability (per scenario)
├── notebooks/
│   └── full_pipeline.ipynb                 ← end-to-end narrative walkthrough
├── models/                                 ← serialized trained models (not committed)
├── results/
│   ├── evaluation_report.md                ← model comparison table
│   ├── explanations.md                     ← LLM explanations — all 8 attack types
│   ├── confusion_matrix_random_forest.png
│   ├── confusion_matrix_xgboost.png
│   ├── confusion_matrix_decision_tree.png
│   ├── confusion_matrix_logistic_regression.png
│   ├── roc_curves.png
│   ├── feature_importance.png
│   └── model_comparison.png
└── writeup/
    └── local_vs_cloud.md                   ← local ML vs cloud AI comparison
```

---

## Capture Session Workflow

See [RUNBOOK.md](RUNBOOK.md) for the complete step-by-step guide.

Quick reference:

```bash
# 1. Ubuntu Server — start benign traffic
cd /home/terickson/traffic-generation-scripts
bash run-benign-all.sh

# 2. Kali — run all attacks (~4-5 hours for full port scan)
cd /home/attacker/attack-scripts
sudo bash run-all-attacks.sh

# 3. Ubuntu Server — stop benign traffic
bash stop-benign-all.sh

# 4. Ubuntu Server — sync PCAPs from OPNsense
ssh opnsense  # type 8, then:
/usr/local/sbin/rsync-to-ubuntu.sh

# 5. Ubuntu Server — run pipeline
python3 ~/pcap_to_csv.py /opt/pcaps/ /opt/cicflow_output/merged_flows.csv
bash ~/pipeline/run_suricata.sh /opt/pcaps/
python3 ~/pipeline/label_flows.py \
  --cicflow-dir /opt/cicflow_output \
  --session-log /home/terickson/data/session_log.csv \
  --output /home/terickson/data/features.csv

# 6. Alienware — train model
python src/preprocessing.py
python src/train.py
python src/explain.py
```

---

## Milestones

| # | Milestone | Status |
|---|-----------|--------|
| 0 | Repo scaffold + Ubuntu environment setup | ✅ Complete |
| 1 | OPNsense continuous capture + Suricata (offline) | ✅ Complete |
| 2 | Attack + benign traffic scripts | ✅ Complete |
| 3 | Ubuntu pipeline — CICFlowMeter, labeling, Suricata offline | ✅ Complete |
| 4 | First capture session (1,201,560 flows, 727 Suricata alerts) | ✅ Complete |
| 5 | Preprocessing pipeline | ✅ Complete |
| 6 | Model training + evaluation | ✅ Complete |
| 7 | Ollama llama3.1:8b explainability layer | ✅ Complete |
| 8 | Notebook + README + writeup | ✅ Complete |

---

## Background

Built as Project 2 of a cybersecurity/AI portfolio by a graduate student entering
Carnegie Mellon University's MSISPM program.
CompTIA Security+, Network+, ISC2 CC, Microsoft AI-900 certified.
