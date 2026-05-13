# Attack Scripts

These scripts are run manually from **Kali Linux (192.168.20.20)** via RDP.
Each script targets one or more VLAN 30 hosts.

## How to Use

1. RDP into Kali
2. Choose a script to run
3. Before running: note the current timestamp
4. Run the script
5. After it finishes: note the end timestamp
6. Add an entry to `data/session_log.csv` on the Ubuntu Server

## Session Log Format

Every attack session must be logged. This is your ground truth — the pipeline
uses these timestamps to label flows as malicious or benign automatically.

```
timestamp_start,timestamp_end,scenario,targets,label,notes
2025-05-13 14:00:00,2025-05-13 14:08:00,nmap_syn_scan,192.168.30.20,malicious,full port range
2025-05-13 14:10:00,2025-05-13 14:22:00,metasploit_ms17010,192.168.30.20,malicious,attempted exploit
```

**Rules:**
- Always use ISO format timestamps: `YYYY-MM-DD HH:MM:SS`
- `targets` is the IP(s) you attacked, comma-separated if multiple
- `label` is always `malicious` for attack scripts
- `notes` is optional but useful — record tool version, flags used, outcome

## Scripts (added in Milestone 2)

| Script | Attack Type | Primary Target |
|--------|-------------|----------------|
| `nmap_syn_scan.sh` | Port scan | All VLAN 30 hosts |
| `nmap_os_fingerprint.sh` | OS/service detection | All VLAN 30 hosts |
| `metasploit_ms17010.sh` | Exploit attempt | Metasploitable (192.168.30.20) |
| `hydra_ssh_brute.sh` | SSH brute force | Metasploitable (192.168.30.20) |
| `hydra_http_brute.sh` | HTTP brute force | iMac Ubuntu Server |
| `slowhttptest_dos.sh` | Slow HTTP DoS | iMac Ubuntu Server |
| `c2_beacon.py` | C2-style beacon | configurable |

## Safety Notes

- All scripts target **VLAN 30 only** — the isolated victim segment
- OPNsense firewall rules prevent any traffic reaching VLAN 10 (management)
- Never run these scripts against production or internet-facing systems
