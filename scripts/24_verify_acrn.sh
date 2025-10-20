#!/bin/bash
#
# Script: 24_verify_acrn.sh
# Purpose: Verify Intel ACRN installation and status
# Usage: ./24_verify_acrn.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
OUTPUT_FILE="$LOG_DIR/acrn_status.log"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "Intel ACRN Verification"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

{
    echo "========================================"
    echo "INTEL ACRN VERIFICATION"
    echo "========================================"
    echo "Verification Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo ""
    
    echo "========================================"
    echo "ACRN INSTALLATION CHECK"
    echo "========================================"
    echo "Checking for ACRN binaries..."
    
    if [ -f /usr/bin/acrn-dm ]; then
        echo "✓ Device model: /usr/bin/acrn-dm"
        ls -lh /usr/bin/acrn-dm
    else
        echo "✗ Device model not found"
    fi
    
    if [ -f /usr/bin/acrnctl ]; then
        echo "✓ Control tool: /usr/bin/acrnctl"
        ls -lh /usr/bin/acrnctl
    else
        echo "✗ Control tool not found"
    fi
    
    if [ -f /usr/bin/acrnlog ]; then
        echo "✓ Log tool: /usr/bin/acrnlog"
        ls -lh /usr/bin/acrnlog
    else
        echo "✗ Log tool not found"
    fi
    echo ""
    
    echo "Checking for ACRN hypervisor binary in /boot..."
    if [ -f /boot/acrn.bin ] || [ -f /boot/acrn.32.out ]; then
        echo "✓ Hypervisor binary found in /boot/"
        ls -lh /boot/acrn.* 2>/dev/null || true
    else
        echo "✗ Hypervisor binary not found in /boot/"
    fi
    echo ""
    
    echo "========================================"
    echo "ACRN HYPERVISOR STATUS"
    echo "========================================"
    echo "Checking for ACRN device nodes..."
    
    if [ -c /dev/acrn_hsm ] || [ -c /dev/acrn_vhm ]; then
        echo "✓ ACRN is RUNNING"
        ls -la /dev/acrn* 2>/dev/null || true
        echo ""
    else
        echo "✗ ACRN device nodes not found"
        echo "   This means ACRN is not currently running"
        echo "   (Normal if not booted into ACRN kernel)"
        echo ""
    fi
    
    echo "Checking ACRN kernel modules..."
    if lsmod | grep -q acrn; then
        echo "✓ ACRN modules loaded:"
        lsmod | grep acrn
    else
        echo "✗ ACRN modules not loaded"
    fi
    echo ""
    
    echo "========================================"
    echo "ACRN VERSION"
    echo "========================================"
    if command -v acrn-dm &> /dev/null; then
        echo "Device Model version:"
        acrn-dm --version 2>&1 || echo "Version info not available"
    else
        echo "acrn-dm command not available"
    fi
    echo ""
    
    echo "========================================"
    echo "DMESG - ACRN MESSAGES"
    echo "========================================"
    if dmesg | grep -i acrn > /dev/null 2>&1; then
        echo "ACRN-related kernel messages:"
        dmesg | grep -i acrn | tail -20
    else
        echo "No ACRN messages in dmesg"
        echo "(Normal if not booted into ACRN)"
    fi
    echo ""
    
    echo "========================================"
    echo "ACRN VMs STATUS"
    echo "========================================"
    if [ -c /dev/acrn_hsm ] || [ -c /dev/acrn_vhm ]; then
        echo "Checking running VMs..."
        if command -v acrnctl &> /dev/null; then
            acrnctl list 2>&1 || echo "Cannot list VMs"
        else
            echo "acrnctl not available"
        fi
    else
        echo "ACRN not running, cannot check VMs"
    fi
    echo ""
    
    echo "========================================"
    echo "GRUB CONFIGURATION"
    echo "========================================"
    echo "Checking for ACRN GRUB entries..."
    if [ -f /boot/grub/grub.cfg ]; then
        if grep -q "acrn" /boot/grub/grub.cfg; then
            echo "✓ ACRN entries found in GRUB:"
            grep "menuentry.*acrn" /boot/grub/grub.cfg -i | head -5
        else
            echo "✗ No ACRN entries in GRUB config"
        fi
    else
        echo "✗ GRUB config not found"
    fi
    echo ""
    
    if [ -f /etc/grub.d/40_custom_acrn ]; then
        echo "✓ Custom ACRN GRUB entry exists"
        echo "Contents:"
        cat /etc/grub.d/40_custom_acrn
    else
        echo "⚠ Custom ACRN GRUB entry not found"
    fi
    echo ""
    
    echo "========================================"
    echo "CPU CONFIGURATION FOR ACRN"
    echo "========================================"
    echo "Total CPUs: $(nproc)"
    echo ""
    
    if [ -f /sys/devices/system/cpu/isolated ]; then
        ISOLATED=$(cat /sys/devices/system/cpu/isolated)
        if [ -n "$ISOLATED" ]; then
            echo "✓ Isolated CPUs: $ISOLATED"
        else
            echo "⚠ No CPUs isolated"
        fi
    else
        echo "⚠ CPU isolation file not found"
    fi
    echo ""
    
    echo "========================================"
    echo "IOMMU STATUS FOR ACRN"
    echo "========================================"
    if grep -qE "(intel_iommu=on)" /proc/cmdline; then
        echo "✓ IOMMU enabled in kernel"
        grep -oE "intel_iommu=[^ ]*" /proc/cmdline
    else
        echo "⚠ IOMMU not enabled"
    fi
    echo ""
    
    if [ -d /sys/kernel/iommu_groups ]; then
        GROUP_COUNT=$(find /sys/kernel/iommu_groups -maxdepth 1 -type d | wc -l)
        GROUP_COUNT=$((GROUP_COUNT - 1))
        if [ $GROUP_COUNT -gt 0 ]; then
            echo "✓ IOMMU groups: $GROUP_COUNT"
        else
            echo "⚠ No IOMMU groups found"
        fi
    else
        echo "⚠ IOMMU groups not available"
    fi
    echo ""
    
    echo "========================================"
    echo "VERIFICATION SUMMARY"
    echo "========================================"
    
    PASS_COUNT=0
    FAIL_COUNT=0
    WARN_COUNT=0
    
    if [ -f /usr/bin/acrn-dm ]; then
        echo "✓ CHECK: ACRN binaries installed"
        ((PASS_COUNT++))
    else
        echo "✗ CHECK: ACRN binaries missing"
        ((FAIL_COUNT++))
    fi
    
    if [ -f /boot/acrn.bin ] || [ -f /boot/acrn.32.out ]; then
        echo "✓ CHECK: Hypervisor binary in /boot"
        ((PASS_COUNT++))
    else
        echo "✗ CHECK: Hypervisor binary missing from /boot"
        ((FAIL_COUNT++))
    fi
    
    if [ -f /etc/grub.d/40_custom_acrn ]; then
        echo "✓ CHECK: GRUB configuration exists"
        ((PASS_COUNT++))
    else
        echo "⚠ CHECK: GRUB configuration missing"
        ((WARN_COUNT++))
    fi
    
    if [ -c /dev/acrn_hsm ] || [ -c /dev/acrn_vhm ]; then
        echo "✓ CHECK: ACRN hypervisor running"
        ((PASS_COUNT++))
    else
        echo "⚠ CHECK: ACRN hypervisor not running"
        ((WARN_COUNT++))
        echo "   (Reboot into ACRN kernel to activate)"
    fi
    
    if grep -qE "(intel_iommu=on)" /proc/cmdline; then
        echo "✓ CHECK: IOMMU enabled"
        ((PASS_COUNT++))
    else
        echo "⚠ CHECK: IOMMU not enabled"
        ((WARN_COUNT++))
    fi
    
    echo ""
    echo "Results: $PASS_COUNT passed, $WARN_COUNT warnings, $FAIL_COUNT failed"
    
    if [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
        echo "✓✓✓ ACRN FULLY OPERATIONAL ✓✓✓"
    elif [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -le 2 ]; then
        echo "⚠⚠⚠ ACRN INSTALLED, REBOOT INTO ACRN KERNEL ⚠⚠⚠"
    elif [ $FAIL_COUNT -eq 0 ]; then
        echo "⚠⚠⚠ ACRN PARTIALLY CONFIGURED ⚠⚠⚠"
    else
        echo "✗✗✗ ACRN INSTALLATION INCOMPLETE ✗✗✗"
    fi
    echo ""
    
} > "$OUTPUT_FILE" 2>&1

echo "✓ ACRN verification complete"
echo "✓ Output saved to: $OUTPUT_FILE"
echo ""

# Display summary
echo "Summary:"
grep "Results:" "$OUTPUT_FILE"
if grep -q "ACRN is RUNNING" "$OUTPUT_FILE"; then
    grep "ACRN is RUNNING" "$OUTPUT_FILE"
elif grep -q "ACRN device nodes not found" "$OUTPUT_FILE"; then
    echo "⚠ ACRN not currently running (reboot into ACRN kernel)"
fi
echo ""
echo "Review full report: cat $OUTPUT_FILE"
echo ""

