#!/bin/bash
# ============================================================
# nmap_syn_scan.sh
# Attack Type: SYN port scan (stealth scan)
# Tool: Nmap
# Source: Kali Linux (192.168.20.20) — run as root
# Targets: All VLAN 30 victim hosts
#
# What this does:
#   Sends TCP SYN packets to every port on each target.
#   Never completes the handshake — just probes which ports
#   are open, closed, or filtered.
#
# What Suricata will see:
#   ET SCAN Nmap SYN scan signatures (SID 2009582 etc.)
#   High volume of SYN packets from one source
#
# Usage:
#   sudo bash nmap_syn_scan.sh
#
# After running, log this session in data/session_log.csv:
#   timestamp_start, timestamp_end, nmap_syn_scan,
#   192.168.30.10/192.168.30.20, malicious, <notes>
# ============================================================

# ── Safety check ─────────────────────────────────────────────
# SYN scans require raw socket access — must run as root
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] This script must be run as root (sudo)"
    exit 1
fi

# ── Configuration ────────────────────────────────────────────
# Targets — all VLAN 30 victim hosts
TARGETS=(
    "192.168.30.10"   # Windows 11 VM
    "192.168.30.20"   # Metasploitable
    "192.168.30.2"    # TP-Link AP
)

# Port range to scan
# -p 1-1000 covers the most common service ports
# Change to -p- to scan all 65535 ports (slower)
PORT_RANGE="1-1000"

# Output directory for scan results
OUTPUT_DIR="/tmp/scan_results"
mkdir -p "$OUTPUT_DIR"

# ── Logging ──────────────────────────────────────────────────
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="${OUTPUT_DIR}/nmap_syn_${TIMESTAMP}.txt"

echo "============================================"
echo " Nmap SYN Scan"
echo " Started:  $(date '+%Y-%m-%d %H:%M:%S')"
echo " Targets:  ${TARGETS[*]}"
echo " Ports:    ${PORT_RANGE}"
echo " Log file: ${LOG_FILE}"
echo "============================================"
echo ""
echo "[!] Record this start time in session_log.csv"
echo ""

# ── Run the scan ─────────────────────────────────────────────
for TARGET in "${TARGETS[@]}"; do
    echo "[*] Scanning ${TARGET}..."

    # Nmap flags explained:
    # -sS          → SYN scan (half-open, requires root)
    # -Pn          → Skip host discovery ping — treat host as up
    #                (some hosts block ICMP, this ensures we scan anyway)
    # -p           → Port range to scan
    # --open       → Only show open ports in output
    # -T4          → Timing template 4 (aggressive — faster scan)
    # -oN          → Save output to a file in normal format
    nmap -sS -Pn -p "$PORT_RANGE" --open -T4 \
        -oN "${OUTPUT_DIR}/syn_${TARGET}_${TIMESTAMP}.txt" \
        "$TARGET"

    echo "[*] Done with ${TARGET}"
    echo ""

    # Brief pause between targets to avoid overwhelming the network
    sleep 2
done

# ── Summary ──────────────────────────────────────────────────
echo "============================================"
echo " Scan complete: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Results saved to: ${OUTPUT_DIR}/"
echo "============================================"
echo ""
echo "[!] Record this end time in session_log.csv"
echo "[!] Label: malicious"
echo "[!] Scenario: nmap_syn_scan"
