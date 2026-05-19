# Attack Scripts

These scripts are run manually from **Kali Linux (192.168.20.20)** via RDP.
Scripts are located at `/home/attacker/attack-scripts/` on the Kali VM.

---

## Quick Start — Full Capture Session

### Step 1 — Start benign traffic (Ubuntu Server)
```bash
cd /home/terickson/traffic-generation-scripts
bash run-benign-all.sh
```

### Step 2 — Run all attacks (Kali)
```bash
cd /home/attacker/attack-scripts
sudo bash run-all-attacks.sh
```
Press **Enter** when prompted. All 8 attacks run sequentially with automatic
session logging. Total runtime: ~90 minutes.

### Step 3 — Stop benign traffic (Ubuntu Server, when attacks finish)
```bash
cd /home/terickson/traffic-generation-scripts
bash stop-benign-all.sh
```

### Step 4 — Copy session log entries
The attack script prints a session log at the end. Copy those entries into
`data/session_log.csv` on the Ubuntu Server.

---

## Running Individual Scripts

```bash
# Always run as root
sudo bash /home/attacker/attack-scripts/<script-name>

# Examples
sudo bash nmap-syn-scan.sh
sudo bash hydra-ssh-brute.sh
python3 c2-beacon.py --mode regular --duration 120
```

Log the session manually in `data/session_log.csv` after each run.

---

## Script Inventory

| Script | Attack Type | Target | Approx Runtime |
|--------|-------------|--------|----------------|
| `nmap-syn-scan.sh` | SYN port scan (all 65535 ports) | All VLAN 30 hosts | 70-90 min |
| `nmap-service-scan.sh` | Service + OS detection (`-sV -O -sC`) (all 65535 ports) | All VLAN 30 hosts | 80-100 min |
| `nmap-evasion-scan.sh` | IDS/firewall evasion (fragmentation, decoys, TTL, badsum) | Metasploitable | 5-8 min |
| `hydra-ssh-brute.sh` | SSH credential brute force | Metasploitable (192.168.30.20) | 3-5 min |
| `hydra-http-brute.sh` | HTTP form brute force (DVWA, phpMyAdmin) | Metasploitable (192.168.30.20) | 3-5 min |
| `slowhttptest-dos.sh` | Slow HTTP DoS (Slowloris) | Metasploitable ports 80 + 8180 | 5 min |
| `c2-beacon.py` | C2 beaconing simulation (regular, jitter, exfil) | Metasploitable (192.168.30.20) | 6-12 min |
| `metasploit-ms17010.sh` | EternalBlue SMB exploit attempt | Metasploitable (192.168.30.20) | 3-5 min |
| `run-all-attacks.sh` | **Master script — runs all 8 above sequentially** | All VLAN 30 hosts | ~90 min |

---

## Session Log Format

`run-all-attacks.sh` logs sessions automatically. For manual runs, add a row to
`data/session_log.csv` on the Ubuntu Server:

```
timestamp_start,timestamp_end,scenario,targets,label,notes
2026-05-15 14:00:00,2026-05-15 14:04:00,nmap_syn_scan,"192.168.30.10,192.168.30.20,192.168.30.2",malicious,full port range
2026-05-15 14:05:00,2026-05-15 14:18:00,nmap_service_scan,"192.168.30.10,192.168.30.20,192.168.30.2",malicious,sV sC sS OS detection
2026-05-15 14:20:00,2026-05-15 14:26:00,nmap_evasion_scan,192.168.30.20,malicious,fragmentation decoys TTL badsum
2026-05-15 14:28:00,2026-05-15 14:32:00,hydra_ssh_brute,192.168.30.20,malicious,rockyou subset
2026-05-15 14:34:00,2026-05-15 14:38:00,hydra_http_brute,192.168.30.20,malicious,DVWA phpMyAdmin
2026-05-15 14:40:00,2026-05-15 14:46:00,c2_beacon,192.168.30.20,malicious,regular jitter exfil
2026-05-15 14:48:00,2026-05-15 14:52:00,slowhttptest_dos,192.168.30.20,malicious,500 connections ports 80 8180
2026-05-15 14:54:00,2026-05-15 14:58:00,metasploit_ms17010,192.168.30.20,malicious,EternalBlue attempt
```

**Rules:**
- Always use ISO format: `YYYY-MM-DD HH:MM:SS`
- `targets` — comma-separated IPs attacked
- `label` — always `malicious` for attack scripts
- `notes` — record outcome, flags used, anything notable

---

## Recommended Attack Order

1. `nmap-syn-scan.sh` — fast reconnaissance
2. `nmap-service-scan.sh` — detailed fingerprinting
3. `nmap-evasion-scan.sh` — evasion techniques
4. `hydra-ssh-brute.sh` — credential attack
5. `hydra-http-brute.sh` — web credential attack
6. `c2-beacon.py` — persistent low-noise traffic
7. `slowhttptest-dos.sh` — resource exhaustion
8. `metasploit-ms17010.sh` — active exploitation (most aggressive, run last)

60 second pause between each attack (handled automatically by `run-all-attacks.sh`).

---

## What Suricata Will Detect

| Script | Expected Suricata Alerts |
|--------|--------------------------|
| `nmap-syn-scan.sh` | ET SCAN Nmap SYN scan |
| `nmap-service-scan.sh` | ET SCAN Nmap Scripting Engine User-Agent |
| `nmap-evasion-scan.sh` | Mixed — some techniques evade, some don't |
| `hydra-ssh-brute.sh` | ET SCAN SSH BruteForce |
| `hydra-http-brute.sh` | ET SCAN Hydra HTTP brute force |
| `slowhttptest-dos.sh` | ET DOS Slowloris |
| `c2-beacon.py` | Possibly none — designed to evade detection |
| `metasploit-ms17010.sh` | ET EXPLOIT MS17-010 EternalBlue |

---

## Safety Notes

- All scripts target **VLAN 30 only** — the isolated victim segment
- OPNsense firewall rules prevent traffic reaching VLAN 10 (management)
- Never run these scripts against production or internet-facing systems
- Kali VM is isolated on VLAN 20 — no internet access during attack sessions
