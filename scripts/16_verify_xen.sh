#!/bin/bash
#
# Script: 16_verify_xen.sh
# Purpose: Verify Xen hypervisor installation and configuration
# Usage: ./16_verify_xen.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
OUTPUT_FILE="$LOG_DIR/xen_status.log"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "Xen Hypervisor Verification"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

{
    echo "========================================"
    echo "XEN HYPERVISOR VERIFICATION"
    echo "========================================"
    echo "Verification Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo ""
    
    echo "========================================"
    echo "XEN INSTALLATION CHECK"
    echo "========================================"
    echo "Installed Xen packages:"
    dpkg -l | grep xen | grep "^ii" || echo "No Xen packages found"
    echo ""
    
    echo "========================================"
    echo "XEN HYPERVISOR STATUS"
    echo "========================================"
    
    if command -v xl &> /dev/null; then
        echo "✓ xl command found"
        echo ""
        
        echo "Attempting to get Xen info..."
        if xl info &> /dev/null; then
            echo "✓ Xen hypervisor is RUNNING"
            echo ""
            xl info
            echo ""
        else
            echo "✗ Xen hypervisor is NOT running"
            echo "   (This is normal if not yet rebooted into Xen)"
            echo ""
            echo "Error output:"
            xl info 2>&1 || true
            echo ""
        fi
    else
        echo "✗ xl command not found - Xen not installed"
    fi
    echo ""
    
    echo "========================================"
    echo "XEN VERSION"
    echo "========================================"
    if command -v xl &> /dev/null; then
        xl --version || echo "Cannot get Xen version"
    else
        echo "xl command not available"
    fi
    echo ""
    
    echo "========================================"
    echo "XEN SCHEDULER"
    echo "========================================"
    if xl info &> /dev/null; then
        xl info | grep -i sched || echo "Scheduler info not available"
        echo ""
        
        # Check if RT scheduler is configured
        SCHED=$(xl info 2>/dev/null | grep "^sched_id" | awk '{print $NF}' || echo "unknown")
        echo "Current scheduler: $SCHED"
        
        if [ "$SCHED" = "rtds" ] || xl info 2>/dev/null | grep -qi "rtds"; then
            echo "✓ RT Deferrable Server (RTDS) scheduler is active"
        elif [ "$SCHED" = "credit2" ]; then
            echo "⚠ Credit2 scheduler (default, not RT)"
        elif [ "$SCHED" = "credit" ]; then
            echo "⚠ Credit scheduler (default, not RT)"
        else
            echo "⚠ Scheduler: $SCHED"
        fi
    else
        echo "Cannot query scheduler (Xen not running)"
    fi
    echo ""
    
    echo "========================================"
    echo "DOM0 CONFIGURATION"
    echo "========================================"
    if xl info &> /dev/null; then
        echo "Domain-0 information:"
        xl list 2>/dev/null || echo "Cannot list domains"
        echo ""
        
        echo "Dom0 vCPU configuration:"
        xl vcpu-list 0 2>/dev/null || echo "Cannot list vCPUs"
    else
        echo "Xen not running, cannot check Dom0"
    fi
    echo ""
    
    echo "========================================"
    echo "XEN DMESG (last 50 lines)"
    echo "========================================"
    if command -v xl &> /dev/null && xl info &> /dev/null; then
        xl dmesg | tail -50 || echo "Cannot access Xen dmesg"
    else
        echo "Xen not running"
    fi
    echo ""
    
    echo "========================================"
    echo "GRUB BOOT MENU"
    echo "========================================"
    echo "Checking for Xen entries in GRUB..."
    if [ -f /boot/grub/grub.cfg ]; then
        grep "menuentry.*[Xx]en" /boot/grub/grub.cfg | head -5 || echo "No Xen menu entries found"
    else
        echo "GRUB config not found"
    fi
    echo ""
    
    echo "========================================"
    echo "XEN CONFIGURATION FILES"
    echo "========================================"
    if [ -d /etc/xen ]; then
        echo "✓ /etc/xen directory exists"
        echo ""
        echo "Contents:"
        ls -la /etc/xen/
        echo ""
        
        if [ -f /etc/xen/xl.conf ]; then
            echo "xl.conf contents:"
            cat /etc/xen/xl.conf
            echo ""
        fi
    else
        echo "✗ /etc/xen directory not found"
    fi
    echo ""
    
    echo "========================================"
    echo "XEN CPU POOLS (for CPU partitioning)"
    echo "========================================"
    if xl info &> /dev/null; then
        xl cpupool-list 2>/dev/null || echo "Cannot list CPU pools (may need configuration)"
    else
        echo "Xen not running"
    fi
    echo ""
    
    echo "========================================"
    echo "VERIFICATION SUMMARY"
    echo "========================================"
    
    PASS_COUNT=0
    FAIL_COUNT=0
    WARN_COUNT=0
    
    if command -v xl &> /dev/null; then
        echo "✓ CHECK: xl tool installed"
        ((PASS_COUNT++))
    else
        echo "✗ CHECK: xl tool not installed"
        ((FAIL_COUNT++))
    fi
    
    if xl info &> /dev/null; then
        echo "✓ CHECK: Xen hypervisor running"
        ((PASS_COUNT++))
    else
        echo "⚠ CHECK: Xen hypervisor not running"
        ((WARN_COUNT++))
    fi
    
    if [ -d /etc/xen ]; then
        echo "✓ CHECK: Xen configuration directory exists"
        ((PASS_COUNT++))
    else
        echo "✗ CHECK: Xen configuration directory missing"
        ((FAIL_COUNT++))
    fi
    
    if xl info &> /dev/null; then
        SCHED=$(xl info 2>/dev/null | grep "^sched_id" | awk '{print $NF}' || echo "unknown")
        if [ "$SCHED" = "rtds" ] || xl info 2>/dev/null | grep -qi "rtds"; then
            echo "✓ CHECK: RT scheduler configured"
            ((PASS_COUNT++))
        else
            echo "⚠ CHECK: RT scheduler not configured (current: $SCHED)"
            ((WARN_COUNT++))
        fi
    fi
    
    echo ""
    echo "Results: $PASS_COUNT passed, $WARN_COUNT warnings, $FAIL_COUNT failed"
    
    if [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
        echo "✓✓✓ XEN FULLY OPERATIONAL ✓✓✓"
    elif [ $FAIL_COUNT -eq 0 ]; then
        echo "⚠⚠⚠ XEN INSTALLED, REBOOT MAY BE NEEDED ⚠⚠⚠"
    else
        echo "⚠⚠⚠ XEN INSTALLATION INCOMPLETE ⚠⚠⚠"
    fi
    echo ""
    
} > "$OUTPUT_FILE" 2>&1

echo "✓ Xen verification complete"
echo "✓ Output saved to: $OUTPUT_FILE"
echo ""

# Display summary
echo "Summary:"
grep "Results:" "$OUTPUT_FILE"
if grep -q "Xen hypervisor running" "$OUTPUT_FILE"; then
    grep "Xen hypervisor" "$OUTPUT_FILE" | head -1
fi
echo ""
echo "Review full report: cat $OUTPUT_FILE"
echo ""

