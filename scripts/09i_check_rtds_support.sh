#!/bin/bash
#
# Script: 09i_check_rtds_support.sh
# Purpose: Check if RTDS scheduler is actually supported
# Usage: sudo ./09i_check_rtds_support.sh
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Run as: sudo $0"
    exit 1
fi

echo "=========================================="
echo "Check RTDS Scheduler Support"
echo "=========================================="
echo ""

echo "1. Current Scheduler"
echo "=========================================="
xl info | grep xen_scheduler
echo ""

echo "2. Check RTDS Command"
echo "=========================================="
echo "Testing xl sched-rtds command..."
if xl sched-rtds 2>&1 | grep -q "not supported\|invalid option"; then
    echo "❌ RTDS scheduler commands not fully supported"
    RTDS_CMD_WORKS=false
else
    echo "✓ RTDS commands available"
    RTDS_CMD_WORKS=true
fi
echo ""

echo "3. Available Schedulers"
echo "=========================================="
echo "Checking Xen capabilities..."
xl info | grep -i sched
echo ""

echo "4. Xen Command Line"
echo "=========================================="
xl dmesg | grep "Command line:" || cat /sys/hypervisor/properties/xen_commandline
echo ""

echo "5. Check Xen Build Config"
echo "=========================================="
if [ -f /boot/xen-4.17-amd64.config ]; then
    echo "Xen configuration file found."
    grep -i "sched" /boot/xen-4.17-amd64.config | grep -v "^#"
else
    echo "No config file found"
fi
echo ""

echo "6. Try Creating RTDS CPU Pool"
echo "=========================================="
echo "Attempting to create RTDS cpupool..."
if xl cpupool-create name=\"rtds-pool\" sched=\"rtds\" 2>&1; then
    echo "✓ RTDS cpupool created!"
    xl cpupool-list
    echo ""
    echo "Destroying test pool..."
    xl cpupool-destroy rtds-pool
    RTDS_AVAILABLE=true
else
    echo "❌ Cannot create RTDS cpupool"
    echo "   RTDS scheduler not available in this Xen build"
    RTDS_AVAILABLE=false
fi
echo ""

echo "7. Check Xen Version and Scheduler Support"
echo "=========================================="
XEN_VERSION=$(xl info | grep "xen_version" | awk '{print $3}')
echo "Xen Version: $XEN_VERSION"
echo ""
echo "Known scheduler support for Xen 4.17:"
echo "  - credit  : Yes (legacy)"
echo "  - credit2 : Yes (default)"
echo "  - rtds    : Yes (if compiled)"
echo "  - null    : Yes"
echo ""

echo "=========================================="
echo "DIAGNOSIS"
echo "=========================================="
echo ""

if [ "$RTDS_AVAILABLE" = true ]; then
    echo "✓ RTDS is compiled and available!"
    echo ""
    echo "The issue is that sched=rtds boot parameter isn't working."
    echo ""
    echo "SOLUTION: Use cpupools instead"
    echo ""
    echo "Method: Create RT cpupool with RTDS scheduler"
    echo "  1. Boot with default scheduler (credit2)"
    echo "  2. Create RTDS cpupool for RT VMs"
    echo "  3. Move RT VMs to RTDS cpupool"
    echo ""
    echo "This is actually BETTER than global RTDS because:"
    echo "  - Dom0 runs on credit2 (better for housekeeping)"
    echo "  - RT VMs run on RTDS (hard real-time)"
    echo "  - More flexible CPU partitioning"
    echo ""
else
    echo "❌ RTDS NOT AVAILABLE in this Xen build"
    echo ""
    echo "Possible reasons:"
    echo "  1. Ubuntu's Xen package doesn't include RTDS"
    echo "  2. RTDS disabled in build config"
    echo "  3. Xen version issue"
    echo ""
    echo "SOLUTIONS:"
    echo ""
    echo "Option A: Use Credit2 with RT tuning"
    echo "  - Credit2 can provide good RT performance"
    echo "  - Configure rate limit and vCPU caps"
    echo "  - Acceptable for soft RT (< 100μs)"
    echo ""
    echo "Option B: Build Xen from source with RTDS"
    echo "  - Compile Xen with SCHED_RTDS=y"
    echo "  - Time consuming but gives full control"
    echo ""
    echo "Option C: Use Intel ACRN instead"
    echo "  - Native RT design"
    echo "  - Better for hard RT requirements"
    echo ""
fi

echo "=========================================="
echo "RECOMMENDATION"
echo "=========================================="
echo ""

if [ "$RTDS_AVAILABLE" = true ]; then
    echo "PROCEED WITH CPUPOOL METHOD"
    echo ""
    echo "Run: sudo ./scripts/10_setup_rtds_cpupool.sh"
else
    echo "Option 1: Try Credit2 RT tuning (quickest)"
    echo "  - Credit2 with proper settings can work"
    echo "  - Good enough for many RT workloads"
    echo ""
    echo "Option 2: Switch to Intel ACRN"
    echo "  - Already have scripts ready"
    echo "  - Native hard RT support"
    echo "  - Run: ./scripts/26_master_setup_acrn.sh"
    echo ""
    echo "Option 3: Build custom Xen with RTDS"
    echo "  - Most control, most effort"
    echo "  - Only if you need Xen specifically"
fi
echo ""

