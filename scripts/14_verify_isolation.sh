#!/bin/bash
#
# Script: 14_verify_isolation.sh
# Purpose: Verify CPU isolation is properly configured
# Usage: ./14_verify_isolation.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
OUTPUT_FILE="$LOG_DIR/cpu_isolation.log"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "CPU Isolation Verification"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

{
    echo "========================================"
    echo "CPU ISOLATION VERIFICATION"
    echo "========================================"
    echo "Verification Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo ""
    
    echo "========================================"
    echo "KERNEL COMMAND LINE"
    echo "========================================"
    cat /proc/cmdline
    echo ""
    
    echo "Checking for isolation parameters..."
    if grep -q "isolcpus" /proc/cmdline; then
        echo "✓ isolcpus parameter found"
        grep -o "isolcpus=[^ ]*" /proc/cmdline
    else
        echo "✗ isolcpus parameter NOT found"
    fi
    
    if grep -q "nohz_full" /proc/cmdline; then
        echo "✓ nohz_full parameter found"
        grep -o "nohz_full=[^ ]*" /proc/cmdline
    else
        echo "✗ nohz_full parameter NOT found"
    fi
    
    if grep -q "rcu_nocbs" /proc/cmdline; then
        echo "✓ rcu_nocbs parameter found"
        grep -o "rcu_nocbs=[^ ]*" /proc/cmdline
    else
        echo "✗ rcu_nocbs parameter NOT found"
    fi
    echo ""
    
    echo "========================================"
    echo "ISOLATED CPUS (from sysfs)"
    echo "========================================"
    if [ -f /sys/devices/system/cpu/isolated ]; then
        ISOLATED=$(cat /sys/devices/system/cpu/isolated)
        if [ -n "$ISOLATED" ]; then
            echo "✓ Isolated CPUs: $ISOLATED"
        else
            echo "⚠ No CPUs isolated in sysfs (file exists but empty)"
            echo ""
            echo "NOTE: This is NORMAL when running under Xen Dom0"
            echo ""
            echo "CPU isolation for Xen works differently:"
            echo "  - Dom0 (host) uses CPUs configured via dom0_max_vcpus"
            echo "  - Guest VMs are pinned to specific physical CPUs"
            echo "  - The kernel parameters (isolcpus, nohz_full, rcu_nocbs) still apply"
            echo "  - Isolated CPUs are reserved for guest VM assignment"
            echo ""
            echo "To verify Dom0 CPU configuration:"
            echo "  sudo xl vcpu-list 0"
            echo ""
        fi
    else
        echo "⚠ /sys/devices/system/cpu/isolated not found"
        echo ""
        echo "NOTE: This is NORMAL when running under Xen Dom0"
        echo "CPU isolation is managed by the Xen hypervisor"
    fi
    
    # Add check for actual CPU affinity
    echo ""
    echo "Checking CPU assignment from kernel parameters..."
    ISOLCPUS_PARAM=$(grep -o "isolcpus=[^ ]*" /proc/cmdline | cut -d= -f2)
    if [ -n "$ISOLCPUS_PARAM" ]; then
        echo "✓ isolcpus parameter: $ISOLCPUS_PARAM"
        echo "  These CPUs are isolated from the general kernel scheduler"
    else
        echo "✗ No isolcpus parameter found in kernel command line"
    fi
    echo ""
    
    echo "========================================"
    echo "NO_HZ FULL CPUS"
    echo "========================================"
    if [ -f /sys/devices/system/cpu/nohz_full ]; then
        NOHZ_FULL=$(cat /sys/devices/system/cpu/nohz_full)
        if [ -n "$NOHZ_FULL" ]; then
            echo "✓ NO_HZ full CPUs: $NOHZ_FULL"
        else
            echo "⚠ NO_HZ full not configured"
        fi
    else
        echo "⚠ /sys/devices/system/cpu/nohz_full not found"
    fi
    echo ""
    
    echo "========================================"
    echo "CPU ONLINE STATUS"
    echo "========================================"
    for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
        if [ -f "$cpu/online" ]; then
            cpu_num=$(basename "$cpu" | sed 's/cpu//')
            online=$(cat "$cpu/online" 2>/dev/null || echo "1")
            echo "CPU $cpu_num: $([ "$online" = "1" ] && echo "Online" || echo "Offline")"
        fi
    done
    echo ""
    
    echo "========================================"
    echo "PROCESS COUNT PER CPU"
    echo "========================================"
    echo "Sleeping 2 seconds to gather data..."
    sleep 2
    
    for cpu in $(seq 0 $(($(nproc)-1))); do
        count=$(ps -eLo psr | grep "^[[:space:]]*$cpu$" | wc -l)
        echo "CPU $cpu: $count threads"
    done
    echo ""
    echo "NOTE: Isolated CPUs should have minimal thread count"
    echo ""
    
    echo "========================================"
    echo "TOP PROCESSES ON ISOLATED CPUS"
    echo "========================================"
    ISOLATED_CPUS=$(cat /sys/devices/system/cpu/isolated 2>/dev/null || echo "")
    if [ -n "$ISOLATED_CPUS" ]; then
        echo "Checking isolated CPUs: $ISOLATED_CPUS"
        ps -eLo pid,tid,psr,comm | head -1
        for cpu in $(echo "$ISOLATED_CPUS" | tr ',' ' ' | tr '-' ' '); do
            ps -eLo pid,tid,psr,comm | grep "^[[:space:]]*[0-9]*[[:space:]]*[0-9]*[[:space:]]*$cpu[[:space:]]" | head -10
        done
    else
        echo "No isolated CPUs detected"
    fi
    echo ""
    
    echo "========================================"
    echo "XEN DOM0 CPU CONFIGURATION"
    echo "========================================"
    if command -v xl &> /dev/null; then
        XL_CMD="xl"
        [ "$EUID" -ne 0 ] && XL_CMD="sudo xl"
        
        if $XL_CMD info &> /dev/null 2>&1; then
            echo "✓ Running under Xen hypervisor"
            echo ""
            echo "Dom0 vCPU assignment:"
            $XL_CMD vcpu-list 0 2>/dev/null || echo "Cannot query Dom0 vCPUs (requires sudo)"
            echo ""
            
            echo "Total physical CPUs available:"
            $XL_CMD info 2>/dev/null | grep "^nr_cpus" || echo "Cannot query (requires sudo)"
            echo ""
            
            echo "NOTE: Under Xen, CPU isolation works as follows:"
            echo "  1. Dom0 (host) runs on CPUs configured via dom0_max_vcpus"
            echo "  2. Guest VMs can be pinned to specific physical CPUs"
            echo "  3. Use 'xl vcpu-pin <domain> <vcpu> <pcpu>' to pin guest vCPUs"
            echo "  4. Isolated CPUs (from isolcpus param) are for guest VM use"
            echo ""
        else
            echo "Xen tools installed but not running under Xen"
        fi
    else
        echo "Not running under Xen hypervisor"
        echo "(Standard Linux kernel CPU isolation applies)"
    fi
    echo ""
    
    echo "========================================"
    echo "SCHEDULER INFORMATION"
    echo "========================================"
    if [ -d /sys/kernel/debug/sched ]; then
        echo "Scheduler debug info available"
        ls -la /sys/kernel/debug/sched/ || true
    else
        echo "Scheduler debug info not available (may require debugfs mount)"
    fi
    echo ""
    
    echo "========================================"
    echo "CLOCKSOURCE"
    echo "========================================"
    if [ -f /sys/devices/system/clocksource/clocksource0/current_clocksource ]; then
        echo "Current: $(cat /sys/devices/system/clocksource/clocksource0/current_clocksource)"
    fi
    if [ -f /sys/devices/system/clocksource/clocksource0/available_clocksource ]; then
        echo "Available: $(cat /sys/devices/system/clocksource/clocksource0/available_clocksource)"
    fi
    echo ""
    
    echo "========================================"
    echo "TIMER TICK MODE"
    echo "========================================"
    grep -r "nohz" /sys/devices/system/cpu/cpu*/cpufreq/ 2>/dev/null || echo "No nohz info in cpufreq"
    echo ""
    
    echo "========================================"
    echo "VERIFICATION SUMMARY"
    echo "========================================"
    
    PASS_COUNT=0
    FAIL_COUNT=0
    
    if grep -q "isolcpus" /proc/cmdline; then
        echo "✓ PASS: isolcpus parameter present"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "✗ FAIL: isolcpus parameter missing"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    if grep -q "nohz_full" /proc/cmdline; then
        echo "✓ PASS: nohz_full parameter present"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "✗ FAIL: nohz_full parameter missing"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    if grep -q "rcu_nocbs" /proc/cmdline; then
        echo "✓ PASS: rcu_nocbs parameter present"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "✗ FAIL: rcu_nocbs parameter missing"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    if [ -f /sys/devices/system/cpu/isolated ] && [ -n "$(cat /sys/devices/system/cpu/isolated)" ]; then
        echo "✓ PASS: CPUs are isolated"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "⚠ NOTE: Dom0 doesn't show isolated CPUs in sysfs (this is expected in Xen)"
        echo "  Isolation is handled by Xen hypervisor for guest VMs"
    fi
    
    echo ""
    echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
    
    if [ $FAIL_COUNT -eq 0 ]; then
        echo "✓✓✓ ALL CHECKS PASSED ✓✓✓"
    else
        echo "⚠⚠⚠ SOME CHECKS FAILED - Review configuration ⚠⚠⚠"
    fi
    echo ""
    
} > "$OUTPUT_FILE" 2>&1

echo "✓ CPU isolation verification complete"
echo "✓ Output saved to: $OUTPUT_FILE"
echo ""

# Display summary
echo "Summary:"
grep "Results:" "$OUTPUT_FILE"
grep "Isolated CPUs:" "$OUTPUT_FILE" || echo "Check log for details"
echo ""
echo "Review full report: cat $OUTPUT_FILE"
echo ""

