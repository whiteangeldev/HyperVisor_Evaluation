#!/bin/bash
#
# Script: 15_verify_iommu.sh
# Purpose: Verify IOMMU groups and enumerate devices for passthrough
# Usage: ./15_verify_iommu.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
OUTPUT_FILE="$LOG_DIR/iommu_groups.log"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "IOMMU Groups Verification"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

{
    echo "========================================"
    echo "IOMMU GROUPS VERIFICATION"
    echo "========================================"
    echo "Verification Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo ""
    
    echo "========================================"
    echo "KERNEL COMMAND LINE (IOMMU params)"
    echo "========================================"
    cat /proc/cmdline
    echo ""
    
    echo "Checking for IOMMU parameters..."
    if grep -qE "(intel_iommu=on|amd_iommu=on)" /proc/cmdline; then
        echo "✓ IOMMU enabled in kernel parameters"
    else
        echo "✗ IOMMU NOT enabled in kernel parameters"
    fi
    
    if grep -q "iommu=pt" /proc/cmdline; then
        echo "✓ IOMMU passthrough mode enabled"
    else
        echo "⚠ IOMMU passthrough mode not set"
    fi
    echo ""
    
    echo "========================================"
    echo "IOMMU HARDWARE STATUS"
    echo "========================================"
    if dmesg | grep -i "IOMMU enabled" > /dev/null 2>&1; then
        echo "✓ IOMMU reported as enabled in dmesg"
        dmesg | grep -i "IOMMU" | tail -10
    else
        echo "⚠ IOMMU status unclear in dmesg"
        dmesg | grep -i "iommu" | tail -10 || echo "No IOMMU messages found"
    fi
    echo ""
    
    echo "========================================"
    echo "IOMMU GROUPS ENUMERATION"
    echo "========================================"
    
    if [ -d /sys/kernel/iommu_groups ]; then
        GROUP_COUNT=$(find /sys/kernel/iommu_groups -maxdepth 1 -type d | wc -l)
        GROUP_COUNT=$((GROUP_COUNT - 1))  # Subtract parent directory
        
        if [ $GROUP_COUNT -gt 0 ]; then
            echo "✓ Found $GROUP_COUNT IOMMU groups"
            echo ""
            
            for group in /sys/kernel/iommu_groups/*; do
                if [ -d "$group" ]; then
                    group_num=$(basename "$group")
                    echo "--- IOMMU Group $group_num ---"
                    
                    for device in "$group"/devices/*; do
                        if [ -e "$device" ]; then
                            dev_path=$(basename "$device")
                            
                            # Get device info from lspci
                            if lspci -nn -s "$dev_path" > /dev/null 2>&1; then
                                lspci -nn -s "$dev_path"
                            else
                                echo "$dev_path (non-PCI device)"
                            fi
                            
                            # Check if VFIO driver is loaded
                            if [ -e "$device/driver" ]; then
                                driver=$(readlink "$device/driver" | xargs basename)
                                echo "  Driver: $driver"
                            else
                                echo "  Driver: (none)"
                            fi
                        fi
                    done
                    echo ""
                fi
            done
        else
            echo "✗ No IOMMU groups found"
            echo "   This usually means IOMMU is not properly enabled"
        fi
    else
        echo "✗ /sys/kernel/iommu_groups directory not found"
        echo "   IOMMU is not active on this system"
    fi
    echo ""
    
    echo "========================================"
    echo "NETWORK DEVICES (for passthrough)"
    echo "========================================"
    echo "Intel Ethernet devices:"
    lspci -nn | grep -i ethernet | grep -i intel || echo "No Intel Ethernet devices found"
    echo ""
    
    echo "All Ethernet devices:"
    lspci -nn | grep -i ethernet || echo "No Ethernet devices found"
    echo ""
    
    echo "========================================"
    echo "USB CONTROLLERS (for passthrough)"
    echo "========================================"
    lspci -nn | grep -i usb || echo "No USB controllers found via PCI"
    echo ""
    
    echo "========================================"
    echo "OTHER PCIe DEVICES"
    echo "========================================"
    lspci -nn | grep -vE "(Host bridge|ISA bridge|SMBus|SATA|IDE)" | head -20
    echo ""
    
    echo "========================================"
    echo "VFIO DRIVER STATUS"
    echo "========================================"
    echo "Loaded VFIO modules:"
    lsmod | grep vfio || echo "No VFIO modules loaded"
    echo ""
    
    echo "Available VFIO modules:"
    modinfo vfio 2>/dev/null | grep "^filename:" || echo "vfio module not found"
    modinfo vfio_pci 2>/dev/null | grep "^filename:" || echo "vfio_pci module not found"
    echo ""
    
    echo "========================================"
    echo "IOMMU DEVICE ASSIGNMENT COMPATIBILITY"
    echo "========================================"
    echo "Checking for devices in isolated IOMMU groups..."
    echo "(Single-device groups are ideal for passthrough)"
    echo ""
    
    if [ -d /sys/kernel/iommu_groups ]; then
        for group in /sys/kernel/iommu_groups/*; do
            if [ -d "$group" ]; then
                group_num=$(basename "$group")
                device_count=$(find "$group/devices" -maxdepth 1 -type l | wc -l)
                
                if [ $device_count -eq 1 ]; then
                    echo "✓ Group $group_num has 1 device (ideal for passthrough)"
                    for device in "$group"/devices/*; do
                        dev_path=$(basename "$device")
                        lspci -nn -s "$dev_path" 2>/dev/null | head -1
                    done
                elif [ $device_count -gt 1 ] && [ $device_count -le 3 ]; then
                    echo "⚠ Group $group_num has $device_count devices (possible, may need to pass entire group)"
                fi
            fi
        done
    fi
    echo ""
    
    echo "========================================"
    echo "VERIFICATION SUMMARY"
    echo "========================================"
    
    PASS_COUNT=0
    FAIL_COUNT=0
    
    if grep -qE "(intel_iommu=on|amd_iommu=on)" /proc/cmdline; then
        echo "✓ PASS: IOMMU enabled in kernel"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "✗ FAIL: IOMMU not enabled in kernel"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    if [ -d /sys/kernel/iommu_groups ]; then
        GROUP_COUNT=$(find /sys/kernel/iommu_groups -maxdepth 1 -type d | wc -l)
        GROUP_COUNT=$((GROUP_COUNT - 1))
        
        if [ $GROUP_COUNT -gt 0 ]; then
            echo "✓ PASS: IOMMU groups present ($GROUP_COUNT groups)"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo "✗ FAIL: No IOMMU groups found"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo "✗ FAIL: IOMMU groups directory not found"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    echo ""
    echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
    
    if [ $FAIL_COUNT -eq 0 ]; then
        echo "✓✓✓ IOMMU READY FOR DEVICE PASSTHROUGH ✓✓✓"
    else
        echo "⚠⚠⚠ IOMMU NOT READY - Review configuration ⚠⚠⚠"
    fi
    echo ""
    
} > "$OUTPUT_FILE" 2>&1

echo "✓ IOMMU verification complete"
echo "✓ Output saved to: $OUTPUT_FILE"
echo ""

# Display summary
echo "Summary:"
grep "Results:" "$OUTPUT_FILE"
if grep -q "IOMMU groups present" "$OUTPUT_FILE"; then
    grep "IOMMU groups present" "$OUTPUT_FILE"
fi
echo ""
echo "Review full report: cat $OUTPUT_FILE"
echo ""

