#!/bin/bash
# run_cicflowmeter.sh
# ─────────────────────────────────────────────────────────────
# Runs CICFlowMeter on unprocessed PCAPs in data/raw/
# Outputs per-PCAP CSVs to pipeline/cicflow_output/
# Tracks processed files to avoid duplicates
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(dirname "$0")"
RAW_DIR="${SCRIPT_DIR}/../data/raw"
OUTPUT_DIR="${SCRIPT_DIR}/cicflow_output"
PROCESSED_LOG="${SCRIPT_DIR}/processed_pcaps.txt"
CICFLOW_JAR="/opt/CICFlowMeter/bin/CICFlowMeter"   # Update after install

mkdir -p "$OUTPUT_DIR"
touch "$PROCESSED_LOG"

echo "[$(date)] Scanning for unprocessed PCAPs in ${RAW_DIR}..."

for pcap in "${RAW_DIR}"/*.pcap "${RAW_DIR}"/*.pcapng; do
    [ -f "$pcap" ] || continue

    filename=$(basename "$pcap")

    if grep -qF "$filename" "$PROCESSED_LOG"; then
        echo "  [skip] ${filename} — already processed"
        continue
    fi

    size_kb=$(du -k "$pcap" | cut -f1)
    if [ "$size_kb" -lt 100 ]; then
        echo "  [skip] ${filename} — too small (${size_kb}KB), may be incomplete"
        continue
    fi

    echo "  [processing] ${filename}..."
    # TODO (Milestone 3): confirm CICFlowMeter command syntax after install
    java -jar "$CICFLOW_JAR" "$pcap" "$OUTPUT_DIR"

    if [ $? -eq 0 ]; then
        echo "$filename" >> "$PROCESSED_LOG"
        echo "  [done] ${filename}"
    else
        echo "  [error] CICFlowMeter failed on ${filename}"
    fi
done

echo "[$(date)] CICFlowMeter run complete."
