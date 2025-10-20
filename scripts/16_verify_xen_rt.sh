#!/bin/bash
#
# Script: 16_verify_xen_rt.sh
# Purpose: Verify Xen RT scheduler configuration
# Usage: ./16_verify_xen_rt.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
OUTPUT_FILE="$LOG_DIR/xen_rt_verification.log"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "Xen RT Scheduler Verification"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

{
    echo "========================================"
    echo "XEN RT SCHEDULER VERIFICATION"
    echo "========================================"
    echo "Verification Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo ""
    
    echo "========================================"
    echo "XEN HYPERVISOR STATUS"
    echo "========================================"
    if xl info > /dev/null 2>&1; then
        echo "✓ Xen hypervisor is running"
        echo ""
        xl info | grep -E "(xen_version|xen_scheduler|nr_cpus|cpu_mhz|total_memory)"
    else
        echo "✗ Xen hypervisor is NOT running"
        echo "   This system appears to be running standard Linux kernel"
        exit 1
    fi
    echo ""
    
    echo "========================================"
    echo "XEN SCHEDULER INFORMATION"
    echo "========================================"
    SCHEDULER=$(xl info | grep xen_scheduler | awk '{print $3}')
    echo "Current Scheduler: $SCHEDULER"
    echo ""
    
    case "$SCHEDULER" in
        rtds)
            echo "✓ RTDS (Real-Time Deferrable Server) scheduler is active"
            echo "  This is the optimal scheduler for hard real-time workloads"
            ;;
        credit2)
            echo "⚠ Credit2 scheduler is active"
            echo "  This is suitable for soft real-time but not optimal for hard RT"
            echo "  Credit2 provides better CPU isolation than Credit scheduler"
            ;;
        credit)
            echo "⚠ Credit scheduler is active"
            echo "  Consider switching to Credit2 or RTDS for better RT performance"
            ;;
        *)
            echo "⚠ Unknown scheduler: $SCHEDULER"
            ;;
    esac
    echo ""
    
    echo "========================================"
    echo "DOM0 VCPU CONFIGURATION"
    echo "========================================"
    DOM0_VCPUS=$(xl info | grep nr_cpus | awk '{print $3}')
    echo "Dom0 vCPUs: $DOM0_VCPUS"
    echo ""
    
    echo "Physical CPU allocation (from kernel cmdline):"
    if grep -o "dom0_max_vcpus=[^ ]*" /proc/cmdline; then
        echo "✓ Dom0 vCPU limit configured"
    else
        echo "⚠ Dom0 vCPU limit not explicitly set"
    fi
    
    if grep -o "dom0_vcpus_pin=[^ ]*" /proc/cmdline; then
        echo "✓ Dom0 vCPU pinning configured"
    else
        echo "⚠ Dom0 vCPU pinning not configured"
    fi
    echo ""
    
    echo "========================================"
    echo "XEN CPUPOOL INFORMATION"
    echo "========================================"
    if xl cpupool-list > /dev/null 2>&1; then
        echo "CPU Pools:"
        xl cpupool-list
        echo ""
        
        # Show detailed cpupool info
        for pool in $(xl cpupool-list | tail -n +2 | awk '{print $1}'); do
            echo "--- CPU Pool: $pool ---"
            xl cpupool-cpu-list "$pool" 2>/dev/null || echo "Cannot list CPUs for pool $pool"
            echo ""
        done
    else
        echo "⚠ Cannot query CPU pools"
    fi
    echo ""
    
    echo "========================================"
    echo "DOM0 MEMORY CONFIGURATION"
    echo "========================================"
    if grep -o "dom0_mem=[^ ]*" /proc/cmdline; then
        echo "✓ Dom0 memory limit configured"
        grep -o "dom0_mem=[^ ]*" /proc/cmdline
    else
        echo "⚠ Dom0 memory not explicitly limited"
        echo "  Recommend setting dom0_mem for better isolation"
    fi
    
    echo ""
    echo "Current Dom0 memory usage:"
    free -h | head -2
    echo ""
    
    echo "========================================"
    echo "XEN COMMAND LINE PARAMETERS"
    echo "========================================"
    if [ -f /proc/xen/xsd_port ]; then
        echo "Xen command line from kernel:"
        cat /proc/cmdline | tr ' ' '\n' | grep -E "(sched=|dom0_)" || echo "No Xen-specific parameters found"
    fi
    echo ""
    
    echo "========================================"
    echo "RUNNING DOMAINS"
    echo "========================================"
    if xl list > /dev/null 2>&1; then
        xl list
    else
        echo "⚠ Cannot list domains"
    fi
    echo ""
    
    echo "========================================"
    echo "XEN BOOT PARAMETERS (from GRUB)"
    echo "========================================"
    echo "Checking /etc/default/grub.d/xen.cfg:"
    if [ -f /etc/default/grub.d/xen.cfg ]; then
        cat /etc/default/grub.d/xen.cfg | grep -v "^#" | grep -v "^$"
    else
        echo "⚠ /etc/default/grub.d/xen.cfg not found"
    fi
    echo ""
    
    echo "========================================"
    echo "VERIFICATION SUMMARY"
    echo "========================================"
    
    PASS_COUNT=0
    WARN_COUNT=0
    FAIL_COUNT=0
    
    # Check if Xen is running
    if xl info > /dev/null 2>&1; then
        echo "✓ PASS: Xen hypervisor is running"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "✗ FAIL: Xen hypervisor is NOT running"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Check scheduler
    if [ "$SCHEDULER" = "rtds" ]; then
        echo "✓ PASS: RTDS scheduler active (optimal for hard RT)"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif [ "$SCHEDULER" = "credit2" ]; then
        echo "⚠ NOTE: Credit2 scheduler active (suitable for soft RT)"
        WARN_COUNT=$((WARN_COUNT + 1))
    else
        echo "⚠ WARN: Non-RT scheduler active ($SCHEDULER)"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi
    
    # Check Dom0 vCPU configuration
    if grep -q "dom0_max_vcpus" /proc/cmdline; then
        echo "✓ PASS: Dom0 vCPU limit configured"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "⚠ WARN: Dom0 vCPU limit not configured"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi
    
    # Check Dom0 vCPU pinning
    if grep -q "dom0_vcpus_pin" /proc/cmdline; then
        echo "✓ PASS: Dom0 vCPU pinning configured"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "⚠ WARN: Dom0 vCPU pinning not configured"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi
    
    # Check Dom0 memory limit
    if grep -q "dom0_mem" /proc/cmdline; then
        echo "✓ PASS: Dom0 memory limit configured"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "⚠ WARN: Dom0 memory limit not configured"
        WARN_COUNT=$((WARN_COUNT + 1))
    fi
    
    echo ""
    echo "Results: $PASS_COUNT passed, $WARN_COUNT warnings, $FAIL_COUNT failed"
    
    if [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
        echo "✓✓✓ XEN RT CONFIGURATION OPTIMAL ✓✓✓"
    elif [ $FAIL_COUNT -eq 0 ]; then
        echo "✓ Xen is configured and running with minor warnings"
    else
        echo "✗✗✗ CRITICAL ISSUES DETECTED ✗✗✗"
    fi
    echo ""
    
} > "$OUTPUT_FILE" 2>&1

echo "✓ Xen RT verification complete"
echo "✓ Output saved to: $OUTPUT_FILE"
echo ""

# Display summary
echo "Summary:"
grep "Results:" "$OUTPUT_FILE"
grep "scheduler" "$OUTPUT_FILE" | grep -E "(RTDS|Credit2|Credit)" | head -1
echo ""
echo "Review full report: cat $OUTPUT_FILE"
echo ""

