#!/bin/bash
# ubuntu_setup.sh
# ─────────────────────────────────────────────────────────────
# Run this once on the Ubuntu Server VM to install everything
# needed for the pipeline.
#
# Usage:
#   chmod +x ubuntu_setup.sh
#   ./ubuntu_setup.sh
# ─────────────────────────────────────────────────────────────

set -e  # Exit immediately on any error

echo "============================================"
echo " ai-traffic-classifier — Ubuntu Server Setup"
echo "============================================"
echo ""

# ── System update ─────────────────────────────────────────────
echo "[1/6] Updating system packages..."
sudo apt-get update -q
sudo apt-get upgrade -y -q

# ── Core tools ────────────────────────────────────────────────
echo "[2/6] Installing core tools (tmux, tshark, rsync, git)..."
sudo apt-get install -y -q \
    tmux \
    tshark \
    rsync \
    git \
    curl \
    wget \
    unzip

# Allow non-root users to capture packets with tshark
sudo usermod -aG wireshark "$USER" || true
echo "  Note: log out and back in for tshark group permissions to take effect"

# ── Python 3 ──────────────────────────────────────────────────
echo "[3/6] Installing Python 3 and pip..."
sudo apt-get install -y -q \
    python3 \
    python3-pip \
    python3-venv

echo "  Python version: $(python3 --version)"

# Create project virtual environment
echo "  Creating virtual environment at ~/venv/traffic-classifier..."
python3 -m venv ~/venv/traffic-classifier
source ~/venv/traffic-classifier/bin/activate

# Install Python pipeline dependencies
pip install --quiet --upgrade pip
pip install --quiet \
    pandas \
    pyyaml \
    tqdm

echo "  Python environment ready."
deactivate

# ── Java 17 (required for CICFlowMeter) ──────────────────────
echo "[4/6] Installing Java 17..."
sudo apt-get install -y -q openjdk-17-jre-headless
echo "  Java version: $(java -version 2>&1 | head -1)"

# ── CICFlowMeter ──────────────────────────────────────────────
echo "[5/6] Installing CICFlowMeter..."
sudo mkdir -p /opt/CICFlowMeter

# Download CICFlowMeter (headless version for Ubuntu Server)
cd /tmp
wget -q "https://github.com/ahlashkari/CICFlowMeter/releases/download/v4.0/CICFlowMeter-4.0.zip" \
    -O CICFlowMeter.zip || {
    echo "  [warning] Could not auto-download CICFlowMeter."
    echo "  Manual install: download from https://github.com/ahlashkari/CICFlowMeter"
    echo "  and extract to /opt/CICFlowMeter/"
}

if [ -f "/tmp/CICFlowMeter.zip" ]; then
    sudo unzip -q /tmp/CICFlowMeter.zip -d /opt/CICFlowMeter/
    sudo chmod +x /opt/CICFlowMeter/bin/cfm
    echo "  CICFlowMeter installed at /opt/CICFlowMeter/"
fi

# ── Directory setup ───────────────────────────────────────────
echo "[6/6] Creating pipeline directories..."
sudo mkdir -p /opt/pcaps
sudo mkdir -p /opt/suricata
sudo chown "$USER":"$USER" /opt/pcaps /opt/suricata
echo "  /opt/pcaps     — PCAP staging directory (rsync target from OPNsense)"
echo "  /opt/suricata  — Suricata alert log staging"

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "============================================"
echo " Setup complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Clone the project repo:"
echo "     git clone https://github.com/tyceerickson/ai-traffic-classifier.git"
echo ""
echo "  2. Set up SSH key auth from OPNsense to this server"
echo "     (so OPNsense can rsync PCAPs here automatically)"
echo ""
echo "  3. Activate the Python environment when running pipeline scripts:"
echo "     source ~/venv/traffic-classifier/bin/activate"
echo ""
echo "  4. Log out and back in for tshark group membership to take effect"
echo ""
