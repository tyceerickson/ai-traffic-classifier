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

That's it. All 5 scripts start and stop with a single command.

---

## How It Works

Benign scripts run **continuously in the background** alongside attack scripts.
They loop automatically — when one cycle finishes, it immediately restarts.
This ensures the dataset has realistic benign traffic throughout the entire
capture session, not just at the start.

```
Ubuntu Server                          Kali Linux
─────────────────────────────          ─────────────────────
bash run-benign-all.sh                 sudo bash run-all-attacks.sh
  └── web traffic (looping)              └── nmap-syn-scan.sh
  └── dns queries (looping)             └── nmap-service-scan.sh
  └── ssh sessions (looping)            └── hydra-ssh-brute.sh
  └── file transfers (looping)          └── ... (8 scripts total)
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

If you want to run a single benign script for testing:

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

Check which benign scripts are currently running:
```bash
ps aux | grep benign
```

View live logs for each script:
```bash
tail -f /tmp/web_traffic.log
tail -f /tmp/dns_queries.log
tail -f /tmp/ssh_session.log
tail -f /tmp/file_transfer.log
tail -f /tmp/ping_sweep.log
```

---

## Session Log

Benign scripts do **not** need individual entries in `data/session_log.csv`.
The labeling pipeline (`label_flows.py`) automatically labels any flow that
falls **outside** a logged attack window as benign.

The only entries in `session_log.csv` should be attack sessions:
```
timestamp_start,timestamp_end,scenario,targets,label,notes
2026-05-15 14:00:00,2026-05-15 14:04:00,nmap_syn_scan,...,malicious,...
```

Everything else — all the web traffic, DNS queries, SSH sessions, file
transfers, and pings — gets labeled `0` (benign) automatically.

---

## Installing Scripts on Ubuntu Server

### Option A — Clone from GitHub (recommended)
```bash
cd ~
git clone https://github.com/tyceerickson/ai-traffic-classifier.git
cp -r ai-traffic-classifier/benign-scripts /home/terickson/traffic-generation-scripts
chmod +x /home/terickson/traffic-generation-scripts/*.sh
```

### Option B — Copy from Alienware via SCP
From your Alienware (Windows PowerShell or Git Bash):
```bash
scp -r /path/to/benign-scripts/* homeserver:/home/terickson/traffic-generation-scripts/
```

Or using Tailscale IP directly:
```bash
scp -r C:\Users\tycee\Downloads\benign-scripts\* terickson@100.82.166.75:/home/terickson/traffic-generation-scripts/
```

### Make scripts executable after copying
```bash
chmod +x /home/terickson/traffic-generation-scripts/*.sh
```

---

## Prerequisites

Scripts install missing tools automatically, but these should be present:

```bash
# Verify tools are available
curl --version
dig -v
sshpass -V
ping -V

# Install anything missing
sudo apt-get install -y curl dnsutils sshpass iputils-ping
```

---

## Traffic Characteristics

Understanding what each script generates helps interpret the ML model's
feature importance output:

**Web traffic** — irregular timing, varied packet sizes, HTTP application
layer data, multiple short-lived TCP connections to port 80/443.

**DNS queries** — small UDP packets to port 53, very short duration flows,
query/response pairs, mix of A and AAAA record types.

**SSH sessions** — encrypted TCP flows to port 22, longer duration (30-120s),
moderate data volume, clean connection establishment and teardown.

**File transfers** — large sustained TCP flows, high throughput, long duration,
much more data outbound than inbound (upload) or inbound (download).

**Ping sweep** — ICMP echo request/reply pairs, very small packets (84 bytes),
regular 30-60 second intervals, one host at a time.

These characteristics produce distinct feature vectors in CICFlowMeter output,
giving the Random Forest classifier clear benign patterns to learn from.
