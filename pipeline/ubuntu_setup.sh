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
echo "[1/7] Updating system packages..."
sudo apt-get update -q
sudo apt-get upgrade -y -q

# ── Core tools ────────────────────────────────────────────────
echo "[2/7] Installing core tools..."
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

# ── Java 17 ───────────────────────────────────────────────────
echo "[3/7] Installing Java 17 (required by CICFlowMeter)..."
sudo apt-get install -y -q openjdk-17-jre-headless
echo "  Java: $(java -version 2>&1 | head -1)"

# ── Python packages ───────────────────────────────────────────
echo "[4/7] Installing Python packages..."
pip3 install pandas --break-system-packages
pip3 install pyyaml --break-system-packages

# ── CICFlowMeter (Python version, patched for Scapy 2.7) ──────
echo "[5/7] Installing CICFlowMeter 0.1.9..."
pip3 install cicflowmeter==0.1.9 --break-system-packages

# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

# Apply patches for Scapy 2.7 compatibility
# CICFlowMeter 0.1.9 has 3 bugs when used with Scapy 2.7+:
# 1. DefaultSession.on_packet_received() removed in Scapy 2.7
# 2. DefaultSession.toPacketList() removed in Scapy 2.7
# 3. AsyncSniffer no longer calls toPacketList() on session
# These patches fix all 3 issues.

CICFLOW_DIR="$HOME/.local/lib/python3.12/site-packages/cicflowmeter"

echo "  Applying Scapy 2.7 compatibility patches..."

# Patch flow_session.py
python3 << 'PATCHEOF'
import os, sys

# Find cicflowmeter install location
for path in [
    os.path.expanduser("~/.local/lib/python3.12/site-packages/cicflowmeter"),
    "/usr/local/lib/python3.12/dist-packages/cicflowmeter",
    "/usr/lib/python3/dist-packages/cicflowmeter",
]:
    flow_session = os.path.join(path, "flow_session.py")
    sniffer = os.path.join(path, "sniffer.py")
    if os.path.exists(flow_session):
        print(f"  Found cicflowmeter at: {path}")

        # Read flow_session.py
        with open(flow_session) as f:
            content = f.read()

        # Add process() method and flush() if not already patched
        if "def process(self, packet):" not in content:
            patch = '''
    def process(self, packet):
        """Scapy 2.7 compatibility: replaces on_packet_received"""
        self.on_packet_received(packet)

    def flush(self):
        """Force write remaining flows to CSV"""
        for flow in self.flows.values():
            self.writer.writerow(flow.get_data())
        self.flows = {}
'''
            # Insert before the last class method
            content = content.replace(
                "\n    def on_packet_received(",
                patch + "\n    def on_packet_received("
            )
            with open(flow_session, 'w') as f:
                f.write(content)
            print("  Patched flow_session.py")
        else:
            print("  flow_session.py already patched")

        # Patch sniffer.py — replace AsyncSniffer with OfflineFlowSniffer
        with open(sniffer) as f:
            sniffer_content = f.read()

        if "OfflineFlowSniffer" not in sniffer_content:
            offline_class = '''
class OfflineFlowSniffer:
    """Reads packets from PCAP file and processes them directly."""
    def __init__(self, input_file, session_class, *args, **kwargs):
        from scapy.utils import PcapReader
        self.input_file = input_file
        self.session = session_class(*args, **kwargs)

    def start(self):
        from scapy.utils import PcapReader
        with PcapReader(self.input_file) as reader:
            for packet in reader:
                self.session.process(packet)
        if hasattr(self.session, 'flush'):
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
            with open(sniffer, 'w') as f:
                f.write(sniffer_content)
            print("  Patched sniffer.py")
        else:
            print("  sniffer.py already patched")

        sys.exit(0)

print("  WARNING: Could not find cicflowmeter install location")
print("  Run manually: pip3 install cicflowmeter==0.1.9 --break-system-packages")
PATCHEOF

echo "  CICFlowMeter installed and patched"

# ── Suricata (offline PCAP analysis) ─────────────────────────
echo "[6/7] Installing Suricata for offline PCAP analysis..."
sudo add-apt-repository -y ppa:oisf/suricata-stable 2>/dev/null || true
sudo apt-get update -q
sudo apt-get install -y -q suricata
sudo suricata-update --suricata-conf /etc/suricata/suricata.yaml \
  --output /var/lib/suricata/rules 2>/dev/null || true

echo "  Suricata: $(suricata --version 2>&1 | head -1)"
echo "  Note: Suricata runs OFFLINE against PCAPs, not live on OPNsense"

# ── Directory setup ───────────────────────────────────────────
echo "[7/7] Creating pipeline directories..."
sudo mkdir -p /opt/pcaps
sudo mkdir -p /opt/cicflow_output
sudo mkdir -p /opt/suricata
sudo chown "$USER":"$USER" /opt/pcaps /opt/cicflow_output /opt/suricata
mkdir -p /home/"$USER"/data
mkdir -p /home/"$USER"/pipeline
mkdir -p /home/"$USER"/traffic-generation-scripts

echo "  /opt/pcaps           — PCAPs synced from OPNsense (rsync hourly)"
echo "  /opt/cicflow_output  — CICFlowMeter CSV output"
echo "  /opt/suricata        — Suricata offline analysis output"
echo "  ~/data               — session_log.csv and features.csv"
echo "  ~/pipeline           — label_flows.py, run_suricata.sh"

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "============================================"
echo " Setup complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Copy pipeline scripts to ~/pipeline/:"
echo "     - label_flows.py"
echo "     - run_suricata.sh"
echo "     - pcap_to_csv.py → ~/pcap_to_csv.py"
echo ""
echo "  2. Copy benign traffic scripts to ~/traffic-generation-scripts/"
echo ""
echo "  3. Configure SSH key auth:"
echo "     ssh-keygen -t ed25519 -f ~/.ssh/opnsense_key"
echo "     # Then add public key to OPNsense authorized_keys"
echo ""
echo "  4. Configure ~/.ssh/config:"
echo "     Host opnsense"
echo "       HostName 192.168.10.1"
echo "       User root"
echo "       IdentityFile ~/.ssh/opnsense_key"
echo "       BindAddress 192.168.10.4"
echo ""
echo "  5. Log out and back in for tshark group membership"
echo ""
