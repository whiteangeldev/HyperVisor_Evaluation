#!/bin/bash
#
# Script: 14_diagnose_boot_issue.sh
# Purpose: Diagnose ACRN boot issues and provide fixes
# Usage: sudo ./14_diagnose_boot_issue.sh

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

echo "========================================"
echo "ACRN Boot Issue Diagnosis"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

ERRORS=0
WARNINGS=0
FIXES_NEEDED=0

# 1. Check ACRN binary
echo "1. ACRN Binary Check:"
if [ -f /boot/acrn.bin ]; then
    SIZE=$(stat -c%s /boot/acrn.bin 2>/dev/null || stat -f%z /boot/acrn.bin 2>/dev/null)
    echo "   ✓ /boot/acrn.bin exists ($(numfmt --to=iec-i --suffix=B $SIZE 2>/dev/null || echo "${SIZE} bytes"))"
    
    # Check if it's a valid ELF or multiboot binary
    if file /boot/acrn.bin | grep -qE "(ELF|executable|multiboot)"; then
        echo "   ✓ Binary format appears valid"
    else
        echo "   ⚠️  Binary format may be incorrect"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check file permissions
    if [ -r /boot/acrn.bin ]; then
        echo "   ✓ Binary is readable"
    else
        echo "   ❌ Binary is not readable"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "   ❌ /boot/acrn.bin not found"
    echo "      Run: sudo ./07_install_acrn_binary.sh"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 2. Check GRUB entry
echo "2. GRUB Entry Check:"
if [ -f /etc/grub.d/40_custom_acrn ]; then
    echo "   ✓ GRUB entry file exists"
    
    # Check for critical parameters
    if grep -q "intel_iommu=on" /etc/grub.d/40_custom_acrn; then
        echo "   ✓ intel_iommu=on found in GRUB entry"
    else
        echo "   ❌ intel_iommu=on MISSING in GRUB entry"
        echo "      This is CRITICAL - Service VM needs IOMMU enabled"
        ERRORS=$((ERRORS + 1))
        FIXES_NEEDED=$((FIXES_NEEDED + 1))
    fi
    
    # Check for console parameters
    if grep -q "console=" /etc/grub.d/40_custom_acrn; then
        echo "   ✓ Console parameters found"
    else
        echo "   ⚠️  Console parameters missing"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check kernel and initrd paths
    KERNEL_PATH=$(grep "module2.*vmlinuz" /etc/grub.d/40_custom_acrn | awk '{print $2}' | head -1 || echo "")
    INITRD_PATH=$(grep "module2.*initrd" /etc/grub.d/40_custom_acrn | awk '{print $2}' | head -1 || echo "")
    
    if [ -n "$KERNEL_PATH" ]; then
        if [ -f "$KERNEL_PATH" ]; then
            echo "   ✓ Kernel file exists: $KERNEL_PATH"
        else
            echo "   ❌ Kernel file NOT found: $KERNEL_PATH"
            ERRORS=$((ERRORS + 1))
        fi
    fi
    
    if [ -n "$INITRD_PATH" ]; then
        if [ -f "$INITRD_PATH" ]; then
            echo "   ✓ Initrd file exists: $INITRD_PATH"
        else
            echo "   ❌ Initrd file NOT found: $INITRD_PATH"
            ERRORS=$((ERRORS + 1))
        fi
    fi
    
    # Check for root UUID
    if grep -q "root=UUID=" /etc/grub.d/40_custom_acrn; then
        echo "   ✓ Root UUID parameter found"
    else
        echo "   ❌ Root UUID parameter missing"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "   ❌ GRUB entry file not found"
    echo "      Run: sudo ./11_create_grub_entry.sh"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 3. Check GRUB configuration
echo "3. GRUB Configuration:"
if [ -f /boot/grub/grub.cfg ]; then
    if grep -q "ACRN Hypervisor" /boot/grub/grub.cfg; then
        echo "   ✓ ACRN entry found in grub.cfg"
        
        # Check if intel_iommu=on is in the actual boot entry
        if grep -A 20 "ACRN Hypervisor" /boot/grub/grub.cfg | grep -q "intel_iommu=on"; then
            echo "   ✓ intel_iommu=on found in compiled grub.cfg"
        else
            echo "   ❌ intel_iommu=on NOT in compiled grub.cfg"
            echo "      Need to regenerate GRUB entry with IOMMU parameter"
            ERRORS=$((ERRORS + 1))
            FIXES_NEEDED=$((FIXES_NEEDED + 1))
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

# 4. Check ACRN binary build info
echo "4. ACRN Binary Information:"
if [ -f /boot/acrn.bin ]; then
    # Try to get strings from binary to check build info
    if command -v strings &> /dev/null; then
        BUILD_INFO=$(strings /boot/acrn.bin 2>/dev/null | grep -E "(ACRN|version|board|scenario)" | head -5 || echo "")
        if [ -n "$BUILD_INFO" ]; then
            echo "   Build info found:"
            echo "$BUILD_INFO" | sed 's/^/      /'
        else
            echo "   ⚠️  Could not extract build info"
        fi
    fi
fi
echo ""

# 5. Check multiboot2 support
echo "5. GRUB Multiboot2 Support:"
if [ -d /boot/grub/i386-pc ] || [ -d /boot/grub/x86_64-efi ]; then
    if [ -f /boot/grub/i386-pc/multiboot2.mod ] || [ -f /boot/grub/x86_64-efi/multiboot2.mod ]; then
        echo "   ✓ Multiboot2 module available"
    else
        echo "   ⚠️  Multiboot2 module not found (may be built-in)"
    fi
else
    echo "   ⚠️  Cannot determine GRUB modules location"
fi
echo ""

# 6. Check for common issues
echo "6. Common Issues Check:"
# Check if ACRN binary is too small (might be corrupted)
if [ -f /boot/acrn.bin ]; then
    SIZE=$(stat -c%s /boot/acrn.bin 2>/dev/null || stat -f%z /boot/acrn.bin 2>/dev/null)
    if [ "$SIZE" -lt 100000 ]; then
        echo "   ⚠️  ACRN binary seems too small ($SIZE bytes) - may be corrupted"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Check if running under ACRN (should not be if boot failed)
if [ -d /dev/acrn ]; then
    echo "   ⚠️  /dev/acrn exists - you may already be running under ACRN"
    echo "      If boot failed, this is unexpected"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Summary and recommendations
echo "========================================"
echo "Diagnosis Summary"
echo "========================================"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo "Fixes needed: $FIXES_NEEDED"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✓ All checks passed"
    echo ""
    echo "If boot still fails, possible causes:"
    echo "1. ACRN binary incompatible with hardware"
    echo "2. ACRN binary built with wrong board/scenario"
    echo "3. Hardware incompatibility"
    echo "4. Need to check boot logs (dmesg after failed boot)"
else
    if [ $FIXES_NEEDED -gt 0 ]; then
        echo "❌ Critical issues found that need fixing"
        echo ""
        echo "Recommended fix:"
        echo "  Run: sudo ./15_fix_grub_entry.sh"
        echo ""
        echo "Or manually fix the GRUB entry to include:"
        echo "  - intel_iommu=on in Service VM kernel parameters"
        echo "  - console=tty0 console=ttyS0,115200n8"
    else
        echo "⚠️  Some warnings found, but no critical errors"
    fi
fi

echo ""
echo "Additional troubleshooting:"
echo "1. Check if ACRN binary was built correctly:"
echo "   ls -lh /boot/acrn.bin"
echo "   file /boot/acrn.bin"
echo ""
echo "2. Review GRUB entry:"
echo "   cat /etc/grub.d/40_custom_acrn"
echo ""
echo "3. Check compiled GRUB config:"
echo "   grep -A 30 'ACRN Hypervisor' /boot/grub/grub.cfg"
echo ""
echo "4. After failed boot, check:"
echo "   dmesg | grep -i acrn"
echo "   journalctl -b -1 | grep -i acrn"

