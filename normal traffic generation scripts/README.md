# Traffic Generation Scripts

Benign traffic generation scripts for the `ai-traffic-classifier` dataset.
These run on the **Ubuntu Server VM (192.168.10.4)** and simulate normal
network activity that runs continuously during attack capture sessions.

Scripts are located at `/home/terickson/traffic-generation-scripts/` on the
Ubuntu Server VM.

---

## Quick Start

### Start all benign traffic (run before attacks)
```bash
cd /home/terickson/traffic-generation-scripts
bash run-benign-all.sh
```

### Stop all benign traffic (run after attacks finish)
```bash
cd /home/terickson/traffic-generation-scripts
bash stop-benign-all.sh
```

---

## How It Works

Benign scripts run **continuously in the background** alongside attack scripts.
They loop automatically — when one cycle finishes, it immediately restarts.

```
Ubuntu Server                          Kali Linux
─────────────────────────────          ─────────────────────
bash run-benign-all.sh                 sudo bash run-all-attacks.sh
  └── web traffic (looping)              └── nmap-syn-scan.sh
  └── dns queries (looping)              └── nmap-service-scan.sh
  └── ssh sessions (looping)             └── hydra-ssh-brute.sh
  └── file transfers (looping)           └── ... (8 scripts total)
  └── ping sweep (looping)
                    ↓ (when attacks done)
bash stop-benign-all.sh
```

---

## Script Inventory

| Script | Traffic Type | Source → Target | What It Generates |
|--------|-------------|-----------------|-------------------|
| `benign-web-traffic.sh` | HTTP/HTTPS browsing | Ubuntu Server → VLAN 30 web services | GET requests with realistic user agents, varied timing |
| `benign-dns-queries.sh` | DNS resolution | Ubuntu Server → OPNsense (192.168.10.1) | A/AAAA queries to internal and external hostnames |
| `benign-ssh-session.sh` | SSH admin sessions | Ubuntu Server → Metasploitable (192.168.30.20) | 8 sessions with real commands (ls, ps, df, netstat) |
| `benign-file-transfer.sh` | SCP file transfers | Ubuntu Server ↔ Metasploitable | Uploads and downloads of 10KB–2MB files |
| `benign-ping-sweep.sh` | ICMP connectivity | Ubuntu Server → All lab hosts | Periodic ping checks every 30-60 seconds |
| `run-benign-all.sh` | **Master start script** | — | Starts all 5 scripts looping in background |
| `stop-benign-all.sh` | **Master stop script** | — | Kills all 5 scripts cleanly |

---

## Running Individual Scripts

```bash
# Run once (finishes after one cycle)
bash benign-web-traffic.sh

# Run continuously until Ctrl+C
while true; do bash benign-web-traffic.sh; done

# Run in background
bash benign-web-traffic.sh &
```

---

## Checking Script Status

```bash
# Check how many benign processes are running (should be 10 = 5 loops + 5 scripts)
ps aux | grep benign | grep -v grep | wc -l

# View live logs for each script
tail -f /tmp/web-traffic.log
tail -f /tmp/dns-queries.log
tail -f /tmp/ssh-session.log
tail -f /tmp/file-transfer.log
tail -f /tmp/ping-sweep.log
```

---

## Installing Scripts on Ubuntu Server

### Option A — Copy from Alienware via SCP (recommended)
```powershell
# From Alienware PowerShell
scp C:\Users\tycee\Downloads\benign-scripts\* terickson@100.82.166.75:/home/terickson/traffic-generation-scripts/
```

### Option B — Clone from GitHub
```bash
# On Ubuntu Server
cd ~
git clone https://github.com/tyceerickson/ai-traffic-classifier.git
cp "ai-traffic-classifier/normal traffic generation scripts/"* \
   /home/terickson/traffic-generation-scripts/
```

### Make scripts executable after copying
```bash
chmod +x /home/terickson/traffic-generation-scripts/*.sh
```

---

## Session Log

Benign scripts do **not** need individual entries in `session_log.csv`.
The labeling pipeline (`label_flows.py`) automatically labels any flow that
falls **outside** a logged attack window as benign (label=0).

Only attack sessions go in `session_log.csv`:
```
timestamp_start,timestamp_end,scenario,targets,label,notes
2026-05-18 19:24:59,2026-05-18 21:15:11,nmap_syn_scan,...,malicious,...
```

Everything else — all web traffic, DNS queries, SSH sessions, file transfers,
and pings — gets labeled `0` (benign) automatically.

---

## Prerequisites

Tools install automatically via the scripts, but verify these are present:

```bash
curl --version
dig -v
sshpass -V
ping -c 1 localhost

# Install anything missing
sudo apt-get install -y curl dnsutils sshpass iputils-ping
```

---

## Traffic Characteristics

| Script | Flow Features | Why It Matters for ML |
|--------|--------------|----------------------|
| Web traffic | Irregular timing, varied packet sizes, HTTP layer, short TCP connections | Represents normal user browsing — contrasts with attack flood patterns |
| DNS queries | Small UDP to port 53, very short flows, query/response pairs | Normal background traffic every device generates constantly |
| SSH sessions | Encrypted TCP to port 22, longer duration (30-120s), moderate volume | Normal admin activity — contrasts with SSH brute force |
| File transfers | Large sustained TCP flows, high throughput, long duration, asymmetric bytes | Normal data movement — contrasts with C2 exfiltration |
| Ping sweep | ICMP echo pairs, 84-byte packets, regular 30-60 second intervals | Normal monitoring — contrasts with Nmap aggressive scanning |
