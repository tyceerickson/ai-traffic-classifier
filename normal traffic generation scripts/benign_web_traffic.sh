#!/bin/bash
# ============================================================
# benign_web_traffic.sh
# Traffic Type: Normal HTTP/HTTPS web browsing simulation
# Source: Ubuntu Server VM (192.168.10.4)
# Targets: VLAN 30 web services
#
# Simulates a user browsing websites — HTTP GETs, page loads,
# varied user agents, normal request timing.
#
# Usage: bash benign_web_traffic.sh
# Log in session_log.csv: label=benign, scenario=benign_web_traffic
# ============================================================

TARGETS=(
    "http://192.168.30.20"          # Metasploitable Apache
    "http://192.168.30.20:8180"     # Metasploitable Tomcat
    "http://192.168.30.20/dvwa"     # DVWA
    "http://192.168.30.20/mutillidae" # Mutillidae
    "http://192.168.30.10"          # Windows 11 IIS (if running)
)

USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)

DURATION=300  # Run for 5 minutes
END_TIME=$(($(date +%s) + DURATION))

echo "============================================"
echo " Benign Web Traffic Simulation"
echo " Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Duration: ${DURATION}s"
echo "============================================"
echo "[!] Record start time in session_log.csv"
echo ""

REQUEST_COUNT=0

while [ $(date +%s) -lt $END_TIME ]; do
    TARGET="${TARGETS[$((RANDOM % ${#TARGETS[@]}))]}"
    UA="${USER_AGENTS[$((RANDOM % ${#USER_AGENTS[@]}))]}"

    curl -s -o /dev/null -w "%{http_code}" \
        --max-time 5 \
        --user-agent "$UA" \
        --referer "http://192.168.30.20/" \
        "$TARGET" > /dev/null 2>&1

    REQUEST_COUNT=$((REQUEST_COUNT + 1))

    # Randomize delay between requests (2-8 seconds)
    # Human browsing is irregular — not perfectly timed
    sleep $((RANDOM % 7 + 2))
done

echo ""
echo "============================================"
echo " Complete: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Total requests: ${REQUEST_COUNT}"
echo "============================================"
echo "[!] Record end time in session_log.csv"
echo "[!] Label: benign | Scenario: benign_web_traffic"
