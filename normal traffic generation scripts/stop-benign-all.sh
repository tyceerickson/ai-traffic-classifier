#!/bin/bash
# ============================================================
# stop_benign_all.sh
# Stops all benign traffic scripts started by run_benign_all.sh
#
# Run on: Ubuntu Server VM (192.168.10.4)
# Usage:  bash stop_benign_all.sh
# ============================================================

PID_FILE="/tmp/benign_pids.txt"

echo "============================================"
echo " Stopping All Benign Traffic Scripts"
echo " Stopped: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""

if [ ! -f "$PID_FILE" ]; then
    echo "[!] No PID file found — killing by process name instead..."
    pkill -f "benign-web-traffic.sh"
    pkill -f "benign-dns-queries.sh"
    pkill -f "benign-ssh-session.sh"
    pkill -f "benign-file-transfer.sh"
    pkill -f "benign-ping-sweep.sh"
else
    while read pid; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            echo "[-] Stopped PID ${pid}"
        fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
fi

# Kill any child processes too
pkill -f "benign_" 2>/dev/null
pkill -f "curl.*192.168" 2>/dev/null
pkill -f "dig.*192.168" 2>/dev/null
pkill -f "sshpass" 2>/dev/null

echo ""
echo "[+] All benign scripts stopped"
echo "[!] Record end time in session_log.csv"
