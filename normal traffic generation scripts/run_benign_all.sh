#!/bin/bash
# ============================================================
# run_benign_all.sh
# Starts all 5 benign traffic scripts simultaneously in the
# background. Scripts loop continuously until stopped.
#
# Run on: Ubuntu Server VM (192.168.10.4)
# Usage:  bash run_benign_all.sh
# Stop:   bash stop_benign_all.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="/tmp/benign_pids.txt"

# Clear any existing PID file
rm -f "$PID_FILE"

echo "============================================"
echo " Starting All Benign Traffic Scripts"
echo " Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""

start_script() {
    local script=$1
    local name=$2
    while true; do
        bash "${SCRIPT_DIR}/${script}" > "/tmp/${name}.log" 2>&1
        sleep 5  # brief pause before restarting
    done &
    local pid=$!
    echo "$pid" >> "$PID_FILE"
    echo "[+] Started ${name} (PID: ${pid})"
}

start_script "benign_web_traffic.sh"   "web_traffic"
start_script "benign_dns_queries.sh"   "dns_queries"
start_script "benign_ssh_session.sh"   "ssh_session"
start_script "benign_file_transfer.sh" "file_transfer"
start_script "benign_ping_sweep.sh"    "ping_sweep"

echo ""
echo "============================================"
echo " All 5 benign scripts running"
echo " PIDs saved to: ${PID_FILE}"
echo " Logs at: /tmp/*.log"
echo " Stop with: bash stop_benign_all.sh"
echo "============================================"
echo ""
echo "[!] Record start time in session_log.csv"
echo "[!] Now switch to Kali and run attack scripts"
