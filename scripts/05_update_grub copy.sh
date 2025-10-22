#!/bin/bash
#
# Script: 05_update_grub.sh
# Purpose: Apply generated GRUB parameters to system
# Usage: sudo ./05_update_grub.sh
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
GRUB_CONFIG_FILE="$CONFIG_DIR/grub_cmdline.txt"
GRUB_DEFAULT="/etc/default/grub"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "========================================"
echo "Update GRUB Configuration"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if generated config exists
if [ ! -f "$GRUB_CONFIG_FILE" ]; then
    echo "❌ ERROR: GRUB configuration file not found"
    echo "Expected: $GRUB_CONFIG_FILE"
    echo "Run: ./04_generate_grub_config.sh first"
    exit 1
fi

# Extract parameters from generated config
GRUB_PARAMS=$(grep -v "^#" "$GRUB_CONFIG_FILE" | grep -v "^$" | head -1)

if [ -z "$GRUB_PARAMS" ]; then
    echo "❌ ERROR: No parameters found in $GRUB_CONFIG_FILE"
    exit 1
fi

echo "Parameters to apply:"
echo "$GRUB_PARAMS"
echo ""

# Backup current GRUB config
echo "Creating backup of $GRUB_DEFAULT..."
cp "$GRUB_DEFAULT" "${GRUB_DEFAULT}.backup_${TIMESTAMP}"
echo "✓ Backup created: ${GRUB_DEFAULT}.backup_${TIMESTAMP}"
echo ""

# Update GRUB_CMDLINE_LINUX_DEFAULT
echo "Updating GRUB configuration..."

# Create temporary file
TMP_GRUB=$(mktemp)

# Check if GRUB_CMDLINE_LINUX_DEFAULT exists
if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_DEFAULT"; then
    # Update existing line
    sed "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_PARAMS\"|" "$GRUB_DEFAULT" > "$TMP_GRUB"
else
    # Add new line
    echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_PARAMS\"" >> "$TMP_GRUB"
    cat "$GRUB_DEFAULT" >> "$TMP_GRUB"
fi

# Verify the change
if grep -q "$GRUB_PARAMS" "$TMP_GRUB"; then
    mv "$TMP_GRUB" "$GRUB_DEFAULT"
    echo "✓ GRUB configuration updated"
else
    echo "❌ ERROR: Failed to update GRUB configuration"
    rm "$TMP_GRUB"
    exit 1
fi

# Show the updated configuration
echo ""
echo "Updated GRUB_CMDLINE_LINUX_DEFAULT:"
grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_DEFAULT"
echo ""

# Ensure GRUB menu is visible for hypervisor selection
echo "Configuring GRUB menu visibility..."

# Update GRUB_TIMEOUT_STYLE to show menu
if grep -q "^GRUB_TIMEOUT_STYLE=" "$GRUB_DEFAULT"; then
    sed -i "s/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/" "$GRUB_DEFAULT"
else
    echo "GRUB_TIMEOUT_STYLE=menu" >> "$GRUB_DEFAULT"
fi

# Update GRUB_TIMEOUT to 10 seconds
if grep -q "^GRUB_TIMEOUT=" "$GRUB_DEFAULT"; then
    sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/" "$GRUB_DEFAULT"
else
    echo "GRUB_TIMEOUT=10" >> "$GRUB_DEFAULT"
fi

echo "✓ GRUB menu visibility configured (10 second timeout)"
echo ""

# Update GRUB
echo "Running update-grub..."
if command -v update-grub &> /dev/null; then
    update-grub
    echo "✓ GRUB updated successfully"
elif command -v grub-mkconfig &> /dev/null; then
    grub-mkconfig -o /boot/grub/grub.cfg
    echo "✓ GRUB updated successfully"
else
    echo "❌ ERROR: Neither update-grub nor grub-mkconfig found"
    exit 1
fi

echo ""
echo "========================================"
echo "GRUB Update Complete"
echo "========================================"
echo "✓ Configuration applied successfully"
echo "✓ Backup saved to: ${GRUB_DEFAULT}.backup_${TIMESTAMP}"
echo ""
echo "⚠️  REBOOT REQUIRED"
echo ""
echo "Next steps:"
echo "1. Review changes: cat $GRUB_DEFAULT"
echo "2. Reboot system: sudo reboot"
echo "3. After reboot, verify: cat /proc/cmdline"
echo ""

