#!/bin/bash
#
# Script: 09d_diagnose_xen_boot.sh
# Purpose: Diagnose why Xen isn't booting
# Usage: sudo ./09d_diagnose_xen_boot.sh
# ⚠️  REQUIRES ROOT PRIVILEGES
#

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ ERROR: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
OUTPUT_FILE="$LOG_DIR/xen_boot_diagnosis.log"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "Xen Boot Diagnosis"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

{
    echo "========================================"
    echo "XEN BOOT DIAGNOSIS LOG"
    echo "========================================"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    echo "1. GRUB CONFIGURATION"
    echo "========================================"
    echo "/etc/default/grub settings:"
    grep -E "^GRUB_DEFAULT|^GRUB_TIMEOUT" /etc/default/grub || echo "No GRUB settings found"
    echo ""
    
    echo "2. GRUB MENU ENTRIES"
    echo "========================================"
    echo "Main menu entries:"
    grep "^menuentry" /boot/grub/grub.cfg | nl -v 0 | head -10
    echo ""
    
    echo "Xen entries:"
    grep "menuentry.*Xen" /boot/grub/grub.cfg || echo "❌ NO XEN ENTRIES FOUND!"
    echo ""
    
    echo "3. XEN FILES IN /boot"
    echo "========================================"
    ls -lh /boot/xen* 2>/dev/null || echo "No Xen files found"
    echo ""
    
    echo "4. CURRENT BOOT STATUS"
    echo "========================================"
    echo "Hypervisor directory:"
    ls -la /sys/hypervisor/ 2>&1
    echo ""
    
    echo "Kernel command line:"
    cat /proc/cmdline
    echo ""
    
    echo "Loaded kernel:"
    uname -a
    echo ""
    
    echo "5. BOOT LOGS (last 50 xen/hypervisor lines)"
    echo "========================================"
    dmesg | grep -i "xen\|hypervisor" | tail -50 || echo "No Xen messages in dmesg"
    echo ""
    
    echo "6. JOURNAL LOGS (xen/grub related)"
    echo "========================================"
    journalctl -b | grep -i "xen\|grub" | tail -30 || echo "No Xen/GRUB in journal"
    echo ""
    
    echo "7. XEN PACKAGES"
    echo "========================================"
    dpkg -l | grep "^ii.*xen" | awk '{print $2, $3}'
    echo ""
    
    echo "8. GRUB XEN CONFIGURATION"
    echo "========================================"
    if [ -f /etc/default/grub.d/xen.cfg ]; then
        echo "xen.cfg found:"
        cat /etc/default/grub.d/xen.cfg
    else
        echo "❌ No /etc/default/grub.d/xen.cfg"
    fi
    echo ""
    
    echo "9. ANALYSIS"
    echo "========================================"
    
    # Check if Xen entries exist
    if ! grep -q "menuentry.*Xen" /boot/grub/grub.cfg; then
        echo "❌ PROBLEM: No Xen entries in GRUB config"
        echo "   SOLUTION: Run sudo ./09b_fix_xen_grub.sh"
        echo ""
    else
        echo "✓ Xen entries exist in GRUB"
        echo ""
    fi
    
    # Check GRUB_DEFAULT
    if grep -q "^GRUB_DEFAULT=" /etc/default/grub; then
        DEFAULT=$(grep "^GRUB_DEFAULT=" /etc/default/grub | cut -d= -f2 | tr -d '"')
        echo "GRUB_DEFAULT is set to: $DEFAULT"
        
        if [ "$DEFAULT" = "0" ]; then
            echo "⚠ WARNING: GRUB_DEFAULT=0 may boot regular kernel"
            echo "   Check if Xen is first entry"
        fi
    else
        echo "⚠ WARNING: GRUB_DEFAULT not set, using GRUB defaults"
    fi
    echo ""
    
    # Check if hypervisor directory exists
    if [ -d /sys/hypervisor ] && [ -n "$(ls -A /sys/hypervisor 2>/dev/null)" ]; then
        echo "✓ /sys/hypervisor exists and has content"
        echo "  But xl info still fails - check Xen modules"
    elif [ -d /sys/hypervisor ]; then
        echo "⚠ /sys/hypervisor exists but is EMPTY"
        echo "  System might have tried to boot Xen but failed"
    else
        echo "❌ /sys/hypervisor does not exist"
        echo "  System is NOT running under any hypervisor"
    fi
    echo ""
    
    echo "10. RECOMMENDED ACTIONS"
    echo "========================================"
    
    if ! grep -q "menuentry.*Xen" /boot/grub/grub.cfg; then
        echo "1. Run: sudo ./09b_fix_xen_grub.sh"
        echo "2. Run: sudo ./09c_set_xen_default.sh"
        echo "3. Run: sudo reboot"
    else
        echo "Xen entries exist. Checking boot configuration..."
        
        # Get the actual first entry
        FIRST_ENTRY=$(grep "^menuentry" /boot/grub/grub.cfg | head -1)
        
        if echo "$FIRST_ENTRY" | grep -qi "xen"; then
            echo "✓ First entry IS Xen - should boot automatically"
            echo ""
            echo "Possible issues:"
            echo "1. Xen hypervisor binary problem"
            echo "2. Missing Xen modules"
            echo "3. GRUB not actually using the config"
            echo ""
            echo "Try:"
            echo "  sudo update-grub"
            echo "  sudo reboot"
        else
            echo "❌ First entry is NOT Xen"
            echo "   First entry: $FIRST_ENTRY"
            echo ""
            echo "Fix:"
            echo "  sudo ./09c_set_xen_default.sh"
            echo "  sudo reboot"
        fi
    fi
    echo ""
    
    echo "11. MANUAL GRUB CHECK"
    echo "========================================"
    echo "To manually check GRUB entries with indices:"
    grep "^menuentry" /boot/grub/grub.cfg | nl -v 0 | grep -i xen
    echo ""
    
} > "$OUTPUT_FILE" 2>&1

cat "$OUTPUT_FILE"

echo ""
echo "========================================"
echo "Diagnosis Complete"
echo "========================================"
echo "Full log saved to: $OUTPUT_FILE"
echo ""

