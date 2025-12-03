#!/bin/bash
#
# Script: 08_configure_grub_iommu.sh
# Purpose: Add intel_iommu=on to GRUB kernel parameters
# Usage: sudo ./08_configure_grub_iommu.sh

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

echo "========================================"
echo "Configure GRUB for IOMMU"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

GRUB_FILE="/etc/default/grub"
BACKUP_FILE="${GRUB_FILE}.backup.$(date +%Y%m%d-%H%M%S)"

# Backup GRUB config
if [ -f "$GRUB_FILE" ]; then
    cp "$GRUB_FILE" "$BACKUP_FILE"
    echo "✓ Backed up GRUB config to: $BACKUP_FILE"
else
    echo "❌ GRUB config not found: $GRUB_FILE"
    exit 1
fi

# Check if intel_iommu=on already exists
if grep -q "intel_iommu=on" "$GRUB_FILE"; then
    echo "✓ intel_iommu=on already present in GRUB"
    echo ""
    echo "Current GRUB_CMDLINE_LINUX:"
    grep "^GRUB_CMDLINE_LINUX=" "$GRUB_FILE" || echo "  (not set)"
    exit 0
fi

# Get current GRUB_CMDLINE_LINUX
CURRENT_CMD=$(grep "^GRUB_CMDLINE_LINUX=" "$GRUB_FILE" | sed 's/^GRUB_CMDLINE_LINUX=//' | tr -d '"' || echo "")

# Add intel_iommu=on
if [ -z "$CURRENT_CMD" ]; then
    NEW_CMD="intel_iommu=on"
else
    NEW_CMD="$CURRENT_CMD intel_iommu=on"
fi

# Update GRUB file
if grep -q "^GRUB_CMDLINE_LINUX=" "$GRUB_FILE"; then
    sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"$NEW_CMD\"|" "$GRUB_FILE"
else
    echo "GRUB_CMDLINE_LINUX=\"$NEW_CMD\"" >> "$GRUB_FILE"
fi

echo "✓ Added intel_iommu=on to GRUB"
echo ""
echo "New GRUB_CMDLINE_LINUX:"
grep "^GRUB_CMDLINE_LINUX=" "$GRUB_FILE"
echo ""

# Update GRUB
echo "Updating GRUB..."
update-grub > /dev/null 2>&1
echo "✓ GRUB updated"
echo ""

echo "========================================"
echo "✓ IOMMU configured in GRUB"
echo "========================================"
echo ""
echo "⚠️  REBOOT REQUIRED for changes to take effect"
echo "After reboot, run: ./01_check_bios_iommu.sh to verify"

