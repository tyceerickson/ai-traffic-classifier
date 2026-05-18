#!/bin/bash
# ============================================================
# run-all-attacks.sh
# Runs all attack scripts sequentially with automatic logging.
#
# Run on: Kali Linux (192.168.20.20) as root
# Location: /home/attacker/attack-scripts/
# Usage:  sudo bash run-all-attacks.sh
#
# Before running:
#   1. Start benign traffic on Ubuntu Server:
#      bash run-benign-all.sh
#   2. Run this script on Kali
#   3. When done, stop benign traffic:
#      bash stop-benign-all.sh
# ============================================================
 
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Must run as root: sudo bash run-all-attacks.sh"
    exit 1
fi
 
SCRIPT_DIR="/home/attacker/attack-scripts"
SESSION_LOG="/tmp/session-log-entries.csv"
PAUSE_BETWEEN=60
 
log_session() {
    local scenario=$1
    local targets=$2
    local start=$3
    local end=$4
    local notes=$5
    echo "${start},${end},${scenario},${targets},malicious,${notes}" >> "$SESSION_LOG"
    echo "[+] Logged: ${scenario}"
}
 
echo "============================================"
echo " Master Attack Script"
echo " Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Scripts: ${SCRIPT_DIR}"
echo " Session log: ${SESSION_LOG}"
echo "============================================"
echo ""
echo "[!] Make sure benign scripts are running on"
echo "    Ubuntu Server before continuing."
echo ""
read -p "Press ENTER when ready to begin attacks..."
echo ""
 
echo "timestamp_start,timestamp_end,scenario,targets,label,notes" > "$SESSION_LOG"
 
# ── Attack 1: Nmap SYN Scan ───────────────────────────────────
echo "============================================"
echo "[1/8] Nmap SYN Scan"
echo "============================================"
START=$(date '+%Y-%m-%d %H:%M:%S')
bash "${SCRIPT_DIR}/nmap-syn-scan.sh"
END=$(date '+%Y-%m-%d %H:%M:%S')
log_session "nmap_syn_scan" "192.168.30.10,192.168.30.20,192.168.30.2" "$START" "$END" "full port range SYN scan"
echo "[*] Pausing ${PAUSE_BETWEEN}s..."
sleep $PAUSE_BETWEEN
 
# ── Attack 2: Nmap Service Scan ──────────────────────────────
echo "============================================"
echo "[2/8] Nmap Service + OS Detection Scan"
echo "============================================"
START=$(date '+%Y-%m-%d %H:%M:%S')
bash "${SCRIPT_DIR}/nmap-service-scan.sh"
END=$(date '+%Y-%m-%d %H:%M:%S')
log_session "nmap_service_scan" "192.168.30.10,192.168.30.20,192.168.30.2" "$START" "$END" "sV sC sS OS detection"
echo "[*] Pausing ${PAUSE_BETWEEN}s..."
sleep $PAUSE_BETWEEN
 
# ── Attack 3: Nmap Evasion Scan ──────────────────────────────
echo "============================================"
echo "[3/8] Nmap IDS/Firewall Evasion Scan"
echo "============================================"
START=$(date '+%Y-%m-%d %H:%M:%S')
bash "${SCRIPT_DIR}/nmap-evasion-scan.sh"
END=$(date '+%Y-%m-%d %H:%M:%S')
log_session "nmap_evasion_scan" "192.168.30.20" "$START" "$END" "fragmentation decoys TTL badsum combined"
echo "[*] Pausing ${PAUSE_BETWEEN}s..."
sleep $PAUSE_BETWEEN
 
# ── Attack 4: Hydra SSH Brute Force ──────────────────────────
echo "============================================"
echo "[4/8] Hydra SSH Brute Force"
echo "============================================"
START=$(date '+%Y-%m-%d %H:%M:%S')
bash "${SCRIPT_DIR}/hydra-ssh-brute.sh"
END=$(date '+%Y-%m-%d %H:%M:%S')
log_session "hydra_ssh_brute" "192.168.30.20" "$START" "$END" "SSH credential brute force rockyou subset"
echo "[*] Pausing ${PAUSE_BETWEEN}s..."
sleep $PAUSE_BETWEEN
 
# ── Attack 5: Hydra HTTP Brute Force ─────────────────────────
echo "============================================"
echo "[5/8] Hydra HTTP Form Brute Force"
echo "============================================"
START=$(date '+%Y-%m-%d %H:%M:%S')
bash "${SCRIPT_DIR}/hydra-http-brute.sh"
END=$(date '+%Y-%m-%d %H:%M:%S')
log_session "hydra_http_brute" "192.168.30.20" "$START" "$END" "DVWA phpMyAdmin HTTP form brute force"
echo "[*] Pausing ${PAUSE_BETWEEN}s..."
sleep $PAUSE_BETWEEN
 
# ── Attack 6: C2 Beacon ──────────────────────────────────────
echo "============================================"
echo "[6/8] C2 Beacon Simulation"
echo "============================================"
START=$(date '+%Y-%m-%d %H:%M:%S')
python3 "${SCRIPT_DIR}/c2-beacon.py" --mode all --duration 120 --interval 15
END=$(date '+%Y-%m-%d %H:%M:%S')
log_session "c2_beacon" "192.168.30.20" "$START" "$END" "regular jitter exfil modes 120s each"
echo "[*] Pausing ${PAUSE_BETWEEN}s..."
sleep $PAUSE_BETWEEN
 
# ── Attack 7: Slow HTTP DoS ───────────────────────────────────
echo "============================================"
echo "[7/8] Slow HTTP DoS (Slowloris)"
echo "============================================"
START=$(date '+%Y-%m-%d %H:%M:%S')
bash "${SCRIPT_DIR}/slowhttptest-dos.sh"
END=$(date '+%Y-%m-%d %H:%M:%S')
log_session "slowhttptest_dos" "192.168.30.20" "$START" "$END" "Slowloris 500 connections port 80 and 8180"
echo "[*] Pausing ${PAUSE_BETWEEN}s..."
sleep $PAUSE_BETWEEN
 
# ── Attack 8: Metasploit MS17-010 ────────────────────────────
echo "============================================"
echo "[8/8] Metasploit MS17-010 EternalBlue"
echo "============================================"
START=$(date '+%Y-%m-%d %H:%M:%S')
bash "${SCRIPT_DIR}/metasploit-ms17010.sh"
END=$(date '+%Y-%m-%d %H:%M:%S')
log_session "metasploit_ms17010" "192.168.30.20" "$START" "$END" "EternalBlue SMB exploit attempt"
 
# ── Final summary ─────────────────────────────────────────────
echo ""
echo "============================================"
echo " All attacks complete!"
echo " Finished: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""
echo "NEXT STEPS:"
echo "  1. Copy session log entries below into"
echo "     data/session_log.csv on Ubuntu Server"
echo "  2. Stop benign traffic on Ubuntu Server:"
echo "     bash stop-benign-all.sh"
echo "  3. Run pipeline on Ubuntu Server:"
echo "     bash pipeline/sync-pcaps.sh"
echo "     bash pipeline/run-cicflowmeter.sh"
echo "     python3 pipeline/label-flows.py"
echo ""
echo "---- SESSION LOG ENTRIES ----"
cat "$SESSION_LOG"
 
