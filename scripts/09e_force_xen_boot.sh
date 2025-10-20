#!/bin/bash
#
# Script: 09e_force_xen_boot.sh
# Purpose: Force Xen to boot using multiple methods
# Usage: sudo ./09e_force_xen_boot.sh
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
echo "Force Xen Boot Configuration"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Find Xen entry number
echo "Finding Xen entry in GRUB..."
XEN_ENTRY_NUM=$(grep -n "^menuentry.*Xen" /boot/grub/grub.cfg | head -1 | cut -d: -f1)

if [ -z "$XEN_ENTRY_NUM" ]; then
    echo "❌ ERROR: No Xen entry found in GRUB"
    echo "Run: sudo ./09b_fix_xen_grub.sh first"
    exit 1
fi

# Calculate actual index (grep gives line number, we need menu position)
# Count how many menuentries come before this one
XEN_INDEX=0
LINE_NUM=0
while IFS= read -r line; do
    LINE_NUM=$((LINE_NUM + 1))
    if [ $LINE_NUM -ge $XEN_ENTRY_NUM ]; then
        break
    fi
    if echo "$line" | grep -q "^menuentry"; then
        XEN_INDEX=$((XEN_INDEX + 1))
    fi
done < /boot/grub/grub.cfg

echo "✓ Xen found at GRUB index: $XEN_INDEX"
echo ""

# Show current and Xen entries
echo "Current menu structure:"
grep "^menuentry" /boot/grub/grub.cfg | nl -v 0 | head -5
echo ""

# Method 1: Set in /etc/default/grub
echo "Method 1: Updating /etc/default/grub..."
if grep -q "^GRUB_DEFAULT=" /etc/default/grub; then
    sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=\"$XEN_INDEX\"/" /etc/default/grub
else
    echo "GRUB_DEFAULT=\"$XEN_INDEX\"" >> /etc/default/grub
fi

# Also set GRUB_SAVEDEFAULT to ensure it persists
if grep -q "^GRUB_SAVEDEFAULT=" /etc/default/grub; then
    sed -i "s/^GRUB_SAVEDEFAULT=.*/GRUB_SAVEDEFAULT=false/" /etc/default/grub
else
    echo "GRUB_SAVEDEFAULT=false" >> /etc/default/grub
fi

echo "✓ Set GRUB_DEFAULT=$XEN_INDEX in /etc/default/grub"
echo ""

# Update GRUB
echo "Updating GRUB..."
update-grub
echo "✓ GRUB updated"
echo ""

# Method 2: Use grub-set-default (more reliable)
echo "Method 2: Using grub-set-default..."
grub-set-default "$XEN_INDEX"
echo "✓ Set default to entry $XEN_INDEX using grub-set-default"
echo ""

# Method 3: Verify grubenv
echo "Method 3: Verifying GRUB environment..."
if [ -f /boot/grub/grubenv ]; then
    echo "Current grubenv:"
    grub-editenv list
    echo ""
else
    echo "Creating grubenv..."
    grub-editenv /boot/grub/grubenv create
    grub-set-default "$XEN_INDEX"
fi

# Final verification
echo "Final configuration:"
echo "  /etc/default/grub GRUB_DEFAULT: $(grep '^GRUB_DEFAULT=' /etc/default/grub)"
echo "  grubenv saved_entry: $(grub-editenv list | grep saved_entry || echo 'none')"
echo ""

echo "========================================"
echo "Xen Boot Forced"
echo "========================================"
echo ""
echo "✓ Multiple methods applied to ensure Xen boots"
echo "✓ GRUB_DEFAULT set to: $XEN_INDEX"
echo "✓ grub-set-default executed"
echo "✓ GRUB updated"
echo ""
echo "Xen entry that will boot:"
grep "^menuentry" /boot/grub/grub.cfg | sed -n "$((XEN_INDEX + 1))p"
echo ""
echo "⚠️  REBOOT NOW"
echo ""
echo "After reboot:"
echo "  1. Wait 2-3 minutes"
echo "  2. SSH back: ssh ubuntu@your-server"
echo "  3. Verify: sudo xl info"
echo "  4. Check: sudo xl info | grep xen_scheduler"
echo ""


