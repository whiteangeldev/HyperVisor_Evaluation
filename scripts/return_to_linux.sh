#!/bin/bash
#
# Script: 09d_return_to_linux.sh
# Purpose: Switch from Xen back to regular Ubuntu kernel
# Description: Updates GRUB to boot into regular Ubuntu kernel instead of Xen
#
# This allows testing ACRN or returning to standard Ubuntu environment
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"

# Create log directory
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/return_to_linux.log"

echo "========================================"
echo "Switch to Regular Ubuntu Kernel"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Log everything
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "📋 Current boot status:"
if [ -d /proc/xen ]; then
    echo "   Currently running: Xen hypervisor"
    xl info 2>/dev/null | grep -E "xen_version|xen_caps" || true
else
    echo "   Currently running: Regular Linux kernel"
fi
echo ""

echo "🔧 Backing up current GRUB configuration..."
if [ -f /etc/default/grub ]; then
    sudo cp /etc/default/grub /etc/default/grub.bak.$(date +%s)
    echo "   ✓ Backup created"
fi
echo ""

echo "🔧 Setting GRUB to boot regular Ubuntu kernel..."

# Option 1: Set GRUB_DEFAULT to 0 (first entry = regular Ubuntu)
sudo sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/' /etc/default/grub

# Option 2: Use grub-set-default to set to entry 0
sudo grub-set-default 0

echo "   ✓ GRUB_DEFAULT set to 0 (regular Ubuntu)"
echo ""

echo "🔧 Updating GRUB..."
sudo update-grub
echo ""

echo "✓ GRUB configuration updated successfully"
echo ""
echo "========================================"
echo "📊 Summary"
echo "========================================"
echo "✓ GRUB configured to boot regular Ubuntu kernel"
echo "✓ Xen will be available but not loaded by default"
echo "✓ Log saved to: $LOG_FILE"
echo ""
echo "⚠️  NEXT STEPS:"
echo "   1. Reboot the system: sudo reboot"
echo "   2. After reboot, verify with: uname -r"
echo "   3. Check VT-x available: grep -q vmx /proc/cpuinfo && echo 'VT-x OK' || echo 'VT-x NOT available'"
echo "   4. Proceed with ACRN installation (scripts 18-24)"
echo ""
echo "🔄 To switch back to Xen later:"
echo "   Run: sudo /home/ubuntu/rt-hypervisor-poc/scripts/09c_set_xen_default.sh"
echo ""

