#!/bin/bash
#
# Script: 09b_fix_xen_grub.sh
# Purpose: Fix GRUB to properly boot Xen hypervisor
# Usage: sudo ./09b_fix_xen_grub.sh
# ⚠️  REQUIRES ROOT PRIVILEGES
#

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ ERROR: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

echo "========================================"
echo "Fix Xen GRUB Boot Configuration"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if Xen is installed
if [ ! -f /boot/xen-4.17-amd64.gz ]; then
    echo "❌ ERROR: Xen hypervisor not found in /boot/"
    echo "Run: sudo ./scripts/07_install_xen.sh first"
    exit 1
fi

echo "✓ Xen hypervisor found: /boot/xen-4.17-amd64.gz"
echo ""

# Check if grub-xen-host is installed
if ! dpkg -l | grep -q "^ii  grub-xen-host"; then
    echo "Installing grub-xen-host..."
    apt update
    apt install -y grub-xen-host
else
    echo "✓ grub-xen-host is installed"
fi
echo ""

# Check /etc/default/grub.d/xen.cfg exists
if [ -f /etc/default/grub.d/xen.cfg ]; then
    echo "✓ Xen GRUB config found: /etc/default/grub.d/xen.cfg"
    echo "Contents:"
    cat /etc/default/grub.d/xen.cfg
    echo ""
else
    echo "⚠ Xen GRUB config not found, will be created during update"
    echo ""
fi

# Create symbolic link if needed
if [ ! -L /boot/xen.gz ]; then
    echo "Creating symbolic link /boot/xen.gz -> xen-4.17-amd64.gz"
    ln -sf xen-4.17-amd64.gz /boot/xen.gz
    echo "✓ Symbolic link created"
else
    echo "✓ Symbolic link /boot/xen.gz already exists"
fi
echo ""

# Force update GRUB
echo "Updating GRUB configuration..."
echo "This will regenerate /boot/grub/grub.cfg with Xen entries"
echo ""

update-grub 2>&1 | tee /tmp/update-grub-output.log

echo ""
echo "Checking for Xen entries in GRUB..."
if grep -q "menuentry.*Xen" /boot/grub/grub.cfg; then
    echo "✓ Xen boot entries found in GRUB!"
    echo ""
    echo "Xen entries:"
    grep "menuentry.*Xen" /boot/grub/grub.cfg | head -3
    echo ""
else
    echo "❌ WARNING: No Xen entries found in GRUB"
    echo ""
    echo "Checking update-grub output:"
    grep -i xen /tmp/update-grub-output.log || echo "No Xen messages in update-grub output"
    echo ""
    echo "Manual GRUB entry may be needed"
fi

echo ""
echo "========================================"
echo "GRUB Configuration Updated"
echo "========================================"
echo ""
echo "⚠️  REBOOT REQUIRED"
echo ""
echo "After reboot:"
echo "1. At GRUB menu, look for entries starting with 'Xen'"
echo "2. Select the Xen entry (usually at the top)"
echo "3. After boot, verify: sudo xl info"
echo ""
echo "If you don't see GRUB menu:"
echo "- Hold SHIFT during boot to show GRUB menu"
echo "- Or edit /etc/default/grub: set GRUB_TIMEOUT=5"
echo ""

