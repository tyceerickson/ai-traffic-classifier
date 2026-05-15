#!/bin/bash
# ============================================================
# benign_dns_queries.sh
# Traffic Type: Normal DNS resolution traffic
# Source: Ubuntu Server VM (192.168.10.4)
# Target: OPNsense DNS resolver (192.168.10.1)
#
# Simulates normal DNS lookups — the kind any device generates
# constantly in the background just by being on a network.
#
# Usage: bash benign_dns-queries.sh
# Log in session_log.csv: label=benign, scenario=benign_dns_queries
# ============================================================

DNS_SERVER="192.168.10.1"

# Mix of internal and external hostnames
# Internal = lab devices by hostname
# External = real domains (resolved by OPNsense upstream)
HOSTNAMES=(
    "google.com"
    "github.com"
    "cloudflare.com"
    "amazon.com"
    "microsoft.com"
    "apple.com"
    "ubuntu.com"
    "stackoverflow.com"
    "192.168.30.20"
    "192.168.30.10"
    "OPNsense.internal"
    "time.cloudflare.com"
    "pool.ntp.org"
    "apt.ubuntu.com"
    "security.ubuntu.com"
)

DURATION=300
END_TIME=$(($(date +%s) + DURATION))

echo "============================================"
echo " Benign DNS Query Simulation"
echo " Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo " DNS Server: ${DNS_SERVER}"
echo " Duration: ${DURATION}s"
echo "============================================"
echo "[!] Record start time in session_log.csv"
echo ""

QUERY_COUNT=0

while [ $(date +%s) -lt $END_TIME ]; do
    HOST="${HOSTNAMES[$((RANDOM % ${#HOSTNAMES[@]}))]}"

    # Alternate between query types like a real system does
    QTYPE_ROLL=$((RANDOM % 3))
    if [ $QTYPE_ROLL -eq 0 ]; then
        dig @"$DNS_SERVER" A "$HOST" +short +time=2 > /dev/null 2>&1
    elif [ $QTYPE_ROLL -eq 1 ]; then
        dig @"$DNS_SERVER" AAAA "$HOST" +short +time=2 > /dev/null 2>&1
    else
        dig @"$DNS_SERVER" "$HOST" +short +time=2 > /dev/null 2>&1
    fi

    QUERY_COUNT=$((QUERY_COUNT + 1))

    # Short delays — DNS queries happen frequently in background
    sleep $((RANDOM % 4 + 1))
done

echo ""
echo "============================================"
echo " Complete: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Total queries: ${QUERY_COUNT}"
echo "============================================"
echo "[!] Record end time in session_log.csv"
echo "[!] Label: benign | Scenario: benign_dns_queries"
