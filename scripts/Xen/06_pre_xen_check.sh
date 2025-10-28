#!/bin/bash
#
# Script: 06_pre_xen_check.sh
# Purpose: Verify IOMMU is enabled after GRUB changes and reboot
# Usage: ./06_pre_xen_check.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
OUTPUT_FILE="$LOG_DIR/iommu_status.log"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "Pre-Xen IOMMU Verification"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

{
    echo "========================================"
    echo "IOMMU STATUS CHECK"
    echo "========================================"
    echo "Check Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    echo "========================================"
    echo "CURRENT KERNEL CMDLINE"
    echo "========================================"
    cat /proc/cmdline
    echo ""
    
    echo "========================================"
    echo "IOMMU PARAMETERS CHECK"
    echo "========================================"
    
    CMDLINE=$(cat /proc/cmdline)
    
    if echo "$CMDLINE" | grep -q "intel_iommu=on\|amd_iommu=on"; then
        echo "✓ IOMMU parameter found in cmdline"
    else
        echo "✗ IOMMU parameter NOT found in cmdline"
    fi
    
    if echo "$CMDLINE" | grep -q "iommu=pt"; then
        echo "✓ IOMMU passthrough mode enabled"
    else
        echo "⚠ IOMMU passthrough mode not enabled"
    fi
    
    echo ""
    
    echo "========================================"
    echo "CPU ISOLATION CHECK"
    echo "========================================"
    
    if echo "$CMDLINE" | grep -q "isolcpus="; then
        ISOLATED=$(echo "$CMDLINE" | grep -o "isolcpus=[^ ]*" | cut -d= -f2)
        echo "✓ CPU isolation configured: $ISOLATED"
    else
        echo "✗ CPU isolation NOT configured"
    fi
    
    if echo "$CMDLINE" | grep -q "nohz_full="; then
        NOHZ=$(echo "$CMDLINE" | grep -o "nohz_full=[^ ]*" | cut -d= -f2)
        echo "✓ nohz_full configured: $NOHZ"
    else
        echo "✗ nohz_full NOT configured"
    fi
    
    if echo "$CMDLINE" | grep -q "rcu_nocbs="; then
        RCU=$(echo "$CMDLINE" | grep -o "rcu_nocbs=[^ ]*" | cut -d= -f2)
        echo "✓ rcu_nocbs configured: $RCU"
    else
        echo "✗ rcu_nocbs NOT configured"
    fi
    
    echo ""
    
    echo "========================================"
    echo "IOMMU GROUPS"
    echo "========================================"
    
    if [ -d "/sys/kernel/iommu_groups" ]; then
        GROUP_COUNT=$(find /sys/kernel/iommu_groups/ -maxdepth 1 -type d | wc -l)
        GROUP_COUNT=$((GROUP_COUNT - 1))
        
        if [ "$GROUP_COUNT" -gt 0 ]; then
            echo "✓ IOMMU ENABLED: $GROUP_COUNT groups detected"
            echo ""
            echo "IOMMU Group Details:"
            for group in /sys/kernel/iommu_groups/*/devices/*; do
                if [ -e "$group" ]; then
                    GROUP_NUM=$(echo "$group" | sed 's|.*/iommu_groups/\([0-9]*\)/.*|\1|')
                    DEVICE=$(basename "$group")
                    DEVICE_INFO=$(lspci -nn -s "$DEVICE" 2>/dev/null || echo "Unknown device")
                    echo "  Group $GROUP_NUM: $DEVICE - $DEVICE_INFO"
                fi
            done
        else
            echo "✗ IOMMU NOT ENABLED: No groups detected"
        fi
    else
        echo "✗ IOMMU NOT ENABLED: /sys/kernel/iommu_groups not found"
    fi
    
    echo ""
    
    echo "========================================"
    echo "DMESG IOMMU MESSAGES"
    echo "========================================"
    
    if [ "$EUID" -eq 0 ]; then
        dmesg | grep -i "iommu\|vt-d\|dmar" | tail -50 || echo "No IOMMU messages found"
    else
        echo "(Requires sudo - run: sudo dmesg | grep -i iommu)"
    fi
    
    echo ""
    
    echo "========================================"
    echo "CPU ISOLATION VERIFICATION"
    echo "========================================"
    
    if [ -f /sys/devices/system/cpu/isolated ]; then
        ISOLATED_CPUS=$(cat /sys/devices/system/cpu/isolated)
        if [ -n "$ISOLATED_CPUS" ] && [ "$ISOLATED_CPUS" != "" ]; then
            echo "✓ Isolated CPUs: $ISOLATED_CPUS"
        else
            echo "⚠ No CPUs currently isolated"
        fi
    else
        echo "⚠ CPU isolation file not found"
    fi
    
    echo ""
    echo "Online CPUs: $(cat /sys/devices/system/cpu/online)"
    echo ""
    
    echo "========================================"
    echo "STATUS SUMMARY"
    echo "========================================"
    
    # Check critical requirements
    PASS=0
    FAIL=0
    
    if echo "$CMDLINE" | grep -q "intel_iommu=on\|amd_iommu=on"; then
        echo "✓ IOMMU enabled in kernel"
        ((PASS++))
    else
        echo "✗ IOMMU NOT enabled"
        ((FAIL++))
    fi
    
    if [ -d "/sys/kernel/iommu_groups" ] && [ "$GROUP_COUNT" -gt 0 ]; then
        echo "✓ IOMMU groups present"
        ((PASS++))
    else
        echo "✗ IOMMU groups NOT present"
        ((FAIL++))
    fi
    
    if echo "$CMDLINE" | grep -q "isolcpus="; then
        echo "✓ CPU isolation configured"
        ((PASS++))
    else
        echo "✗ CPU isolation NOT configured"
        ((FAIL++))
    fi
    
    echo ""
    echo "Checks passed: $PASS"
    echo "Checks failed: $FAIL"
    echo ""
    
    if [ "$FAIL" -eq 0 ]; then
        echo "✓ SYSTEM READY FOR XEN INSTALLATION"
        exit 0
    else
        echo "✗ SYSTEM NOT READY - Please fix issues above"
        exit 1
    fi
    
} | tee "$OUTPUT_FILE"

echo ""
echo "✓ Pre-Xen check completed"
echo "✓ Output saved to: $OUTPUT_FILE"
echo ""

