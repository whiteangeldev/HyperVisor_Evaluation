#!/bin/bash
#
# Script: 13_test_acrn_boot.sh
# Purpose: Test ACRN boot configuration (dry-run check)
# Usage: ./13_test_acrn_boot.sh

set -e

echo "========================================"
echo "ACRN Boot Test (Pre-Boot Check)"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

ERRORS=0

# Check ACRN binary
echo "1. ACRN Binary:"
if [ -f /boot/acrn.bin ]; then
    SIZE=$(ls -lh /boot/acrn.bin | awk '{print $5}')
    echo "   ✓ /boot/acrn.bin exists ($SIZE)"
else
    echo "   ❌ /boot/acrn.bin not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check GRUB entry
echo "2. GRUB Entry:"
if [ -f /etc/grub.d/40_custom_acrn ]; then
    echo "   ✓ GRUB entry file exists"
    if grep -q "ACRN Hypervisor" /etc/grub.d/40_custom_acrn; then
        echo "   ✓ ACRN menu entry found"
    else
        echo "   ❌ ACRN menu entry not found in file"
        ERRORS=$((ERRORS + 1))
    fi
    
    if grep -q "intel_iommu=on" /etc/grub.d/40_custom_acrn; then
        echo "   ✓ intel_iommu=on found in GRUB entry"
    else
        echo "   ⚠️  intel_iommu=on not found in GRUB entry"
    fi
else
    echo "   ❌ GRUB entry file not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check if ACRN appears in grub.cfg
echo "3. GRUB Configuration:"
if grep -q "ACRN Hypervisor" /boot/grub/grub.cfg 2>/dev/null; then
    echo "   ✓ ACRN entry found in grub.cfg"
    ENTRY_NUM=$(awk '/^menuentry/ {count++} /menuentry.*ACRN/ {print count-1; exit}' /boot/grub/grub.cfg)
    if [ -n "$ENTRY_NUM" ]; then
        echo "   ✓ ACRN is GRUB entry #$ENTRY_NUM"
    fi
else
    echo "   ⚠️  ACRN entry not found in grub.cfg"
    echo "   (May need to run: sudo update-grub)"
fi
echo ""

# Check kernel and initrd
echo "4. Service OS Files:"
KERNEL=$(grep "module2.*vmlinuz" /etc/grub.d/40_custom_acrn | awk '{print $2}' | head -1 || echo "")
INITRD=$(grep "module2.*initrd" /etc/grub.d/40_custom_acrn | awk '{print $2}' | head -1 || echo "")

if [ -n "$KERNEL" ] && [ -f "$KERNEL" ]; then
    echo "   ✓ Kernel found: $KERNEL"
else
    echo "   ⚠️  Kernel path in GRUB entry may be incorrect"
fi

if [ -n "$INITRD" ] && [ -f "$INITRD" ]; then
    echo "   ✓ Initrd found: $INITRD"
else
    echo "   ⚠️  Initrd path in GRUB entry may be incorrect"
fi
echo ""

# Check IOMMU configuration
echo "5. IOMMU Configuration:"
if grep -q "intel_iommu=on" /etc/default/grub 2>/dev/null || \
   grep -q "intel_iommu=on" /boot/grub/grub.cfg 2>/dev/null; then
    echo "   ✓ intel_iommu=on configured"
else
    echo "   ⚠️  intel_iommu=on not found (may be in GRUB entry only)"
fi
echo ""

# Check CPU isolation
echo "6. CPU Isolation:"
if grep -q "isolcpus=" /etc/default/grub 2>/dev/null; then
    ISOLCPUS=$(grep "isolcpus=" /etc/default/grub | sed 's/.*isolcpus=\([^ ]*\).*/\1/')
    echo "   ✓ isolcpus configured: $ISOLCPUS"
else
    echo "   ⚠️  isolcpus not configured"
fi
echo ""

# Summary
echo "========================================"
if [ $ERRORS -eq 0 ]; then
    echo "✓ Boot Test: PASSED"
    echo ""
    echo "ACRN is ready to boot!"
    echo ""
    echo "Next steps:"
    echo "1. Reboot: sudo reboot"
    echo "2. Select 'ACRN Hypervisor' from GRUB menu"
    echo "3. After boot, run: ./12_verify_acrn.sh"
else
    echo "❌ Boot Test: FAILED ($ERRORS errors)"
    echo ""
    echo "Please fix the errors above before rebooting"
fi

