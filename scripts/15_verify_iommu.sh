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
            echo ""
            echo "========================================" 
            echo "TROUBLESHOOTING: NO IOMMU GROUPS"
            echo "========================================"
            echo ""
            echo "This means IOMMU is not properly initialized."
            echo ""
            echo "STEP 1: Check BIOS Settings"
            echo "  ⚠️  CRITICAL: Enable these in BIOS/UEFI:"
            echo "     - Intel VT-x (Virtualization Technology)"
            echo "     - Intel VT-d (Virtualization for Directed I/O)"
            echo "  Common locations:"
            echo "     - Advanced → CPU Configuration"
            echo "     - Advanced → Chipset Configuration"
            echo "     - Security → Virtualization"
            echo ""
            echo "STEP 2: Verify Kernel Parameters"
            echo "  Current cmdline:"
            cat /proc/cmdline
            echo ""
            echo "  Required: intel_iommu=on iommu=pt"
            if ! grep -qE "(intel_iommu=on|amd_iommu=on)" /proc/cmdline; then
                echo "  ✗ MISSING: intel_iommu=on parameter"
                echo ""
                echo "  To fix:"
                echo "    cd ~/rt-hypervisor-poc/scripts"
                echo "    ./04_generate_grub_config.sh"
                echo "    sudo ./05_update_grub.sh"
                echo "    sudo reboot"
            fi
            echo ""
            echo "STEP 3: Check dmesg for IOMMU errors"
            if dmesg | grep -i "iommu" > /dev/null 2>&1; then
                dmesg | grep -i "iommu" | tail -15
            else
                echo "  No IOMMU messages in dmesg (hardware may not support it)"
            fi
            echo ""
            echo "STEP 4: Verify Hardware Support"
            if grep -q "vmx\|svm" /proc/cpuinfo; then
                echo "  ✓ CPU supports virtualization"
            else
                echo "  ✗ CPU does not support virtualization"
            fi
            echo ""
            echo "STEP 5: Check if running under Xen"
            if command -v xl &> /dev/null && xl info &> /dev/null 2>&1; then
                XL_CMD="xl"
                [ "$EUID" -ne 0 ] && XL_CMD="sudo xl"
                echo "  ✓ Running under Xen hypervisor"
                echo "  NOTE: Under Xen, IOMMU groups may not appear in Dom0 sysfs"
                echo "  Check Xen's IOMMU status instead:"
                echo ""
                $XL_CMD dmesg 2>/dev/null | grep -i iommu | head -20 || echo "  Cannot query Xen (requires sudo)"
            else
                echo "  Not running under Xen"
            fi
            echo ""
        fi
    else
        echo "✗ /sys/kernel/iommu_groups directory not found"
        echo ""
        echo "========================================" 
        echo "TROUBLESHOOTING: IOMMU NOT ACTIVE"
        echo "========================================"
        echo ""
        echo "IOMMU is NOT active on this system. This means:"
        echo "  - Device passthrough will NOT work"
        echo "  - VMs cannot have direct device access"
        echo ""
        echo "REQUIRED FIXES (in order):"
        echo ""
        echo "1. Enable VT-d in BIOS/UEFI"
        echo "   ⚠️  THIS IS THE MOST COMMON ISSUE"
        echo "   - Reboot and enter BIOS (usually Del, F2, or F10)"
        echo "   - Look for 'Intel VT-d' or 'Virtualization for Directed I/O'"
        echo "   - Set to ENABLED"
        echo "   - Also enable 'Intel VT-x' if not already enabled"
        echo "   - Save and exit BIOS"
        echo ""
        echo "2. Verify kernel parameters include:"
        echo "   intel_iommu=on iommu=pt"
        echo ""
        echo "   Current parameters:"
        cat /proc/cmdline
        echo ""
        if ! grep -qE "(intel_iommu=on|amd_iommu=on)" /proc/cmdline; then
            echo "   ✗ MISSING intel_iommu=on parameter"
            echo ""
            echo "   To add kernel parameters:"
            echo "     cd ~/rt-hypervisor-poc/scripts"
            echo "     ./04_generate_grub_config.sh"
            echo "     sudo ./05_update_grub.sh"
            echo "     sudo reboot"
        fi
        echo ""
        echo "3. Check dmesg for IOMMU hardware detection:"
        if dmesg | grep -i "iommu" > /dev/null 2>&1; then
            dmesg | grep -i "iommu" | grep -i "detected\|enabled\|disabled\|error" | tail -10
        else
            echo "   No IOMMU messages found - hardware may not support VT-d"
            echo "   Check: grep -E 'vmx|svm' /proc/cpuinfo"
        fi
        echo ""
        echo "4. If running under Xen hypervisor:"
        if command -v xl &> /dev/null; then
            XL_CMD="xl"
            [ "$EUID" -ne 0 ] && XL_CMD="sudo xl"
            if $XL_CMD info &> /dev/null 2>&1; then
                echo "   ✓ Xen is running"
                echo "   Under Xen, check IOMMU status with:"
                echo "     sudo xl dmesg | grep -i iommu"
                echo ""
                $XL_CMD dmesg 2>/dev/null | grep -i iommu | head -20 || echo "   (requires sudo to view)"
            fi
        else
            echo "   Xen not detected"
        fi
        echo ""
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

