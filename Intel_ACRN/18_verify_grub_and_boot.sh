#!/bin/bash
#
# Script: 18_verify_grub_and_boot.sh
# Purpose: Verify GRUB entry is correct before booting
# Usage: ./18_verify_grub_and_boot.sh

set -e

echo "========================================"
echo "ACRN GRUB Entry Verification"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

ERRORS=0
WARNINGS=0

# 1. Check GRUB entry file
echo "1. Checking GRUB entry file..."
GRUB_ENTRY="/etc/grub.d/40_custom_acrn"
if [ -f "$GRUB_ENTRY" ]; then
    echo "   ✓ GRUB entry file exists"
    
    # Check multiboot2 line
    MULTIBOOT_LINE=$(grep "multiboot2.*acrn.bin" "$GRUB_ENTRY" || echo "")
    if [ -n "$MULTIBOOT_LINE" ]; then
        # Check for extra /boot/ or other issues
        if echo "$MULTIBOOT_LINE" | grep -q "multiboot2 /boot/acrn.bin[^ ]*$" || \
           echo "$MULTIBOOT_LINE" | grep -q "multiboot2 /boot/acrn.bin hvlog\|console\|uart"; then
            echo "   ✓ multiboot2 line looks correct"
        else
            if echo "$MULTIBOOT_LINE" | grep -q "/boot/ /boot/\|/boot/ /"; then
                echo "   ❌ multiboot2 line has extra /boot/ path"
                echo "      Current: $MULTIBOOT_LINE"
                echo "      Should be: multiboot2 /boot/acrn.bin"
                ERRORS=$((ERRORS + 1))
            else
                echo "   ⚠️  multiboot2 line: $MULTIBOOT_LINE"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    else
        echo "   ❌ multiboot2 line not found"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check module2 kernel line
    MODULE2_KERNEL=$(grep "module2.*vmlinuz" "$GRUB_ENTRY" || echo "")
    if [ -n "$MODULE2_KERNEL" ]; then
        # Check for intel_iommu=on
        if echo "$MODULE2_KERNEL" | grep -q "intel_iommu=on"; then
            echo "   ✓ intel_iommu=on found in kernel parameters"
        else
            echo "   ❌ intel_iommu=on MISSING in kernel parameters"
            ERRORS=$((ERRORS + 1))
        fi
        
        # Check for duplicate kernel paths
        KERNEL_COUNT=$(echo "$MODULE2_KERNEL" | grep -o "/boot/vmlinuz[^ ]*" | wc -l || echo "0")
        if [ "$KERNEL_COUNT" -eq 1 ]; then
            echo "   ✓ Kernel path appears once (correct)"
        else
            echo "   ❌ Kernel path appears $KERNEL_COUNT times (should be 1)"
            ERRORS=$((ERRORS + 1))
        fi
        
        # Check for root UUID
        if echo "$MODULE2_KERNEL" | grep -q "root=UUID="; then
            echo "   ✓ root=UUID parameter found"
        else
            echo "   ❌ root=UUID parameter missing"
            ERRORS=$((ERRORS + 1))
        fi
        
        # Check for console parameters
        if echo "$MODULE2_KERNEL" | grep -q "console="; then
            echo "   ✓ Console parameters found"
        else
            echo "   ⚠️  Console parameters missing"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo "   ❌ module2 kernel line not found"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check module2 initrd line
    if grep -q "module2.*initrd" "$GRUB_ENTRY"; then
        echo "   ✓ module2 initrd line found"
    else
        echo "   ❌ module2 initrd line missing"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "   ❌ GRUB entry file not found: $GRUB_ENTRY"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 2. Check if GRUB needs updating
echo "2. Checking if GRUB needs updating..."
if [ -f "$GRUB_ENTRY" ]; then
    ENTRY_TIME=$(stat -c %Y "$GRUB_ENTRY" 2>/dev/null || stat -f %m "$GRUB_ENTRY" 2>/dev/null)
    GRUB_CFG_TIME=$(stat -c %Y /boot/grub/grub.cfg 2>/dev/null || stat -f %m /boot/grub/grub.cfg 2>/dev/null || echo "0")
    
    if [ "$ENTRY_TIME" -gt "$GRUB_CFG_TIME" ]; then
        echo "   ⚠️  GRUB entry was modified after grub.cfg was generated"
        echo "      Need to run: sudo update-grub"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "   ✓ GRUB is up to date"
    fi
fi
echo ""

# 3. Check compiled grub.cfg
echo "3. Checking compiled grub.cfg..."
if [ -f /boot/grub/grub.cfg ]; then
    if grep -q "ACRN Hypervisor" /boot/grub/grub.cfg; then
        echo "   ✓ ACRN entry found in grub.cfg"
        
        # Check compiled multiboot2 line
        COMPILED_MULTIBOOT=$(grep -A 15 "ACRN Hypervisor" /boot/grub/grub.cfg | grep "multiboot2" | head -1 || echo "")
        if [ -n "$COMPILED_MULTIBOOT" ]; then
            if echo "$COMPILED_MULTIBOOT" | grep -q "/boot/ /boot/\|/boot/ /"; then
                echo "   ❌ Compiled multiboot2 has extra /boot/ path"
                echo "      Current: $COMPILED_MULTIBOOT"
                ERRORS=$((ERRORS + 1))
            else
                echo "   ✓ Compiled multiboot2 line looks correct"
            fi
        fi
        
        # Check compiled module2 line
        COMPILED_MODULE2=$(grep -A 20 "ACRN Hypervisor" /boot/grub/grub.cfg | grep "module2.*vmlinuz" | head -1 || echo "")
        if [ -n "$COMPILED_MODULE2" ]; then
            if echo "$COMPILED_MODULE2" | grep -q "intel_iommu=on"; then
                echo "   ✓ intel_iommu=on found in compiled config"
            else
                echo "   ❌ intel_iommu=on NOT in compiled config"
                ERRORS=$((ERRORS + 1))
            fi
            
            # Check for duplicate kernel paths
            COMPILED_KERNEL_COUNT=$(echo "$COMPILED_MODULE2" | grep -o "/boot/vmlinuz[^ ]*" | wc -l || echo "0")
            if [ "$COMPILED_KERNEL_COUNT" -eq 1 ]; then
                echo "   ✓ No duplicate kernel paths in compiled config"
            else
                echo "   ❌ Duplicate kernel paths in compiled config ($COMPILED_KERNEL_COUNT found)"
                ERRORS=$((ERRORS + 1))
            fi
        fi
    else
        echo "   ⚠️  ACRN entry not found in grub.cfg"
        echo "      Run: sudo update-grub"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "   ⚠️  grub.cfg not found (may be using EFI)"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 4. Check ACRN binary
echo "4. Checking ACRN binary..."
if [ -f /boot/acrn.bin ]; then
    SIZE=$(stat -c%s /boot/acrn.bin 2>/dev/null || stat -f%z /boot/acrn.bin 2>/dev/null)
    if [ "$SIZE" -gt 100000 ]; then
        echo "   ✓ /boot/acrn.bin exists and has reasonable size ($(numfmt --to=iec-i --suffix=B $SIZE 2>/dev/null || echo "${SIZE} bytes"))"
    else
        echo "   ⚠️  /boot/acrn.bin seems too small ($SIZE bytes)"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "   ❌ /boot/acrn.bin not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Summary
echo "========================================"
echo "Verification Summary"
echo "========================================"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✓ All checks passed! Ready to boot."
    echo ""
    echo "Next steps:"
    echo "1. Reboot: sudo reboot"
    echo "2. Select 'ACRN Hypervisor' from GRUB menu"
    echo "3. After boot, run: ./12_verify_acrn.sh"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  Some warnings found, but no critical errors"
    echo ""
    if [ $WARNINGS -gt 0 ]; then
        echo "Recommendations:"
        if grep -q "GRUB entry was modified" <<< "$(grep -A 5 '2. Checking' <<< "$(cat /dev/stdin)")" 2>/dev/null || [ -f "$GRUB_ENTRY" ]; then
            echo "- Run: sudo update-grub (to update compiled config)"
        fi
    fi
    echo ""
    echo "You can proceed with boot, but review warnings above."
    exit 0
else
    echo "❌ Critical errors found!"
    echo ""
    echo "Please fix the errors above before rebooting."
    echo ""
    echo "Common fixes:"
    echo "- If multiboot2 has extra /boot/: Edit /etc/grub.d/40_custom_acrn"
    echo "- If intel_iommu=on missing: Run sudo ./15_fix_grub_entry.sh"
    echo "- If GRUB needs updating: Run sudo update-grub"
    exit 1
fi

