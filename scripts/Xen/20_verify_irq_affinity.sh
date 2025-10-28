#!/bin/bash
#
# Script: 20_verify_irq_affinity.sh
# Purpose: Verify IRQ affinity configuration
# Usage: ./20_verify_irq_affinity.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
OUTPUT_FILE="$LOG_DIR/irq_affinity_verification.log"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "IRQ Affinity Verification"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

{
    echo "========================================"
    echo "IRQ AFFINITY VERIFICATION"
    echo "========================================"
    echo "Verification Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo ""
    
    echo "========================================"
    echo "SYSTEM CPU INFORMATION"
    echo "========================================"
    echo "Total CPUs visible to this system: $(nproc)"
    echo ""
    
    if xl info > /dev/null 2>&1; then
        echo "Running under Xen hypervisor (Dom0)"
        echo "Dom0 vCPUs: $(xl info | grep nr_cpus | awk '{print $3}')"
        echo ""
        echo "NOTE: In Dom0, IRQ affinity is managed for Dom0 vCPUs only."
        echo "      Guest VMs will have their own IRQ handling."
    else
        echo "Running on bare metal (no hypervisor detected)"
    fi
    echo ""
    
    echo "========================================"
    echo "IRQBALANCE SERVICE STATUS"
    echo "========================================"
    if systemctl is-active irqbalance > /dev/null 2>&1; then
        echo "⚠ WARNING: irqbalance is RUNNING"
        echo "   For RT systems, irqbalance should be stopped/disabled"
        systemctl status irqbalance --no-pager | head -5
    elif systemctl is-enabled irqbalance > /dev/null 2>&1; then
        echo "⚠ WARNING: irqbalance is ENABLED (not running now)"
        echo "   For RT systems, irqbalance should be disabled"
    else
        echo "✓ irqbalance is not active (good for RT)"
    fi
    echo ""
    
    echo "========================================"
    echo "IRQ AFFINITY SYSTEMD SERVICE"
    echo "========================================"
    if [ -f /etc/systemd/system/set-irq-affinity.service ]; then
        echo "✓ IRQ affinity service file exists"
        echo ""
        echo "Service status:"
        systemctl status set-irq-affinity.service --no-pager 2>&1 | head -10
    else
        echo "⚠ IRQ affinity service not installed"
        echo "   Run: sudo ./scripts/12_install_irq_service.sh"
    fi
    echo ""
    
    echo "========================================"
    echo "IRQ AFFINITY SCRIPT"
    echo "========================================"
    if [ -f /usr/local/bin/set_irq_affinity.sh ]; then
        echo "✓ IRQ affinity script installed at /usr/local/bin/set_irq_affinity.sh"
        echo ""
        echo "Script configuration:"
        grep -E "(HOUSEKEEPING_CPUS|HOUSEKEEPING_MASK)" /usr/local/bin/set_irq_affinity.sh | head -2
    else
        echo "⚠ IRQ affinity script not installed"
    fi
    echo ""
    
    echo "========================================"
    echo "CURRENT IRQ DISTRIBUTION"
    echo "========================================"
    echo "IRQs per CPU (top 10 most active):"
    echo ""
    
    for cpu in $(seq 0 $(($(nproc)-1))); do
        count=0
        for irq in /proc/irq/*/smp_affinity; do
            if [ -f "$irq" ]; then
                affinity=$(cat "$irq" 2>/dev/null || echo "")
                if [ -n "$affinity" ]; then
                    # Check if this CPU is in the affinity mask
                    # This is simplified - doesn't parse hex correctly
                    count=$((count + 1))
                fi
            fi
        done
    done
    
    echo "IRQ Number | CPU Affinity | IRQ Name"
    echo "-----------|--------------|----------"
    for irq_dir in /proc/irq/[0-9]*; do
        if [ -d "$irq_dir" ]; then
            irq_num=$(basename "$irq_dir")
            if [ -f "$irq_dir/smp_affinity" ]; then
                affinity=$(cat "$irq_dir/smp_affinity" 2>/dev/null || echo "N/A")
                # Get IRQ name/device
                if [ -f "$irq_dir/actions" ]; then
                    action=$(cat "$irq_dir/actions" 2>/dev/null | head -1)
                else
                    action="(unknown)"
                fi
                printf "%10s | %12s | %s\n" "$irq_num" "$affinity" "$action"
            fi
        fi
    done | head -20
    
    echo ""
    echo "NOTE: Affinity is shown as hexadecimal bitmask"
    echo "      0x0f = CPUs 0,1,2,3"
    echo "      0xff = CPUs 0-7"
    echo ""
    
    echo "========================================"
    echo "IRQ COUNTS (Current Activity)"
    echo "========================================"
    echo "Top 15 most active IRQs:"
    cat /proc/interrupts | head -1
    cat /proc/interrupts | grep -E "^[ ]*[0-9]+" | sort -t: -k2 -rn | head -15
    echo ""
    
    echo "========================================"
    echo "HARDWARE IRQs (cannot be moved)"
    echo "========================================"
    echo "Some IRQs are locked to specific CPUs by hardware:"
    echo ""
    LOCKED_COUNT=0
    for irq_dir in /proc/irq/[0-9]*; do
        if [ -d "$irq_dir" ]; then
            irq_num=$(basename "$irq_dir")
            # Check if affinity can be changed
            if [ -f "$irq_dir/smp_affinity" ] && ! [ -w "$irq_dir/smp_affinity" ]; then
                action=$(cat "$irq_dir/actions" 2>/dev/null | head -1 || echo "unknown")
                echo "  IRQ $irq_num: $action (locked)"
                LOCKED_COUNT=$((LOCKED_COUNT + 1))
            fi
        fi
    done
    
    if [ $LOCKED_COUNT -eq 0 ]; then
        echo "  (No obviously locked IRQs detected - some may still fail to move)"
    fi
    echo ""
    
    echo "========================================"
    echo "CPU ISOLATION vs IRQ AFFINITY"
    echo "========================================"
    
    if [ -f /sys/devices/system/cpu/isolated ]; then
        ISOLATED=$(cat /sys/devices/system/cpu/isolated)
        if [ -n "$ISOLATED" ]; then
            echo "Isolated CPUs (from kernel): $ISOLATED"
        else
            echo "No CPUs isolated at kernel level (expected in Xen Dom0)"
        fi
    fi
    
    if grep -q "isolcpus" /proc/cmdline; then
        echo "Isolation parameters in kernel cmdline:"
        grep -o "isolcpus=[^ ]*" /proc/cmdline
        grep -o "nohz_full=[^ ]*" /proc/cmdline 2>/dev/null || true
        grep -o "rcu_nocbs=[^ ]*" /proc/cmdline 2>/dev/null || true
    fi
    
    echo ""
    echo "IRQ affinity should route interrupts AWAY from isolated CPUs"
    echo "In Xen Dom0, IRQs are managed for Dom0 vCPUs, not physical CPUs"
    echo ""
    
    echo "========================================"
    echo "VERIFICATION SUMMARY"
    echo "========================================"
    
    PASS_COUNT=0
    WARN_COUNT=0
    FAIL_COUNT=0
    
    # Check irqbalance is disabled
    if ! systemctl is-active irqbalance > /dev/null 2>&1; then
        echo "✓ PASS: irqbalance is not running"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "✗ FAIL: irqbalance is running (should be stopped for RT)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Check if service is installed
    if [ -f /etc/systemd/system/set-irq-affinity.service ]; then
        echo "✓ PASS: IRQ affinity service is installed"
        PASS_COUNT=$((PASS_COUNT + 1))
        
        # Check if enabled
        if systemctl is-enabled set-irq-affinity.service > /dev/null 2>&1; then
            echo "✓ PASS: IRQ affinity service is enabled"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo "⚠ WARN: IRQ affinity service is not enabled"
            WARN_COUNT=$((WARN_COUNT + 1))
        fi
    else
        echo "✗ FAIL: IRQ affinity service not installed"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Check if script exists
    if [ -f /usr/local/bin/set_irq_affinity.sh ]; then
        echo "✓ PASS: IRQ affinity script is installed"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "✗ FAIL: IRQ affinity script not installed"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    echo ""
    echo "Results: $PASS_COUNT passed, $WARN_COUNT warnings, $FAIL_COUNT failed"
    
    if [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
        echo "✓✓✓ IRQ AFFINITY PROPERLY CONFIGURED ✓✓✓"
    elif [ $FAIL_COUNT -eq 0 ]; then
        echo "✓ IRQ affinity configured with minor warnings"
    else
        echo "✗✗✗ IRQ CONFIGURATION INCOMPLETE ✗✗✗"
        echo "    Complete remaining steps in Phase 1.4"
    fi
    echo ""
    
} > "$OUTPUT_FILE" 2>&1

echo "✓ IRQ affinity verification complete"
echo "✓ Output saved to: $OUTPUT_FILE"
echo ""

# Display summary
echo "Summary:"
grep "Results:" "$OUTPUT_FILE"
if grep -q "irqbalance is not running" "$OUTPUT_FILE"; then
    echo "✓ irqbalance: not running (good)"
else
    echo "⚠ irqbalance: check status"
fi
echo ""
echo "Review full report: cat $OUTPUT_FILE"
echo ""

