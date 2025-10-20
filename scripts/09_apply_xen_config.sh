#!/bin/bash
#
# Script: 09_apply_xen_config.sh
# Purpose: Apply Xen RT configuration to system
# Usage: sudo ./09_apply_xen_config.sh
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
CONFIG_DIR="$PROJECT_ROOT/configs"
XEN_CONFIG="$CONFIG_DIR/xen_rt.cfg"
XEN_GRUB_CFG="/etc/default/grub.d/xen.cfg"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "========================================"
echo "Apply Xen RT Configuration"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if config exists
if [ ! -f "$XEN_CONFIG" ]; then
    echo "❌ ERROR: Xen configuration not found"
    echo "Expected: $XEN_CONFIG"
    echo "Run: ./08_configure_xen_rt.sh first"
    exit 1
fi

# Extract parameters from config
SCHED=$(grep "^sched=" "$XEN_CONFIG" | cut -d= -f2)
DOM0_VCPUS=$(grep "^dom0_max_vcpus=" "$XEN_CONFIG" | cut -d= -f2)
DOM0_PIN=$(grep "^dom0_vcpus_pin=" "$XEN_CONFIG" | cut -d= -f2)
DOM0_MEM=$(grep "^dom0_mem=" "$XEN_CONFIG" | cut -d= -f2)

echo "Configuration to apply:"
echo "  Scheduler: $SCHED"
echo "  Dom0 VCPUs: $DOM0_VCPUS"
echo "  Dom0 CPU Pin: $DOM0_PIN"
echo "  Dom0 Memory: $DOM0_MEM"
echo ""

# Create Xen-specific GRUB configuration
mkdir -p /etc/default/grub.d

echo "Creating Xen GRUB configuration..."
cat > "$XEN_GRUB_CFG" << EOF
# Xen Hypervisor Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

# Xen hypervisor command line options
# Note: dom0_vcpus_pin needs the actual CPU list
GRUB_CMDLINE_XEN_DEFAULT="sched=${SCHED} dom0_max_vcpus=${DOM0_VCPUS} dom0_vcpus_pin=${DOM0_PIN} dom0_mem=${DOM0_MEM}"

# Set Xen as default boot option
# GRUB_DEFAULT="Xen"
EOF

echo "✓ Xen GRUB configuration created: $XEN_GRUB_CFG"
echo ""

# Copy additional configuration files
if [ -d /etc/xen ]; then
    echo "Copying Xen configuration to /etc/xen/..."
    cp "$XEN_CONFIG" "/etc/xen/xen_rt.cfg.${TIMESTAMP}"
    echo "✓ Configuration copied"
fi

# Update GRUB
echo "Updating GRUB..."
if command -v update-grub &> /dev/null; then
    update-grub
    echo "✓ GRUB updated"
elif command -v grub-mkconfig &> /dev/null; then
    grub-mkconfig -o /boot/grub/grub.cfg
    echo "✓ GRUB updated"
else
    echo "❌ ERROR: Cannot update GRUB"
    exit 1
fi

echo ""
echo "========================================"
echo "Xen Configuration Applied"
echo "========================================"
echo "✓ Xen RT scheduler configured"
echo "✓ GRUB updated with Xen parameters"
echo ""
echo "⚠️  REBOOT REQUIRED"
echo ""
echo "After reboot:"
echo "1. Select 'Xen Hypervisor' from GRUB menu"
echo "2. Verify Xen is running: xl info"
echo "3. Check scheduler: xl sched-rtds -s"
echo "4. Verify Dom0 CPU pinning: xl vcpu-list 0"
echo ""

