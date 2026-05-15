#!/bin/bash
# ============================================================
# nmap_evasion_scan.sh
# Attack Type: IDS/Firewall evasion and detection probing
# Tool: Nmap (evasion flags)
# Source: Kali Linux (192.168.20.20) — run as root
# Targets: All VLAN 30 victim hosts
#
# What this does:
#   Runs a series of scans using Nmap's evasion techniques.
#   Each scan uses a different method to avoid detection by
#   firewalls and IDS systems — in our case, Suricata.
#
#   Some techniques WILL be caught by Suricata.
#   Some techniques MAY evade detection.
#   Both outcomes are valuable for the ML dataset.
#
# Why this matters for ML:
#   Standard scans have very consistent traffic signatures.
#   Evasion scans deliberately corrupt or alter those signatures.
#   The ML model needs to learn that attack patterns can be
#   disguised — feature combinations matter more than any
#   single indicator.
#
# The 6 evasion techniques demonstrated:
#   1. Packet fragmentation  — split packets to confuse IDS
#   2. Decoy scanning        — hide real scan among fake sources
#   3. Source port spoofing  — appear to come from trusted ports
#   4. TTL manipulation      — confuse hop-count based detection
#   5. MAC address spoofing  — evade MAC-based controls
#   6. Badsum probing        — fingerprint firewall/IDS behavior
#
# Usage:
#   sudo bash nmap_evasion_scan.sh
#
# After running, log in data/session_log.csv:
#   timestamp_start, timestamp_end, nmap_evasion_scan,
#   192.168.30.10/192.168.30.20/192.168.30.2, malicious,
#   note which techniques triggered alerts vs evaded
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

# Primary target for most evasion tests
PRIMARY_TARGET="192.168.30.20"

# Our real IP
KALI_IP="192.168.20.20"

# Fake decoy IPs — these don't need to exist
# We mix real-looking lab IPs with internet IPs
# to make the decoy traffic more convincing
DECOYS="192.168.20.50,192.168.20.51,10.0.0.1,172.16.0.1,ME,192.168.20.52"
# ME = insert our real IP at this position in the decoy list
# This hides our real IP among the fakes

OUTPUT_DIR="/tmp/evasion_results"
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

echo "============================================"
echo " Nmap IDS/Firewall Evasion Scan"
echo " Started:  $(date '+%Y-%m-%d %H:%M:%S')"
echo " Target:   ${PRIMARY_TARGET} (primary)"
echo "============================================"
echo ""
echo "[!] Record this start time in session_log.csv"
echo ""
echo "Watch Suricata alerts tab during each technique"
echo "to see which ones get caught vs evaded."
echo ""

# ── Technique 1: Packet Fragmentation ────────────────────────
echo "--------------------------------------------"
echo "[1/6] Packet Fragmentation (-f)"
echo "      Splits packets into 8-byte fragments"
echo "      Goal: Split signatures across fragments"
echo "--------------------------------------------"

# -f        → fragment packets into 8-byte chunks
# -f -f     → fragment even smaller (use twice for 16-byte min)
# --mtu 16  → alternatively, set specific MTU for fragmentation
#
# How it works:
#   A normal Nmap SYN packet is ~40 bytes.
#   With -f, it gets split into multiple 8-byte IP fragments.
#   If Suricata doesn't reassemble before matching, the
#   signature (which expects a complete packet) won't fire.
#   Suricata DOES reassemble — so this likely still gets caught.
#   But the fragmented flow data looks different to ML.

nmap -sS -Pn -f \
    -p 21,22,23,80,139,445,3306 \
    -T3 \
    -oN "${OUTPUT_DIR}/fragmented_${TIMESTAMP}.txt" \
    "$PRIMARY_TARGET"

echo "[*] Fragmentation scan complete"
echo ""
sleep 3

# ── Technique 2: Decoy Scanning ──────────────────────────────
echo "--------------------------------------------"
echo "[2/6] Decoy Scanning (-D)"
echo "      Real scan hidden among 5 fake sources"
echo "      Goal: Make source attribution difficult"
echo "--------------------------------------------"

# -D ${DECOYS}
#   → Send scans appearing to originate from multiple IPs
#   → Suricata/firewall sees 6 simultaneous scans
#   → Cannot easily determine which is the real attacker
#   → ME in the decoy list = insert our real IP here
#
# Important: Decoy packets are sent FROM OUR MACHINE but with
# spoofed source IPs. We need raw socket access (root).
# The OS sends real packets with fake headers.
#
# Limitation: Return traffic goes to the decoy IPs, not us.
# This technique works for SYN scans where we don't need
# the response (we infer open/closed from Suricata's view).

nmap -sS -Pn \
    -D "$DECOYS" \
    -p 21,22,23,80,139,445,3306 \
    -T3 \
    -oN "${OUTPUT_DIR}/decoy_${TIMESTAMP}.txt" \
    "$PRIMARY_TARGET"

echo "[*] Decoy scan complete"
echo ""
sleep 3

# ── Technique 3: Source Port Spoofing ────────────────────────
echo "--------------------------------------------"
echo "[3/6] Source Port Spoofing (-g)"
echo "      Scan appears to come from port 53 (DNS)"
echo "      Goal: Bypass rules that trust DNS traffic"
echo "--------------------------------------------"

# -g 53 (or --source-port 53)
#   → Send all packets FROM port 53
#   → Some firewalls allow inbound from port 53 (DNS responses)
#   → A scan appearing to come from "DNS" may bypass rules
#
# Also try port 80 (HTTP) — another commonly trusted source port

echo "  [*] Spoofing source port 53 (DNS)..."
nmap -sS -Pn \
    -g 53 \
    -p 21,22,80,443,3306 \
    -T3 \
    -oN "${OUTPUT_DIR}/srcport53_${TIMESTAMP}.txt" \
    "$PRIMARY_TARGET"

sleep 2

echo "  [*] Spoofing source port 80 (HTTP)..."
nmap -sS -Pn \
    -g 80 \
    -p 21,22,80,443,3306 \
    -T3 \
    -oN "${OUTPUT_DIR}/srcport80_${TIMESTAMP}.txt" \
    "$PRIMARY_TARGET"

echo "[*] Source port spoofing complete"
echo ""
sleep 3

# ── Technique 4: TTL Manipulation ────────────────────────────
echo "--------------------------------------------"
echo "[4/6] TTL Manipulation (--ttl)"
echo "      Sets abnormally low Time-To-Live values"
echo "      Goal: Confuse hop-count based detection"
echo "--------------------------------------------"

# --ttl <value>
#   → Sets the IP TTL field manually
#
# Normal TTL values: Windows=128, Linux=64, Cisco=255
# Abnormal TTL: anything that doesn't match OS defaults
#
# TTL-based evasion works when IDS sits at a different hop
# count than the target. If TTL=5 and IDS is 3 hops away
# but target is 6 hops, IDS sees the packet but target doesn't.
#
# In our lab (same subnet) this won't evade detection,
# but it produces anomalous TTL values in flow data that
# ML can use as a feature. Real-world attackers use this
# against enterprise networks with multi-hop IDS placement.

echo "  [*] Scanning with TTL=1 (expires very fast)..."
nmap -sS -Pn \
    --ttl 1 \
    -p 80,443,22 \
    -T3 \
    -oN "${OUTPUT_DIR}/ttl1_${TIMESTAMP}.txt" \
    "$PRIMARY_TARGET"

sleep 2

echo "  [*] Scanning with TTL=128 (Windows-like)..."
nmap -sS -Pn \
    --ttl 128 \
    -p 80,443,22 \
    -T3 \
    -oN "${OUTPUT_DIR}/ttl128_${TIMESTAMP}.txt" \
    "$PRIMARY_TARGET"

echo "[*] TTL manipulation complete"
echo ""
sleep 3

# ── Technique 5: MAC Address Spoofing ────────────────────────
echo "--------------------------------------------"
echo "[5/6] MAC Address Spoofing (--spoof-mac)"
echo "      Randomizes hardware address per scan"
echo "      Goal: Evade MAC-based access controls"
echo "--------------------------------------------"

# --spoof-mac <value>
#   Accepts several formats:
#   0             → random MAC address each scan
#   Apple         → random Apple vendor MAC
#   00:11:22:33:44:55 → specific MAC
#
# MAC spoofing only works on the local network segment —
# MACs don't traverse routers. In our lab Kali and the
# firewall are on the same VLAN, so this affects what
# the firewall's ARP table sees.
#
# This won't change what Suricata sees (IP-based) but
# creates anomalous ARP behavior visible in raw captures.

echo "  [*] Spoofing random MAC address..."
nmap -sS -Pn \
    --spoof-mac 0 \
    -p 80,22,21 \
    -T3 \
    -oN "${OUTPUT_DIR}/macspoof_random_${TIMESTAMP}.txt" \
    "$PRIMARY_TARGET"

sleep 2

echo "  [*] Spoofing Apple vendor MAC..."
nmap -sS -Pn \
    --spoof-mac Apple \
    -p 80,22,21 \
    -T3 \
    -oN "${OUTPUT_DIR}/macspoof_apple_${TIMESTAMP}.txt" \
    "$PRIMARY_TARGET"

echo "[*] MAC spoofing complete"
echo ""
sleep 3

# ── Technique 6: Badsum Probing ──────────────────────────────
echo "--------------------------------------------"
echo "[6/6] Badsum Probing (--badsum)"
echo "      Sends packets with invalid checksums"
echo "      Goal: Fingerprint IDS/firewall behavior"
echo "--------------------------------------------"

# --badsum
#   → Sends packets with deliberately wrong TCP/UDP checksums
#
# How to interpret results:
#   Open port responds  → firewall/IDS skips checksum validation
#                         (performance optimization — dangerous)
#   No response         → checksum validation is enforced
#                         (packets correctly dropped)
#
# In a well-configured network, ALL ports should show
# "no response" to badsum packets — they should be dropped.
# Any response reveals a security misconfiguration.
#
# This is also a great ML feature — legitimate traffic never
# has invalid checksums. Any flow with badsum = definitely anomalous.

echo "  [*] Sending packets with invalid checksums..."
echo "      (All ports should show 'no response' if IDS is working)"

nmap -sS -Pn \
    --badsum \
    -p 21,22,23,80,139,445,3306 \
    -T3 \
    -oN "${OUTPUT_DIR}/badsum_${TIMESTAMP}.txt" \
    "$PRIMARY_TARGET"

echo "[*] Badsum probing complete"
echo ""

# ── Bonus: Combined evasion ───────────────────────────────────
echo "--------------------------------------------"
echo "[BONUS] Combined Evasion"
echo "        Fragment + Decoy + Source port spoof"
echo "        Most realistic advanced attacker behavior"
echo "--------------------------------------------"

# Real sophisticated attackers combine multiple techniques
# simultaneously. This is what APT (Advanced Persistent Threat)
# reconnaissance looks like.

nmap -sS -Pn \
    -f \
    -D "$DECOYS" \
    -g 53 \
    --data-length 25 \
    -p 21,22,23,80,139,445,3306,8180 \
    -T2 \
    -oN "${OUTPUT_DIR}/combined_evasion_${TIMESTAMP}.txt" \
    "$PRIMARY_TARGET"

# --data-length 25
#   → Appends 25 random bytes to each packet
#   → Makes packet sizes non-standard
#   → Some IDS systems match on packet length patterns

echo "[*] Combined evasion scan complete"

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "============================================"
echo " All evasion scans complete: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Results saved to: ${OUTPUT_DIR}/"
echo "============================================"
echo ""
echo "Now check Suricata Alerts tab and note:"
echo "  - Which techniques generated alerts?"
echo "  - Which techniques evaded detection?"
echo "  - Did alert signatures differ per technique?"
echo ""
echo "This comparison is valuable content for your writeup."
echo ""
echo "[!] Record this end time in session_log.csv"
echo "[!] Label: malicious"
echo "[!] Scenario: nmap_evasion_scan"
echo "[!] Notes: record which techniques fired alerts"
