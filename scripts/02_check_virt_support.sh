#!/bin/bash
#
# Script: 02_check_virt_support.sh
# Purpose: Verify virtualization support (VT-x, VT-d, IOMMU)
# Usage: ./02_check_virt_support.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
OUTPUT_FILE="$LOG_DIR/virt_support.log"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "Virtualization Support Check"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

{
    echo "========================================"
    echo "VIRTUALIZATION SUPPORT CHECK"
    echo "========================================"
    echo "Check Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    echo "========================================"
    echo "CPU VIRTUALIZATION FEATURES"
    echo "========================================"
    
    # Check for VT-x (Intel) or AMD-V
    if grep -q "vmx" /proc/cpuinfo; then
        echo "✓ VT-x (Intel Virtualization Technology) SUPPORTED"
        VTX_STATUS="PASS"
    else
        echo "✗ VT-x NOT FOUND"
        VTX_STATUS="FAIL"
    fi
    
    if grep -q "svm" /proc/cpuinfo; then
        echo "✓ AMD-V (AMD Virtualization) SUPPORTED"
    fi
    
    echo ""
    
    # Check for EPT (Extended Page Tables)
    if grep -q "ept" /proc/cpuinfo; then
        echo "✓ EPT (Extended Page Tables) SUPPORTED"
        EPT_STATUS="PASS"
    else
        echo "✗ EPT NOT FOUND"
        EPT_STATUS="FAIL"
    fi
    
    echo ""
    
    # Check for VPID
    if grep -q "vpid" /proc/cpuinfo; then
        echo "✓ VPID (Virtual Processor ID) SUPPORTED"
    fi
    
    echo ""
    
    echo "========================================"
    echo "IOMMU HARDWARE DETECTION"
    echo "========================================"
    
    # Check for IOMMU hardware via lspci
    if lspci -v | grep -i "iommu" > /dev/null 2>&1; then
        echo "✓ IOMMU HARDWARE DETECTED"
        lspci | grep -i "iommu"
        IOMMU_HW_STATUS="PASS"
    else
        echo "✗ IOMMU HARDWARE NOT DETECTED"
        IOMMU_HW_STATUS="FAIL"
    fi
    
    echo ""
    
    echo "========================================"
    echo "IOMMU KERNEL STATUS"
    echo "========================================"
    
    # Check if IOMMU is enabled in kernel
    if [ -d "/sys/kernel/iommu_groups" ]; then
        IOMMU_GROUP_COUNT=$(find /sys/kernel/iommu_groups/ -maxdepth 1 -type d | wc -l)
        if [ "$IOMMU_GROUP_COUNT" -gt 1 ]; then
            echo "✓ IOMMU ENABLED: $((IOMMU_GROUP_COUNT - 1)) groups found"
            IOMMU_KERNEL_STATUS="PASS"
        else
            echo "✗ IOMMU NOT ENABLED (no groups found)"
            IOMMU_KERNEL_STATUS="FAIL"
        fi
    else
        echo "✗ IOMMU NOT ENABLED (/sys/kernel/iommu_groups not found)"
        IOMMU_KERNEL_STATUS="FAIL"
    fi
    
    echo ""
    
    echo "========================================"
    echo "KERNEL MODULES"
    echo "========================================"
    
    echo "KVM modules:"
    lsmod | grep kvm || echo "  No KVM modules loaded"
    echo ""
    
    echo "VFIO modules:"
    lsmod | grep vfio || echo "  No VFIO modules loaded"
    echo ""
    
    echo "========================================"
    echo "DMESG IOMMU MESSAGES (requires sudo)"
    echo "========================================"
    
    if [ "$EUID" -eq 0 ]; then
        dmesg | grep -i "iommu\|vt-d\|dmar" | head -30 || echo "  No IOMMU messages in dmesg"
    else
        echo "  (Skipped - requires root privileges)"
        echo "  Run: sudo dmesg | grep -i iommu"
    fi
    
    echo ""
    
    echo "========================================"
    echo "SUMMARY"
    echo "========================================"
    echo "VT-x Support:           $VTX_STATUS"
    echo "EPT Support:            $EPT_STATUS"
    echo "IOMMU Hardware:         $IOMMU_HW_STATUS"
    echo "IOMMU Kernel Status:    $IOMMU_KERNEL_STATUS"
    echo ""
    
    if [ "$VTX_STATUS" = "PASS" ] && [ "$IOMMU_HW_STATUS" = "PASS" ]; then
        echo "✓ HARDWARE VIRTUALIZATION CAPABLE"
        if [ "$IOMMU_KERNEL_STATUS" = "FAIL" ]; then
            echo "⚠ IOMMU needs to be enabled in kernel parameters"
        fi
    else
        echo "✗ VIRTUALIZATION REQUIREMENTS NOT MET"
    fi
    
} | tee "$OUTPUT_FILE"

echo ""
echo "✓ Virtualization support check completed"
echo "✓ Output saved to: $OUTPUT_FILE"
echo ""

