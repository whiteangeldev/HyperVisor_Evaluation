#!/bin/bash
#
# Script: 09h_fix_xen_scheduler.sh
# Purpose: Fix Xen scheduler by removing 'placeholder' junk from GRUB
# Usage: sudo ./09h_fix_xen_scheduler.sh
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Run as: sudo $0"
    exit 1
fi

echo "=========================================="
echo "Fix Xen RT Scheduler"
echo "=========================================="
echo ""

echo "Problem: 'placeholder' text preventing sched=rtds from working"
echo ""

# Backup GRUB config
cp /boot/grub/grub.cfg /boot/grub/grub.cfg.backup.$(date +%Y%m%d_%H%M%S)
echo "✓ Backed up grub.cfg"
echo ""

# Check current Xen command
echo "Current Xen command line:"
grep "xen_commandline" /sys/hypervisor/properties/ 2>/dev/null || xl dmesg | grep -i "command line" | head -1
echo ""

# Fix the custom Xen entry if it exists
if [ -f /etc/grub.d/06_xen_first ]; then
    echo "Fixing /etc/grub.d/06_xen_first..."
    
    # Remove 'placeholder' from multiboot2 and module2 lines
    sed -i 's/multiboot2 \/xen\.gz placeholder /multiboot2 \/xen.gz /' /etc/grub.d/06_xen_first
    sed -i 's/module2 \/vmlinuz.*placeholder /module2 \/vmlinuz-6.8.0-85-generic /' /etc/grub.d/06_xen_first
    
    echo "✓ Removed 'placeholder' from custom entry"
fi

# Also check and fix the generated GRUB config directly (temporary until regenerated)
echo "Fixing /boot/grub/grub.cfg directly..."
sed -i 's/multiboot2[[:space:]]*\/xen\.gz placeholder /multiboot2 \/xen.gz /' /boot/grub/grub.cfg
sed -i 's/module2[[:space:]]*\/vmlinuz[^[:space:]]*[[:space:]]*placeholder /module2 \/vmlinuz-6.8.0-85-generic /' /boot/grub/grub.cfg

echo "✓ Removed 'placeholder' from grub.cfg"
echo ""

# Verify the fix
echo "Checking fixed Xen entry:"
sed -n '/^menuentry.*Xen.*{/,/^}/p' /boot/grub/grub.cfg | grep -E "multiboot2|module2" | head -3
echo ""

# Now regenerate GRUB properly
echo "Regenerating GRUB configuration..."

# First, fix the Xen config file
XEN_CFG="/etc/default/grub.d/xen.cfg"
if [ -f "$XEN_CFG" ]; then
    echo "Current xen.cfg:"
    cat "$XEN_CFG"
    echo ""
    
    # The issue might be in how update-grub generates entries
    # Check if grub-xen script is adding placeholder
    echo "Note: The 'placeholder' text comes from /etc/grub.d/20_linux_xen"
    echo "      This is a GRUB bug with Xen module handling"
fi

# Update GRUB
echo "Updating GRUB..."
update-grub
echo "✓ GRUB updated"
echo ""

# Verify again
echo "Verifying Xen command line after update:"
sed -n '/^menuentry.*Xen.*{/,/^}/p' /boot/grub/grub.cfg | grep "multiboot2" | head -1
echo ""

if grep -q "multiboot2.*placeholder" /boot/grub/grub.cfg; then
    echo "⚠️  WARNING: 'placeholder' still present after update-grub"
    echo "   This is a GRUB/Xen integration bug"
    echo ""
    echo "   Applying direct fix to grub.cfg..."
    sed -i 's/multiboot2[[:space:]]*\/xen\.gz placeholder /multiboot2 \/xen.gz /' /boot/grub/grub.cfg
    sed -i 's/module2[[:space:]]*\/vmlinuz[^[:space:]]*[[:space:]]*placeholder /module2 \/vmlinuz-6.8.0-85-generic /' /boot/grub/grub.cfg
    echo "   ✓ Direct fix applied"
fi

echo ""
echo "=========================================="
echo "Fix Complete"
echo "=========================================="
echo ""
echo "✓ Removed 'placeholder' junk from Xen command line"
echo "✓ GRUB configuration updated"
echo ""
echo "The Xen command line should now be:"
echo "  /xen.gz sched=rtds dom0_max_vcpus=4 dom0_vcpus_pin=0-3 ..."
echo ""
echo "⚠️  REBOOT REQUIRED"
echo ""
echo "After reboot, verify:"
echo "  sudo xl info | grep xen_scheduler"
echo "  Should show: xen_scheduler : rtds"
echo ""
echo "Reboot now: sudo reboot"
echo ""


