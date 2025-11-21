#!/bin/bash
#
# Script: 19_fix_duplicate_grub_entries.sh
# Purpose: Remove duplicate ACRN GRUB entries and keep only one correct entry
# Usage: sudo ./19_fix_duplicate_grub_entries.sh

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

echo "========================================"
echo "Fix Duplicate ACRN GRUB Entries"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Find all ACRN-related GRUB entry files
echo "1. Searching for ACRN GRUB entry files..."
ACRN_ENTRIES=$(find /etc/grub.d -name "*acrn*" -o -name "*custom*" 2>/dev/null | grep -E "(acrn|custom)" | sort)
ALL_CUSTOM=$(find /etc/grub.d -name "*custom*" 2>/dev/null | sort)

echo "Found GRUB entry files:"
for entry in $ALL_CUSTOM; do
    if [ -f "$entry" ]; then
        if grep -q "ACRN Hypervisor\|acrn.bin" "$entry" 2>/dev/null; then
            echo "   ✓ ACRN entry: $entry"
        else
            echo "   - Other custom: $entry"
        fi
    fi
done
echo ""

# Count ACRN entries
ACRN_COUNT=$(echo "$ACRN_ENTRIES" | grep -c . || echo "0")
if [ "$ACRN_COUNT" -eq 0 ]; then
    ACRN_COUNT=$(grep -l "ACRN Hypervisor\|acrn.bin" /etc/grub.d/* 2>/dev/null | wc -l || echo "0")
fi

echo "2. Found $ACRN_COUNT ACRN GRUB entry file(s)"
echo ""

# Check which entries exist in grub.cfg
echo "3. Checking compiled grub.cfg..."
if [ -f /boot/grub/grub.cfg ]; then
    GRUB_ACRN_COUNT=$(grep -c "menuentry.*ACRN Hypervisor" /boot/grub/grub.cfg 2>/dev/null || echo "0")
    echo "   Found $GRUB_ACRN_COUNT ACRN menu entries in grub.cfg"
    
    if [ "$GRUB_ACRN_COUNT" -gt 1 ]; then
        echo "   ⚠️  Multiple ACRN entries detected in grub.cfg"
        echo ""
        echo "   Current ACRN entries:"
        grep -n "menuentry.*ACRN Hypervisor" /boot/grub/grub.cfg | sed 's/^/      /'
    fi
else
    echo "   ⚠️  grub.cfg not found (may be using EFI)"
fi
echo ""

# Find the best entry to keep (prefer 40_custom_acrn, then newest)
KEEP_ENTRY=""
PREFERRED_ENTRY="/etc/grub.d/40_custom_acrn"

if [ -f "$PREFERRED_ENTRY" ]; then
    KEEP_ENTRY="$PREFERRED_ENTRY"
    echo "4. Using preferred entry: $KEEP_ENTRY"
else
    # Find newest ACRN entry
    KEEP_ENTRY=$(grep -l "ACRN Hypervisor\|acrn.bin" /etc/grub.d/* 2>/dev/null | head -1 || echo "")
    if [ -n "$KEEP_ENTRY" ]; then
        echo "4. Using newest ACRN entry: $KEEP_ENTRY"
    else
        echo "❌ No ACRN GRUB entry found!"
        echo "   Run: sudo ./11_create_grub_entry.sh"
        exit 1
    fi
fi

# Verify the entry to keep is correct
echo "5. Verifying entry to keep..."
if grep -q "intel_iommu=on" "$KEEP_ENTRY" 2>/dev/null; then
    echo "   ✓ intel_iommu=on found"
else
    echo "   ⚠️  intel_iommu=on NOT found - will need to fix"
    NEEDS_FIX=true
fi

if grep -q "multiboot2.*acrn.bin" "$KEEP_ENTRY" 2>/dev/null; then
    MULTIBOOT_LINE=$(grep "multiboot2.*acrn.bin" "$KEEP_ENTRY" | head -1)
    if echo "$MULTIBOOT_LINE" | grep -q "/boot/ /boot/\|/boot/ /"; then
        echo "   ⚠️  multiboot2 line has issues: $MULTIBOOT_LINE"
        NEEDS_FIX=true
    else
        echo "   ✓ multiboot2 line looks correct"
    fi
else
    echo "   ❌ multiboot2 line not found"
    NEEDS_FIX=true
fi

if grep -q "module2.*vmlinuz" "$KEEP_ENTRY" 2>/dev/null; then
    KERNEL_COUNT=$(grep "module2.*vmlinuz" "$KEEP_ENTRY" | grep -o "/boot/vmlinuz[^ ]*" | wc -l || echo "0")
    if [ "$KERNEL_COUNT" -eq 1 ]; then
        echo "   ✓ Kernel path appears once"
    else
        echo "   ⚠️  Kernel path appears $KERNEL_COUNT times (should be 1)"
        NEEDS_FIX=true
    fi
fi
echo ""

# Find all other ACRN entries to remove
echo "6. Identifying duplicate entries to remove..."
DUPLICATES=$(grep -l "ACRN Hypervisor\|acrn.bin" /etc/grub.d/* 2>/dev/null | grep -v "^$KEEP_ENTRY$" || echo "")

if [ -z "$DUPLICATES" ]; then
    echo "   ✓ No duplicate files found (only one ACRN entry file exists)"
else
    echo "   Found duplicate entry files:"
    for dup in $DUPLICATES; do
        echo "      - $dup"
    done
fi
echo ""

# Backup and remove duplicates
if [ -n "$DUPLICATES" ]; then
    echo "7. Backing up and removing duplicates..."
    BACKUP_DIR="/etc/grub.d/backup_$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    for dup in $DUPLICATES; do
        if [ -f "$dup" ]; then
            cp "$dup" "$BACKUP_DIR/"
            rm -f "$dup"
            echo "   ✓ Removed: $dup (backed up to $BACKUP_DIR/)"
        fi
    done
    echo ""
fi

# Fix the entry if needed
if [ "$NEEDS_FIX" = true ]; then
    echo "8. Fixing the GRUB entry..."
    echo "   Running: sudo ./17_clean_grub_entry.sh"
    if [ -f "./17_clean_grub_entry.sh" ]; then
        ./17_clean_grub_entry.sh
    else
        echo "   ⚠️  Clean script not found, please run manually:"
        echo "      sudo ./17_clean_grub_entry.sh"
    fi
    echo ""
fi

# Ensure we have exactly one entry with correct name
echo "9. Ensuring single correct entry..."
if [ ! -f "/etc/grub.d/40_custom_acrn" ]; then
    if [ -n "$KEEP_ENTRY" ] && [ "$KEEP_ENTRY" != "/etc/grub.d/40_custom_acrn" ]; then
        echo "   Moving $KEEP_ENTRY to /etc/grub.d/40_custom_acrn"
        cp "$KEEP_ENTRY" /etc/grub.d/40_custom_acrn
        chmod +x /etc/grub.d/40_custom_acrn
    fi
fi

# Update GRUB
echo "10. Updating GRUB..."
if update-grub > /dev/null 2>&1; then
    echo "   ✓ GRUB updated"
else
    echo "   ⚠️  update-grub had warnings (may be normal)"
fi
echo ""

# Verify final result
echo "11. Verifying final configuration..."
FINAL_COUNT=$(grep -c "menuentry.*ACRN Hypervisor" /boot/grub/grub.cfg 2>/dev/null || echo "0")
if [ "$FINAL_COUNT" -eq 1 ]; then
    echo "   ✓ Exactly one ACRN entry in grub.cfg"
    
    # Show the entry
    echo ""
    echo "   Final ACRN entry:"
    grep -A 2 "menuentry.*ACRN Hypervisor" /boot/grub/grub.cfg | head -3 | sed 's/^/      /'
else
    echo "   ⚠️  Found $FINAL_COUNT ACRN entries (should be 1)"
    if [ "$FINAL_COUNT" -gt 1 ]; then
        echo "   This may require manual cleanup of grub.cfg"
    fi
fi
echo ""

echo "========================================"
echo "✓ Duplicate Entries Fixed"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Reboot: sudo reboot"
echo "2. You should now see only ONE 'ACRN Hypervisor' entry"
echo "3. Select it and boot"
echo "4. After boot, run: ./12_verify_acrn.sh"
echo ""






