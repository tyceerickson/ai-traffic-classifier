#!/bin/bash
# ============================================================
# benign_ssh_session.sh
# Traffic Type: Normal SSH session with file operations
# Source: Ubuntu Server VM (192.168.10.4)
# Target: Metasploitable (192.168.30.20) — msfadmin:msfadmin
#
# Simulates a sysadmin doing normal work over SSH — checking
# logs, listing files, running commands. Generates encrypted
# session traffic that looks nothing like brute force.
#
# Requires: sshpass (installed if missing)
# Usage: bash benign_ssh_session.sh
# Log in session_log.csv: label=benign, scenario=benign_ssh_session
# ============================================================

TARGET_IP="192.168.30.20"
TARGET_USER="msfadmin"
TARGET_PASS="msfadmin"

# Install sshpass if not present
if ! command -v sshpass &> /dev/null; then
    echo "[*] Installing sshpass..."
    sudo apt-get install -y sshpass > /dev/null 2>&1
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=no"

echo "============================================"
echo " Benign SSH Session Simulation"
echo " Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Target: ${TARGET_USER}@${TARGET_IP}"
echo "============================================"
echo "[!] Record start time in session_log.csv"
echo ""

run_ssh_command() {
    sshpass -p "$TARGET_PASS" ssh $SSH_OPTS \
        "${TARGET_USER}@${TARGET_IP}" "$1" 2>/dev/null
}

SESSION_COUNT=0

for i in $(seq 1 8); do
    echo "[*] SSH session $i..."

    # Simulate different types of normal admin activity
    case $((RANDOM % 6)) in
        0) run_ssh_command "ls -la /home/ && echo done" ;;
        1) run_ssh_command "df -h && uptime" ;;
        2) run_ssh_command "ps aux | head -20" ;;
        3) run_ssh_command "cat /etc/passwd | head -10" ;;
        4) run_ssh_command "netstat -an | head -20" ;;
        5) run_ssh_command "find /tmp -type f 2>/dev/null | head -10" ;;
    esac

    SESSION_COUNT=$((SESSION_COUNT + 1))

    # Realistic pause between sessions (15-45 seconds)
    PAUSE=$((RANDOM % 31 + 15))
    echo "  [*] Waiting ${PAUSE}s before next session..."
    sleep $PAUSE
done

echo ""
echo "============================================"
echo " Complete: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Total sessions: ${SESSION_COUNT}"
echo "============================================"
echo "[!] Record end time in session_log.csv"
echo "[!] Label: benign | Scenario: benign_ssh_session"
