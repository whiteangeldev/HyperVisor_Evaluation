#!/bin/bash
#
# Script: 18_pre_acrn_check.sh
# Purpose: Pre-installation check for Intel ACRN requirements
# Usage: ./18_pre_acrn_check.sh
#

# Note: Using 'set -e' but with safe increment syntax to avoid early exit
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
OUTPUT_FILE="$LOG_DIR/acrn_pre_check.log"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "Intel ACRN Pre-Installation Check"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

{
    echo "========================================"
    echo "INTEL ACRN PRE-INSTALLATION CHECK"
    echo "========================================"
    echo "Check Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo ""
    
    PASS_COUNT=0
    FAIL_COUNT=0
    WARN_COUNT=0
    
    echo "========================================"
    echo "1. CPU VENDOR CHECK"
    echo "========================================"
    if grep -q "GenuineIntel" /proc/cpuinfo; then
        echo "✓ PASS: Intel CPU detected"
        grep "model name" /proc/cpuinfo | head -1
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "✗ FAIL: Intel CPU NOT detected"
        echo "   ACRN requires Intel processors"
        grep "model name" /proc/cpuinfo | head -1 || echo "CPU info not available"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    echo ""
    
    echo "========================================"
    echo "2. VIRTUALIZATION SUPPORT (VT-x)"
    echo "========================================"
    if grep -q "vmx" /proc/cpuinfo; then
        echo "✓ PASS: VT-x (vmx) flag present"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "✗ FAIL: VT-x (vmx) flag NOT found"
        echo "   Enable VT-x in BIOS"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    echo ""
    
    echo "========================================"
    echo "3. IOMMU/VT-d SUPPORT"
    echo "========================================"
    if dmesg | grep -qi "DMAR.*IOMMU enabled"; then
        echo "✓ PASS: IOMMU enabled"
        dmesg | grep -i "DMAR" | head -5
        PASS_COUNT=$((PASS_COUNT + 1))
    elif grep -qE "(intel_iommu=on)" /proc/cmdline; then
        echo "⚠ WARNING: IOMMU parameter present but not confirmed in dmesg"
        WARN_COUNT=$((WARN_COUNT + 1))
    else
        echo "✗ FAIL: IOMMU not enabled"
        echo "   Add intel_iommu=on to kernel parameters"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    echo ""
    
    echo "========================================"
    echo "4. CPU CORES AVAILABILITY"
    echo "========================================"
    TOTAL_CPUS=$(nproc)
    echo "Total CPUs: $TOTAL_CPUS"
    
    if [ $TOTAL_CPUS -ge 4 ]; then
        echo "✓ PASS: Sufficient CPUs for ACRN (minimum 4 recommended)"
        echo "   Recommended allocation:"
        echo "   - Service VM (SOS): CPUs 0-1"
        echo "   - RT VM (UOS): CPUs 2-3"
        echo "   - GPOS VM (UOS): CPUs 4-7"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "⚠ WARNING: Limited CPUs ($TOTAL_CPUS cores)"
        echo "   ACRN will work but with limited isolation"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi
    echo ""
    
    echo "========================================"
    echo "5. MEMORY AVAILABILITY"
    echo "========================================"
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
    
    echo "Total Memory: ${TOTAL_MEM_GB} GB"
    
    if [ $TOTAL_MEM_GB -ge 8 ]; then
        echo "✓ PASS: Sufficient memory (8GB+ recommended)"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif [ $TOTAL_MEM_GB -ge 4 ]; then
        echo "⚠ WARNING: Limited memory (${TOTAL_MEM_GB} GB)"
        echo "   8GB+ recommended for ACRN with multiple VMs"
        WARN_COUNT=$((WARN_COUNT + 1))
    else
        echo "✗ FAIL: Insufficient memory (${TOTAL_MEM_GB} GB)"
        echo "   4GB minimum, 8GB+ recommended"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    echo ""
    
    echo "========================================"
    echo "6. KERNEL VERSION"
    echo "========================================"
    KERNEL_VERSION=$(uname -r)
    KERNEL_MAJOR=$(echo "$KERNEL_VERSION" | cut -d. -f1)
    KERNEL_MINOR=$(echo "$KERNEL_VERSION" | cut -d. -f2)
    
    echo "Current kernel: $KERNEL_VERSION"
    
    # ACRN typically requires kernel 5.4+
    if [ $KERNEL_MAJOR -ge 5 ] && [ $KERNEL_MINOR -ge 4 ]; then
        echo "✓ PASS: Kernel version compatible (5.4+ recommended)"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif [ $KERNEL_MAJOR -ge 5 ]; then
        echo "⚠ WARNING: Kernel version may work but 5.4+ recommended"
        WARN_COUNT=$((WARN_COUNT + 1))
    else
        echo "⚠ WARNING: Kernel version may need upgrade"
        echo "   ACRN recommends kernel 5.4 or newer"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi
    echo ""
    
    echo "========================================"
    echo "7. DISK SPACE"
    echo "========================================"
    AVAIL_SPACE=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
    
    echo "Available space on /: ${AVAIL_SPACE} GB"
    
    if [ $AVAIL_SPACE -ge 20 ]; then
        echo "✓ PASS: Sufficient disk space"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif [ $AVAIL_SPACE -ge 10 ]; then
        echo "⚠ WARNING: Limited disk space"
        echo "   20GB+ recommended"
        WARN_COUNT=$((WARN_COUNT + 1))
    else
        echo "✗ FAIL: Insufficient disk space"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    echo ""
    
    echo "========================================"
    echo "8. NETWORK INTERFACES"
    echo "========================================"
    NIC_COUNT=$(ip link show | grep "^[0-9]:" | grep -v "lo:" | wc -l)
    
    echo "Network interfaces: $NIC_COUNT"
    ip link show | grep "^[0-9]:" | grep -v "lo:"
    echo ""
    
    if [ $NIC_COUNT -ge 2 ]; then
        echo "✓ PASS: Multiple NICs available for passthrough"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif [ $NIC_COUNT -ge 1 ]; then
        echo "⚠ WARNING: Only one NIC available"
        echo "   Multiple NICs recommended for VM passthrough"
        WARN_COUNT=$((WARN_COUNT + 1))
    else
        echo "✗ FAIL: No network interfaces found"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    echo ""
    
    echo "========================================"
    echo "9. REQUIRED PACKAGES"
    echo "========================================"
    echo "Checking for build dependencies..."
    
    REQUIRED_PKGS=(
        "build-essential"
        "git"
        "make"
        "gcc"
        "libssl-dev"
        "libpciaccess-dev"
        "uuid-dev"
        "libsystemd-dev"
        "libevent-dev"
        "libxml2-dev"
        "libusb-1.0-0-dev"
        "python3"
        "python3-pip"
    )
    
    MISSING_PKGS=()
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if dpkg -l | grep -q "^ii  $pkg"; then
            echo "  ✓ $pkg"
        else
            echo "  ✗ $pkg (missing)"
            MISSING_PKGS+=("$pkg")
        fi
    done
    
    if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
        echo "✓ PASS: All required packages installed"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "⚠ WARNING: ${#MISSING_PKGS[@]} package(s) missing"
        echo "   Install with: sudo apt install ${MISSING_PKGS[*]}"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi
    echo ""
    
    echo "========================================"
    echo "10. EXISTING HYPERVISORS"
    echo "========================================"
    echo "Checking for conflicting hypervisors..."
    
    CONFLICTS=0
    
    if command -v xl &> /dev/null && xl info &> /dev/null; then
        echo "⚠ Xen hypervisor is currently running"
        echo "   Note: Cannot run ACRN and Xen simultaneously"
        CONFLICTS=$((CONFLICTS + 1))
    fi
    
    if lsmod | grep -q "^kvm_intel"; then
        echo "⚠ KVM module loaded"
        echo "   Note: ACRN replaces KVM functionality"
        CONFLICTS=$((CONFLICTS + 1))
    fi
    
    if [ $CONFLICTS -eq 0 ]; then
        echo "✓ No conflicting hypervisors detected"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "⚠ WARNING: $CONFLICTS potential conflict(s) found"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi
    echo ""
    
    echo "========================================"
    echo "SUMMARY"
    echo "========================================"
    echo "Passed:   $PASS_COUNT"
    echo "Warnings: $WARN_COUNT"
    echo "Failed:   $FAIL_COUNT"
    echo ""
    
    TOTAL=$((PASS_COUNT + WARN_COUNT + FAIL_COUNT))
    if [ $TOTAL -gt 0 ]; then
        SCORE=$((PASS_COUNT * 100 / TOTAL))
        echo "Score: $SCORE%"
    fi
    echo ""
    
    if [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -le 2 ]; then
        echo "✓✓✓ SYSTEM READY FOR ACRN INSTALLATION ✓✓✓"
        echo ""
        echo "Next steps:"
        echo "1. Install dependencies: sudo ./scripts/19_install_acrn_deps.sh"
        echo "2. Download ACRN: ./scripts/20_download_acrn.sh"
        echo "3. Build ACRN: ./scripts/21_build_acrn.sh"
        echo "4. Install ACRN: sudo ./scripts/22_install_acrn.sh"
    elif [ $FAIL_COUNT -eq 0 ]; then
        echo "⚠⚠⚠ SYSTEM MOSTLY READY - ADDRESS WARNINGS ⚠⚠⚠"
        echo ""
        echo "Review warnings above and proceed with caution"
    else
        echo "✗✗✗ SYSTEM NOT READY - FIX CRITICAL ISSUES ✗✗✗"
        echo ""
        echo "Address failed checks before proceeding"
    fi
    echo ""
    
} > "$OUTPUT_FILE" 2>&1

echo "✓ ACRN pre-installation check complete"
echo "✓ Output saved to: $OUTPUT_FILE"
echo ""

# Display summary
echo "Summary:"
grep "^Passed:" "$OUTPUT_FILE"
grep "^Warnings:" "$OUTPUT_FILE"
grep "^Failed:" "$OUTPUT_FILE"
echo ""
echo "Review full report: cat $OUTPUT_FILE"
echo ""

