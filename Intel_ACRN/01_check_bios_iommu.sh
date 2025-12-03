#!/bin/bash
#
# Script: 01_check_bios_iommu.sh
# Purpose: Check if IOMMU/VT-d is enabled in BIOS and kernel
# Usage: ./01_check_bios_iommu.sh

set -e

echo "========================================"
echo "BIOS/IOMMU Check"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

ERRORS=0

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  Running without root - some checks may be limited"
    echo ""
fi

# Check CPU vendor
echo "1. CPU Vendor:"
if grep -q "GenuineIntel" /proc/cpuinfo; then
    echo "   ✓ Intel CPU detected"
else
    echo "   ❌ Not an Intel CPU (ACRN requires Intel)"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check VT-x support
echo "2. VT-x (Virtualization) Support:"
if grep -q "vmx" /proc/cpuinfo || grep -q "svm" /proc/cpuinfo; then
    echo "   ✓ Hardware virtualization supported"
else
    echo "   ❌ Hardware virtualization NOT supported"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check VT-d/IOMMU in dmesg
echo "3. IOMMU/VT-d Status:"
if dmesg | grep -qi "DMAR.*enabled\|IOMMU.*enabled"; then
    echo "   ✓ IOMMU detected in kernel messages"
elif dmesg | grep -qi "DMAR.*disabled\|IOMMU.*disabled"; then
    echo "   ❌ IOMMU is DISABLED in kernel"
    ERRORS=$((ERRORS + 1))
else
    echo "   ⚠️  IOMMU status unclear from dmesg"
fi
echo ""

# Check if IOMMU is enabled in current kernel
echo "4. Current Kernel IOMMU:"
if [ -d /sys/kernel/iommu_groups ]; then
    GROUP_COUNT=$(find /sys/kernel/iommu_groups -mindepth 1 -maxdepth 1 -type d | wc -l)
    if [ "$GROUP_COUNT" -gt 0 ]; then
        echo "   ✓ IOMMU groups found: $GROUP_COUNT groups"
    else
        echo "   ⚠️  IOMMU groups directory exists but empty"
    fi
else
    echo "   ❌ IOMMU groups not found - IOMMU likely disabled"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check GRUB for intel_iommu=on
echo "5. GRUB Configuration:"
if grep -q "intel_iommu=on" /etc/default/grub 2>/dev/null || \
   grep -q "intel_iommu=on" /boot/grub/grub.cfg 2>/dev/null; then
    echo "   ✓ intel_iommu=on found in GRUB"
else
    echo "   ⚠️  intel_iommu=on NOT found in GRUB (will need to add)"
fi
echo ""

# Summary
echo "========================================"
if [ $ERRORS -eq 0 ]; then
    echo "✓ BIOS/IOMMU Check: PASSED"
    exit 0
else
    echo "❌ BIOS/IOMMU Check: FAILED ($ERRORS errors)"
    echo ""
    echo "Next steps:"
    echo "1. Enable VT-d in BIOS"
    echo "2. Add 'intel_iommu=on' to GRUB kernel parameters"
    echo "3. Reboot and run this script again"
    exit 1
fi

