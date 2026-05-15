#!/bin/bash
# ============================================================
# benign_ping_sweep.sh
# Traffic Type: Normal ICMP / ping traffic
# Source: Ubuntu Server VM (192.168.10.4)
# Targets: All lab hosts
#
# Simulates normal network monitoring and connectivity checks —
# the kind of ICMP traffic any sysadmin or monitoring system
# generates routinely. Very different from Nmap ping sweeps:
# slower, targeted, regular intervals, no port scanning follows.
#
# Usage: bash benign-ping-sweep.sh
# Log in session_log.csv: label=benign, scenario=benign_ping_sweep
# ============================================================

# All known lab hosts
HOSTS=(
    "192.168.10.1"    # OPNsense firewall
    "192.168.10.3"    # Mac Server
    "192.168.20.20"   # Kali Linux
    "192.168.30.10"   # Windows 11
    "192.168.30.20"   # Metasploitable
    "192.168.30.2"    # TP-Link AP
)

DURATION=300
END_TIME=$(($(date +%s) + DURATION))

echo "============================================"
echo " Benign Ping / ICMP Traffic Simulation"
echo " Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Duration: ${DURATION}s"
echo "============================================"
echo "[!] Record start time in session_log.csv"
echo ""

PING_COUNT=0
ROUND=0

while [ $(date +%s) -lt $END_TIME ]; do
    ROUND=$((ROUND + 1))
    echo "[*] Round $ROUND connectivity check..."

    for HOST in "${HOSTS[@]}"; do
        # Normal ping — 3 packets, 1 second interval
        # This is what monitoring tools and sysadmins do
        ping -c 3 -i 1 -W 2 "$HOST" > /dev/null 2>&1
        STATUS=$?
        if [ $STATUS -eq 0 ]; then
            echo "  [+] $HOST — reachable"
        else
            echo "  [-] $HOST — unreachable"
        fi
        PING_COUNT=$((PING_COUNT + 3))

        # Small gap between hosts
        sleep 1
    done

    # Realistic interval between monitoring rounds (30-60 seconds)
    # Real monitoring tools check every 30-60s — not constantly
    INTERVAL=$((RANDOM % 31 + 30))
    echo "  [*] Next check in ${INTERVAL}s..."
    sleep $INTERVAL
done

echo ""
echo "============================================"
echo " Complete: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Total pings sent: ${PING_COUNT}"
echo " Rounds completed: ${ROUND}"
echo "============================================"
echo "[!] Record end time in session_log.csv"
echo "[!] Label: benign | Scenario: benign_ping_sweep"
