#!/bin/bash
# ============================================================
# run_suricata.sh
# Runs Suricata offline against PCAP files for IDS analysis.
#
# Suricata runs OFFLINE on the Ubuntu Server — NOT live on
# OPNsense. This avoids the OPNsense 26.1 + Suricata 8.0.3
# VLAN interface compatibility issue.
#
# Run on: Ubuntu Server VM (192.168.10.4)
# Location: /home/terickson/pipeline/run_suricata.sh
#
# Usage:
#   bash run_suricata.sh /opt/pcaps/           # process all PCAPs
#   bash run_suricata.sh /opt/pcaps/file.pcap  # single PCAP
#
# Output: /opt/suricata/eve.json
# ============================================================

SURICATA_BIN="/usr/bin/suricata"
SURICATA_CONF="/etc/suricata/suricata.yaml"
OUTPUT_DIR="/opt/suricata"
EVE_JSON="${OUTPUT_DIR}/eve.json"
LOG_FILE="${OUTPUT_DIR}/suricata.log"

INPUT="${1:-/opt/pcaps}"

# ── Validate input ────────────────────────────────────────────
if [ -z "$INPUT" ]; then
    echo "Usage: bash run_suricata.sh <pcap_file_or_directory>"
    exit 1
fi

if [ ! -e "$INPUT" ]; then
    echo "[ERROR] Input not found: $INPUT"
    exit 1
fi

# ── Archive previous eve.json ─────────────────────────────────
if [ -f "$EVE_JSON" ] && [ -s "$EVE_JSON" ]; then
    ARCHIVE="${OUTPUT_DIR}/eve_$(date +%Y%m%d_%H%M%S).json"
    mv "$EVE_JSON" "$ARCHIVE"
    echo "[*] Archived previous eve.json → $(basename $ARCHIVE)"
fi

mkdir -p "$OUTPUT_DIR"

echo "============================================"
echo " Suricata Offline Analysis"
echo " Input:  ${INPUT}"
echo " Config: ${SURICATA_CONF}"
echo " Output: ${EVE_JSON}"
echo " Rules:  $(wc -l < /var/lib/suricata/rules/suricata.rules) lines"
echo "============================================"
echo ""

# ── Run Suricata ──────────────────────────────────────────────
if [ -f "$INPUT" ]; then
    # Single PCAP file
    echo "[*] Processing single PCAP: $(basename $INPUT)"
    sudo suricata \
        -c "$SURICATA_CONF" \
        -r "$INPUT" \
        -l "$OUTPUT_DIR" \
        --runmode=single \
        2>"$LOG_FILE"

elif [ -d "$INPUT" ]; then
    # Directory of PCAPs — process each one
    PCAP_FILES=$(find "$INPUT" -name "*.pcap" -size +100k 2>/dev/null)
    COUNT=$(echo "$PCAP_FILES" | grep -c "." 2>/dev/null || echo 0)

    if [ "$COUNT" -eq 0 ]; then
        echo "[ERROR] No PCAP files found in $INPUT"
        exit 1
    fi

    echo "[*] Found $COUNT PCAP file(s) to process"
    echo ""

    # Create temp combined log dir
    TEMP_DIR=$(mktemp -d)

    for PCAP in $PCAP_FILES; do
        echo "[*] Processing: $(basename $PCAP)"
        TEMP_OUT="${TEMP_DIR}/$(basename $PCAP .pcap)"
        mkdir -p "$TEMP_OUT"

        sudo suricata \
            -c "$SURICATA_CONF" \
            -r "$PCAP" \
            -l "$TEMP_OUT" \
            --runmode=single \
            2>>"$LOG_FILE"

        # Append this PCAP's eve.json to master
        if [ -f "${TEMP_OUT}/eve.json" ]; then
            cat "${TEMP_OUT}/eve.json" >> "$EVE_JSON"
        fi
    done

    rm -rf "$TEMP_DIR"
fi

# ── Results summary ───────────────────────────────────────────
echo ""
echo "============================================"
if [ -f "$EVE_JSON" ] && [ -s "$EVE_JSON" ]; then
    ALERTS=$(grep -c '"event_type":"alert"' "$EVE_JSON" 2>/dev/null || echo 0)
    FLOWS=$(grep -c '"event_type":"flow"' "$EVE_JSON" 2>/dev/null || echo 0)
    DNS=$(grep -c '"event_type":"dns"' "$EVE_JSON" 2>/dev/null || echo 0)
    HTTP=$(grep -c '"event_type":"http"' "$EVE_JSON" 2>/dev/null || echo 0)
    SIZE=$(du -sh "$EVE_JSON" | cut -f1)

    echo " Results"
    echo "  alerts : ${ALERTS}"
    echo "  flows  : ${FLOWS}"
    echo "  dns    : ${DNS}"
    echo "  http   : ${HTTP}"
    echo "  output : ${EVE_JSON} (${SIZE})"
    echo ""

    # Show sample alerts
    echo "-- Sample alerts (first 3) --"
    python3 -c "
import json, sys
alerts = []
with open('${EVE_JSON}') as f:
    for line in f:
        try:
            e = json.loads(line)
            if e.get('event_type') == 'alert':
                alerts.append(e)
                if len(alerts) >= 3:
                    break
        except: pass
for a in alerts:
    ts = a.get('timestamp','')[:19]
    src = a.get('src_ip','?')
    dst = a.get('dest_ip','?')
    port = a.get('dest_port','?')
    sig = a.get('alert',{}).get('signature','?')
    cat = a.get('alert',{}).get('category','?')
    print(f'[{ts}] {src} -> {dst}:{port}')
    print(f'  {sig}')
    print(f'  Category: {cat}')
    print()
" 2>/dev/null || echo "  (install python3 to see sample alerts)"

else
    echo " [ERROR] eve.json was not created"
    echo " Check log: $LOG_FILE"
fi
echo "============================================"
