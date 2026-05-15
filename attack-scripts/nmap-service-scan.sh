#!/bin/bash
# ============================================================
# nmap_service_scan.sh
# Attack Type: Service version + OS detection scan
# Tool: Nmap
# Source: Kali Linux (192.168.20.20) — run as root
# Targets: All VLAN 30 victim hosts
#
# What this does:
#   Goes beyond port discovery — identifies what software is
#   running on each open port and fingerprints the OS.
#   Sends real application-layer probes (HTTP requests, FTP
#   banner grabs, SSH handshakes) to elicit version info.
#
# How it differs from nmap_syn_scan.sh:
#   SYN scan:     "Is port 80 open?" → Yes/No
#   Service scan: "What is on port 80?" → Apache 2.2.8 (Ubuntu)
#
# What Suricata will see:
#   ET SCAN Nmap Scripting Engine user-agent
#   Application layer probes across multiple protocols
#   OS fingerprinting packet sequences
#   Different flow patterns than pure SYN scan
#
# Usage:
#   sudo bash nmap-service-scan.sh
#
# After running, log this session in data/session_log.csv:
#   timestamp_start, timestamp_end, nmap_service_scan,
#   192.168.30.10/192.168.30.20/192.168.30.2, malicious, <notes>
# ============================================================

# ── Safety check ─────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] This script must be run as root (sudo)"
    exit 1
fi

# ── Configuration ────────────────────────────────────────────
TARGETS=(
    "192.168.30.10"   # Windows 11 VM
    "192.168.30.20"   # Metasploitable
    "192.168.30.2"    # TP-Link AP
)

OUTPUT_DIR="/tmp/scan_results"
mkdir -p "$OUTPUT_DIR"

# ── Logging ──────────────────────────────────────────────────
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

echo "============================================"
echo " Nmap Service + OS Detection Scan"
echo " Started:  $(date '+%Y-%m-%d %H:%M:%S')"
echo " Targets:  ${TARGETS[*]}"
echo "============================================"
echo ""
echo "[!] Record this start time in session_log.csv"
echo ""

# ── Run the scan ─────────────────────────────────────────────
for TARGET in "${TARGETS[@]}"; do
    echo "[*] Scanning ${TARGET}..."

    # Nmap flags explained:
    #
    # -sS     → SYN scan to find open ports first (fast, requires root)
    #
    # -sV     → Service/version detection
    #           Nmap sends protocol-specific probes to each open port
    #           and reads the response to identify the service and version.
    #           Examples:
    #             Port 22 → sends SSH handshake → "OpenSSH 4.7p1"
    #             Port 80 → sends HTTP GET → "Apache 2.2.8"
    #             Port 21 → reads FTP banner → "vsftpd 2.3.4"
    #
    # -O      → OS detection
    #           Sends crafted packets and analyzes TCP/IP stack behavior
    #           (TTL, window size, TCP options) to fingerprint the OS.
    #           Requires root because it needs raw socket access.
    #
    # -sC     → Default NSE scripts
    #           Runs Nmap's built-in scripts against open ports.
    #           These do things like:
    #             - Grab HTTP titles and headers
    #             - Check for anonymous FTP login
    #             - Enumerate SMB shares
    #             - Pull SSL certificates
    #           This generates the most diverse application traffic
    #           of all the scan types — great for ML feature diversity.
    #
    # -Pn     → Skip ping probe (treat host as up)
    #
    # -p-     → Scan ALL 65,535 ports
    #           Includes ephemeral ports (1024-65535)
    #           Slower but gives complete picture and more traffic data
    #
    # -T4     → Aggressive timing (faster scan)
    #
    # --version-intensity 5 → How hard to try version detection
    #           0 = light probing, 9 = try every probe
    #           5 is a good balance of thoroughness vs speed
    #
    # -oN     → Save output in human-readable format
    # -oX     → Save output in XML format (useful for parsing later)

    nmap -sS -sV -O -sC -Pn -p- -T4 \
        --version-intensity 5 \
        -oN "${OUTPUT_DIR}/service_${TARGET}_${TIMESTAMP}.txt" \
        -oX "${OUTPUT_DIR}/service_${TARGET}_${TIMESTAMP}.xml" \
        "$TARGET"

    echo "[*] Done with ${TARGET}"
    echo ""
    sleep 3
done

# ── Summary ──────────────────────────────────────────────────
echo "============================================"
echo " Scan complete: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Results saved to: ${OUTPUT_DIR}/"
echo "============================================"
echo ""
echo "[!] Record this end time in session_log.csv"
echo "[!] Label: malicious"
echo "[!] Scenario: nmap_service_scan"
echo ""
echo "Key findings to note in session log:"
echo "  - List any interesting services discovered"
echo "  - Note OS fingerprint results"
echo "  - Flag any services with known vulnerabilities"
