#!/bin/bash
# sync_pcaps.sh
# ─────────────────────────────────────────────────────────────
# Rsyncs new PCAP files from OPNsense to data/raw/
# Run on Ubuntu Server VM — manually or via cron
#
# Cron example (every 60 minutes):
#   0 * * * * /path/to/ai-traffic-classifier/pipeline/sync_pcaps.sh
# ─────────────────────────────────────────────────────────────

# TODO (Milestone 1): fill in OPNsense SSH user and confirm remote path
OPNSENSE_USER="root"
OPNSENSE_IP="192.168.10.1"
REMOTE_PATH="/var/capturedata/"
LOCAL_PATH="$(dirname "$0")/../data/raw/"
SURICATA_REMOTE="/var/log/suricata/eve.json"
SURICATA_LOCAL="$(dirname "$0")/../data/suricata/"

echo "[$(date)] Starting PCAP sync from OPNsense..."

mkdir -p "$LOCAL_PATH"
mkdir -p "$SURICATA_LOCAL"

rsync -av --ignore-existing \
    "${OPNSENSE_USER}@${OPNSENSE_IP}:${REMOTE_PATH}" \
    "$LOCAL_PATH"

rsync -av \
    "${OPNSENSE_USER}@${OPNSENSE_IP}:${SURICATA_REMOTE}" \
    "$SURICATA_LOCAL"

echo "[$(date)] Sync complete."
