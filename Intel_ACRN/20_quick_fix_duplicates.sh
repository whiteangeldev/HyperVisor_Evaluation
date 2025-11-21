#!/bin/bash
#
# Script: 20_quick_fix_duplicates.sh
# Purpose: Quick fix for duplicate ACRN GRUB entries
# Usage: sudo ./20_quick_fix_duplicates.sh

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

echo "========================================"
echo "Quick Fix: Remove Duplicate ACRN Entries"
echo "========================================"
echo ""

# Find all ACRN entry files
echo "Finding all ACRN GRUB entry files..."
ACRN_FILES=$(grep -l "ACRN Hypervisor\|acrn.bin" /etc/grub.d/* 2>/dev/null | sort || echo "")

if [ -z "$ACRN_FILES" ]; then
    echo "❌ No ACRN GRUB entry files found"
    exit 1
fi

echo "Found ACRN entry files:"
for file in $ACRN_FILES; do
    echo "  - $file"
done
echo ""

# Keep only 40_custom_acrn, remove all others
KEEP_FILE="/etc/grub.d/40_custom_acrn"
BACKUP_DIR="/etc/grub.d/backup_$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Removing duplicates (keeping only $KEEP_FILE)..."
for file in $ACRN_FILES; do
    if [ "$file" != "$KEEP_FILE" ]; then
        if [ -f "$file" ]; then
            cp "$file" "$BACKUP_DIR/"
            rm -f "$file"
            echo "  ✓ Removed: $file (backed up)"
        fi
    fi
done

# If 40_custom_acrn doesn't exist, create it from the first found file
if [ ! -f "$KEEP_FILE" ] && [ -n "$ACRN_FILES" ]; then
    FIRST_FILE=$(echo "$ACRN_FILES" | head -1)
    if [ -f "$FIRST_FILE" ]; then
        cp "$FIRST_FILE" "$BACKUP_DIR/"
        cp "$FIRST_FILE" "$KEEP_FILE"
        chmod +x "$KEEP_FILE"
        rm -f "$FIRST_FILE"
        echo "  ✓ Created $KEEP_FILE from $FIRST_FILE"
    fi
fi

echo ""

# Verify the kept entry
if [ -f "$KEEP_FILE" ]; then
    echo "Verifying kept entry: $KEEP_FILE"
    
    if grep -q "intel_iommu=on" "$KEEP_FILE"; then
        echo "  ✓ intel_iommu=on found"
    else
        echo "  ⚠️  intel_iommu=on missing - will fix"
        NEEDS_FIX=true
    fi
    
    # Check for issues
    if grep -q "multiboot2.*acrn.bin.*/boot/" "$KEEP_FILE" && grep -q "multiboot2.*acrn.bin.*/boot/ /boot/" "$KEEP_FILE"; then
        echo "  ⚠️  multiboot2 line has issues"
        NEEDS_FIX=true
    fi
else
    echo "  ❌ $KEEP_FILE not found - need to create it"
    echo "     Run: sudo ./11_create_grub_entry.sh"
    exit 1
fi
echo ""

# Fix if needed
if [ "$NEEDS_FIX" = true ]; then
    echo "Fixing the entry..."
    if [ -f "./17_clean_grub_entry.sh" ]; then
        ./17_clean_grub_entry.sh
    else
        echo "  Run manually: sudo ./17_clean_grub_entry.sh"
    fi
fi

# Update GRUB
echo "Updating GRUB..."
update-grub > /dev/null 2>&1
echo "✓ GRUB updated"
echo ""

# Verify
FINAL_COUNT=$(grep -c "menuentry.*ACRN Hypervisor" /boot/grub/grub.cfg 2>/dev/null || echo "0")
echo "Final result: $FINAL_COUNT ACRN entry(ies) in grub.cfg"

if [ "$FINAL_COUNT" -eq 1 ]; then
    echo "✓ Success! Only one ACRN entry remains"
    echo ""
    echo "Next: sudo reboot and select 'ACRN Hypervisor'"
else
    echo "⚠️  Still have $FINAL_COUNT entries"
    echo "   You may need to manually edit /boot/grub/grub.cfg"
fi






