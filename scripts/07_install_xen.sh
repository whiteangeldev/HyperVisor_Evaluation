#!/bin/bash
#
# Script: 07_install_xen.sh
# Purpose: Install Xen hypervisor packages
# Usage: sudo ./07_install_xen.sh
# ⚠️  REQUIRES ROOT PRIVILEGES
#

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ ERROR: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
INSTALL_LOG="$LOG_DIR/xen_install.log"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "Xen Hypervisor Installation"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

{
    echo "========================================"
    echo "XEN INSTALLATION LOG"
    echo "========================================"
    echo "Installation Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo ""
    
    echo "Step 1: Update package lists..."
    apt update
    echo "✓ Package lists updated"
    echo ""
    
    echo "Step 2: Install Xen hypervisor and tools..."
    # Install Xen packages
    DEBIAN_FRONTEND=noninteractive apt install -y \
        xen-hypervisor-amd64 \
        xen-tools \
        xen-utils-common \
        bridge-utils \
        libvirt-daemon-system \
        virtinst
    
    echo "✓ Xen packages installed"
    echo ""
    
    echo "Step 3: Verify installation..."
    dpkg -l | grep xen
    echo ""
    
    echo "Step 4: Check Xen configuration directory..."
    if [ -d /etc/xen ]; then
        echo "✓ /etc/xen directory exists"
        ls -la /etc/xen
    else
        echo "⚠ /etc/xen directory not found"
    fi
    echo ""
    
    echo "Step 5: Check Xen binary..."
    if [ -f /usr/sbin/xl ]; then
        echo "✓ Xen xl tool found"
        /usr/sbin/xl --version || echo "Xen not yet running (normal before reboot)"
    else
        echo "⚠ Xen xl tool not found"
    fi
    echo ""
    
    echo "========================================"
    echo "Installation Complete"
    echo "========================================"
    echo "✓ Xen hypervisor installed successfully"
    echo ""
    echo "Next steps:"
    echo "1. Configure Xen RT scheduler: ./08_configure_xen_rt.sh"
    echo "2. Apply configuration: sudo ./09_apply_xen_config.sh"
    echo "3. Reboot into Xen: sudo reboot"
    echo ""
    
} 2>&1 | tee "$INSTALL_LOG"

echo "✓ Installation log saved to: $INSTALL_LOG"
echo ""

