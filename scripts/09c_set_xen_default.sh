#!/bin/bash
#
# Script: 09c_set_xen_default.sh
# Purpose: Set Xen as default boot option in GRUB (for remote servers)
# Usage: sudo ./09c_set_xen_default.sh
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
echo "Set Xen as Default Boot Option"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "⚠️  FOR REMOTE SERVERS - This makes Xen boot automatically"
echo ""

# Backup current GRUB config
if [ -f /etc/default/grub ]; then
    cp /etc/default/grub "/etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✓ Backed up /etc/default/grub"
fi

# Check if Xen entries exist in GRUB
if ! grep -q "menuentry.*Xen" /boot/grub/grub.cfg; then
    echo "❌ ERROR: No Xen entries found in GRUB"
    echo "Run: sudo ./09b_fix_xen_grub.sh first"
    exit 1
fi

echo "✓ Xen entries found in GRUB"
echo ""

# Find the Xen entry number
echo "Finding Xen boot entry..."
XEN_ENTRY=$(grep -n "menuentry.*Xen" /boot/grub/grub.cfg | head -1 | cut -d: -f1)

# Calculate submenu structure
# GRUB counts: main menu entries, then submenu entries
# Usually Xen is entry 0 or in "Advanced options" submenu

# Get all menuentry lines
TOTAL_MAIN=$(grep "^menuentry" /boot/grub/grub.cfg | head -20 | nl -v 0)
echo "Main menu entries:"
echo "$TOTAL_MAIN" | head -10
echo ""

# Find if Xen is in main menu or submenu
XEN_MAIN=$(grep "^menuentry" /boot/grub/grub.cfg | grep -n "Xen" | head -1 | cut -d: -f1)

if [ -n "$XEN_MAIN" ]; then
    # Xen is in main menu
    XEN_INDEX=$((XEN_MAIN - 1))  # 0-indexed
    GRUB_DEFAULT_VALUE="$XEN_INDEX"
    echo "✓ Xen found in main menu at position $XEN_INDEX"
else
    # Xen is in submenu (Advanced options)
    echo "Xen appears to be in Advanced options submenu"
    
    # Find Advanced options position
    ADV_POS=$(grep "^menuentry" /boot/grub/grub.cfg | grep -n "Advanced" | head -1 | cut -d: -f1)
    ADV_POS=$((ADV_POS - 1))  # 0-indexed
    
    # Find Xen position within submenu
    XEN_SUB=$(grep "menuentry.*Xen" /boot/grub/grub.cfg | head -1)
    
    # Format: 1>0 means "Advanced menu" (1) > "First entry" (0)
    GRUB_DEFAULT_VALUE="${ADV_POS}>0"
    echo "✓ Xen found in submenu: Advanced options > Xen entry"
    echo "  Using GRUB_DEFAULT=${GRUB_DEFAULT_VALUE}"
fi

echo ""
echo "Configuring GRUB to boot Xen automatically..."

# Update /etc/default/grub
if grep -q "^GRUB_DEFAULT=" /etc/default/grub; then
    # Update existing GRUB_DEFAULT
    sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=\"${GRUB_DEFAULT_VALUE}\"/" /etc/default/grub
else
    # Add GRUB_DEFAULT
    echo "GRUB_DEFAULT=\"${GRUB_DEFAULT_VALUE}\"" >> /etc/default/grub
fi

# Set timeout to ensure it waits (fallback safety)
if grep -q "^GRUB_TIMEOUT=" /etc/default/grub; then
    sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/" /etc/default/grub
else
    echo "GRUB_TIMEOUT=5" >> /etc/default/grub
fi

# Disable hidden timeout
sed -i 's/^GRUB_TIMEOUT_STYLE=hidden/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub

echo "✓ GRUB configuration updated"
echo ""

echo "Current GRUB configuration:"
grep "^GRUB_DEFAULT" /etc/default/grub
grep "^GRUB_TIMEOUT" /etc/default/grub
echo ""

# Update GRUB
echo "Updating GRUB..."
update-grub
echo "✓ GRUB updated"
echo ""

echo "========================================"
echo "Xen Set as Default Boot Option"
echo "========================================"
echo ""
echo "✓ GRUB_DEFAULT set to: ${GRUB_DEFAULT_VALUE}"
echo "✓ Xen will boot automatically on next reboot"
echo ""
echo "⚠️  IMPORTANT: Test reboot safety"
echo ""
echo "SAFE REBOOT (Recommended for remote servers):"
echo "  1. Reboot: sudo reboot"
echo "  2. Wait 2-3 minutes for boot"
echo "  3. SSH back in: ssh ubuntu@your-server"
echo "  4. Verify Xen: sudo xl info"
echo ""
echo "If SSH doesn't come back up:"
echo "  - You may need physical/IPMI access to select regular kernel"
echo "  - Or wait for automatic fallback (if configured)"
echo ""
echo "To revert to regular kernel boot:"
echo "  1. SSH in (before rebooting)"
echo "  2. Edit: sudo nano /etc/default/grub"
echo "  3. Set: GRUB_DEFAULT=0"
echo "  4. Update: sudo update-grub"
echo ""

