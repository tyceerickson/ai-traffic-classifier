#!/bin/bash
# ubuntu_setup.sh
# ─────────────────────────────────────────────────────────────
# Run this once on the Ubuntu Server VM to install everything
# needed for the ai-traffic-classifier pipeline.
#
# Ubuntu Server 24.04 LTS (ARM64/aarch64)
# Run as: bash ubuntu_setup.sh
# ─────────────────────────────────────────────────────────────

set -e

echo "============================================"
echo " ai-traffic-classifier — Ubuntu Server Setup"
echo " Ubuntu 24.04 LTS (ARM64)"
echo "============================================"
echo ""

# ── System update ─────────────────────────────────────────────
echo "[1/6] Updating system packages..."
sudo apt-get update -q
sudo apt-get upgrade -y -q

# ── Core tools ────────────────────────────────────────────────
echo "[2/6] Installing core tools..."
sudo apt-get install -y -q \
  tmux \
  tshark \
  rsync \
  git \
  curl \
  wget \
  unzip \
  python3 \
  python3-pip \
  dnsutils \
  sshpass \
  iputils-ping

# Allow non-root tshark
sudo usermod -aG wireshark "$USER" || true
echo "  Note: log out and back in for tshark group permissions"

# ── Python packages ───────────────────────────────────────────
echo "[3/6] Installing Python packages..."
pip3 install pandas --break-system-packages
pip3 install pyyaml --break-system-packages

# ── CICFlowMeter (Python pip version, patched for Scapy 2.7) ──
echo "[4/6] Installing CICFlowMeter 0.1.9 (Python version)..."
# NOTE: We use the Python pip version of CICFlowMeter, NOT the Java version.
# Java is NOT required. The Python version is installed via pip and patched
# to fix 3 compatibility bugs with Scapy 2.7+.
pip3 install cicflowmeter==0.1.9 --break-system-packages

# Add ~/.local/bin to PATH so 'cicflowmeter' command works
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

# Apply patches for Scapy 2.7 compatibility
# CICFlowMeter 0.1.9 has 3 bugs when used with Scapy 2.7+:
#   Bug 1: DefaultSession.on_packet_received() removed in Scapy 2.7
#   Bug 2: DefaultSession.toPacketList() removed in Scapy 2.7
#   Bug 3: AsyncSniffer no longer calls toPacketList() on session
# These patches add a process() override and OfflineFlowSniffer class to fix all 3.

echo "  Applying Scapy 2.7 compatibility patches to CICFlowMeter..."

python3 << 'PATCHEOF'
import os, sys

for base in [
    os.path.expanduser("~/.local/lib/python3.12/site-packages/cicflowmeter"),
    "/usr/local/lib/python3.12/dist-packages/cicflowmeter",
    "/usr/lib/python3/dist-packages/cicflowmeter",
]:
    flow_session_path = os.path.join(base, "flow_session.py")
    sniffer_path = os.path.join(base, "sniffer.py")

    if not os.path.exists(flow_session_path):
        continue

    print(f"  Found cicflowmeter at: {base}")

    # Patch 1 & 2: flow_session.py — add process() and flush()
    with open(flow_session_path) as f:
        content = f.read()

    if "def process(self, packet):" not in content:
        patch = '''
    def process(self, packet):
        """Scapy 2.7 compatibility: process() replaces on_packet_received()"""
        self.on_packet_received(packet)

    def flush(self):
        """Force write any remaining open flows to CSV output."""
        for flow in self.flows.values():
            self.writer.writerow(flow.get_data())
        self.flows = {}
'''
        content = content.replace(
            "\n    def on_packet_received(",
            patch + "\n    def on_packet_received("
        )
        with open(flow_session_path, 'w') as f:
            f.write(content)
        print("  Patched flow_session.py (added process() and flush())")
    else:
        print("  flow_session.py already patched")

    # Patch 3: sniffer.py — replace AsyncSniffer with OfflineFlowSniffer
    with open(sniffer_path) as f:
        sniffer_content = f.read()

    if "OfflineFlowSniffer" not in sniffer_content:
        offline_class = '''
class OfflineFlowSniffer:
    """
    Reads packets directly from a PCAP file using PcapReader.
    Replaces AsyncSniffer for offline file processing to fix
    Scapy 2.7 compatibility where AsyncSniffer no longer calls
    toPacketList() on the session after reading.
    """
    def __init__(self, input_file, session_class, *args, **kwargs):
        self.input_file = input_file
        self.session = session_class(*args, **kwargs)

    def start(self):
        from scapy.utils import PcapReader
        with PcapReader(self.input_file) as reader:
            for packet in reader:
                self.session.process(packet)
        if hasattr(self.session, "flush"):
            self.session.flush()

    def join(self):
        pass

    def stop(self):
        pass

'''
        sniffer_content = sniffer_content.replace(
            "\ndef create_sniffer(",
            offline_class + "\ndef create_sniffer("
        )
        with open(sniffer_path, 'w') as f:
            f.write(sniffer_content)
        print("  Patched sniffer.py (added OfflineFlowSniffer class)")
    else:
        print("  sniffer.py already patched")

    sys.exit(0)

print("  WARNING: Could not find cicflowmeter install location")
PATCHEOF

echo "  CICFlowMeter installed and patched"
echo "  Verify: cicflowmeter --help"

# ── Suricata (offline PCAP analysis) ─────────────────────────
echo "[5/6] Installing Suricata for offline PCAP analysis..."
# NOTE: Suricata runs OFFLINE against PCAP files on this Ubuntu Server.
# It does NOT run live on OPNsense (unstable on OPNsense 26.1 + Suricata 8.0.3
# on VLAN interfaces in PCAP mode on FreeBSD).
sudo add-apt-repository -y ppa:oisf/suricata-stable 2>/dev/null || true
sudo apt-get update -q
sudo apt-get install -y -q suricata

# Download ET Open rules
sudo suricata-update --suricata-conf /etc/suricata/suricata.yaml \
  --output /var/lib/suricata/rules 2>/dev/null || \
  echo "  Note: run 'sudo suricata-update' manually if this fails"

echo "  Suricata version: $(suricata --version 2>&1 | head -1)"
echo "  Rules: $(wc -l < /var/lib/suricata/rules/suricata.rules 2>/dev/null || echo 'pending suricata-update') lines"

# ── Directory setup ───────────────────────────────────────────
echo "[6/6] Creating pipeline directories..."
sudo mkdir -p /opt/pcaps
sudo mkdir -p /opt/cicflow_output
sudo mkdir -p /opt/suricata
sudo chown "$USER":"$USER" /opt/pcaps /opt/cicflow_output /opt/suricata

mkdir -p /home/"$USER"/data
mkdir -p /home/"$USER"/pipeline
mkdir -p /home/"$USER"/traffic-generation-scripts

echo "  /opt/pcaps              — PCAPs synced from OPNsense (rsync hourly)"
echo "  /opt/cicflow_output     — CICFlowMeter CSV output"
echo "  /opt/suricata           — Suricata offline analysis output (eve.json)"
echo "  ~/data                  — session_log.csv + features.csv"
echo "  ~/pipeline              — label_flows.py + run_suricata.sh"
echo "  ~/traffic-generation-scripts  — benign traffic scripts"

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "============================================"
echo " Setup complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Copy pipeline scripts to ~/pipeline/:"
echo "     - label_flows.py    (from pipeline/ in repo)"
echo "     - run_suricata.sh   (from pipeline/ in repo)"
echo "     - pcap_to_csv.py    → ~/pcap_to_csv.py"
echo ""
echo "  2. Copy benign scripts to ~/traffic-generation-scripts/:"
echo "     scp <files> terickson@<ubuntu-ip>:~/traffic-generation-scripts/"
echo "     chmod +x ~/traffic-generation-scripts/*.sh"
echo ""
echo "  3. Configure SSH key auth to OPNsense:"
echo "     ssh-keygen -t ed25519 -f ~/.ssh/opnsense_key -N ''"
echo "     # Add ~/.ssh/opnsense_key.pub to OPNsense authorized_keys"
echo ""
echo "  4. Add to ~/.ssh/config:"
echo "     Host opnsense"
echo "       HostName 192.168.10.1"
echo "       User root"
echo "       IdentityFile ~/.ssh/opnsense_key"
echo "       BindAddress 192.168.10.4"
echo ""
echo "  5. Log out and back in for tshark group membership"
echo "  6. Run: source ~/.bashrc  (to activate PATH update)"
echo ""
