#!/bin/bash
#
# Script: 26_verify_and_set_acrn_boot.sh
# Purpose: Safely verify and optionally set ACRN as default boot
# Usage: sudo ./26_verify_and_set_acrn_boot.sh [--test-once|--set-default|--revert]
#

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "ACRN Boot Configuration (SAFE MODE)"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

MODE="$1"

# Function to show menu entries
show_grub_entries() {
    echo "=========================================="
    echo "Current GRUB Menu Entries:"
    echo "=========================================="
    
    if [ ! -f /boot/grub/grub.cfg ]; then
        echo "❌ ERROR: /boot/grub/grub.cfg not found!"
        return 1
    fi
    
    # Parse and display menu entries with numbers
    local count=0
    while IFS= read -r line; do
        if [[ $line =~ menuentry.*\'([^\']+)\' ]]; then
            entry="${BASH_REMATCH[1]}"
            echo "  [$count] $entry"
            count=$((count + 1))
        fi
    done < /boot/grub/grub.cfg
    
    echo ""
    echo "Total entries: $count"
    echo ""
    
    # Check for ACRN entries
    local acrn_found=$(grep -c "menuentry.*ACRN" /boot/grub/grub.cfg || true)
    if [ "$acrn_found" -eq 0 ]; then
        echo "⚠️  WARNING: No ACRN entries found in GRUB!"
        echo "   Run ./25_install_acrn.sh first"
        return 1
    else
        echo "✓ Found $acrn_found ACRN entry/entries"
        grep -n "menuentry.*ACRN" /boot/grub/grub.cfg | sed 's/^/   /'
    fi
    echo ""
}

# Function to check current default
check_current_default() {
    echo "Current GRUB Default Configuration:"
    echo "-----------------------------------"
    if grep -q "^GRUB_DEFAULT=" /etc/default/grub; then
        grep "^GRUB_DEFAULT=" /etc/default/grub
    else
        echo "GRUB_DEFAULT not set (defaults to 0)"
    fi
    
    if grep -q "^GRUB_TIMEOUT=" /etc/default/grub; then
        grep "^GRUB_TIMEOUT=" /etc/default/grub
    else
        echo "GRUB_TIMEOUT not set"
    fi
    echo ""
}

# Function to verify ACRN installation
verify_acrn_files() {
    echo "Verifying ACRN Installation:"
    echo "----------------------------"
    
    local errors=0
    
    # Check hypervisor binary
    if [ -f /boot/acrn.bin ]; then
        echo "✓ /boot/acrn.bin exists"
    elif [ -f /boot/acrn.32.out ]; then
        echo "✓ /boot/acrn.32.out exists"
    else
        echo "❌ No ACRN hypervisor binary in /boot/"
        errors=$((errors + 1))
    fi
    
    # Check device model
    if [ -f /usr/bin/acrn-dm ]; then
        echo "✓ /usr/bin/acrn-dm exists"
    else
        echo "❌ /usr/bin/acrn-dm not found"
        errors=$((errors + 1))
    fi
    
    # Check GRUB entry file
    if [ -f /etc/grub.d/40_custom_acrn ]; then
        echo "✓ /etc/grub.d/40_custom_acrn exists"
    else
        echo "❌ /etc/grub.d/40_custom_acrn not found"
        errors=$((errors + 1))
    fi
    
    # Check kernel
    if [ -f /boot/vmlinuz-$(uname -r) ]; then
        echo "✓ Kernel exists: /boot/vmlinuz-$(uname -r)"
    else
        echo "⚠️  Warning: Current kernel not found in /boot/"
    fi
    
    echo ""
    
    if [ $errors -gt 0 ]; then
        echo "❌ ACRN installation incomplete ($errors errors)"
        echo "   Run ./25_install_acrn.sh first"
        return 1
    else
        echo "✓ ACRN installation verified"
    fi
    
    return 0
}

# Function to show ACRN GRUB entry content
show_acrn_grub_entry() {
    echo "ACRN GRUB Entry Configuration:"
    echo "------------------------------"
    if [ -f /etc/grub.d/40_custom_acrn ]; then
        cat /etc/grub.d/40_custom_acrn
    else
        echo "❌ /etc/grub.d/40_custom_acrn not found"
        return 1
    fi
    echo ""
}

# Main logic
if [ -z "$MODE" ]; then
    # No mode specified - show information and options
    echo "SAFE MODE: No changes will be made"
    echo ""
    
    verify_acrn_files || exit 1
    check_current_default
    show_grub_entries || exit 1
    show_acrn_grub_entry || exit 1
    
    echo "=========================================="
    echo "SAFE BOOT OPTIONS:"
    echo "=========================================="
    echo ""
    echo "Step 1: TEST ACRN ONCE (recommended first):"
    echo "  sudo ./26_verify_and_set_acrn_boot.sh --test-once"
    echo "  → Boots ACRN ONLY NEXT REBOOT, then reverts to Ubuntu"
    echo "  → If ACRN fails, server will boot Ubuntu automatically"
    echo ""
    echo "Step 2: If test succeeds, SET AS DEFAULT:"
    echo "  sudo ./26_verify_and_set_acrn_boot.sh --set-default"
    echo "  → Makes ACRN the permanent default boot"
    echo ""
    echo "Step 3: REVERT to Ubuntu default:"
    echo "  sudo ./26_verify_and_set_acrn_boot.sh --revert"
    echo ""
    echo "=========================================="
    
elif [ "$MODE" == "--test-once" ]; then
    echo "MODE: Test ACRN Once (Safe Test)"
    echo ""
    
    verify_acrn_files || exit 1
    show_grub_entries || exit 1
    
    # Get the ACRN entry number
    echo "Finding ACRN menu entry number..."
    ACRN_ENTRY=$(awk '/^menuentry/ {count++} /menuentry.*ACRN/ {print count-1; exit}' /boot/grub/grub.cfg)
    
    if [ -z "$ACRN_ENTRY" ]; then
        echo "❌ Could not find ACRN entry number"
        exit 1
    fi
    
    echo "✓ ACRN is entry number: $ACRN_ENTRY"
    echo ""
    
    # Use grub-reboot for one-time boot
    echo "Setting ACRN for NEXT BOOT ONLY..."
    grub-reboot "$ACRN_ENTRY"
    echo "✓ ACRN set for next boot only"
    echo ""
    
    # Verify current default is still Ubuntu
    check_current_default
    
    echo "=========================================="
    echo "✓ ONE-TIME ACRN BOOT CONFIGURED"
    echo "=========================================="
    echo ""
    echo "WHAT HAPPENS NEXT:"
    echo "  1. Next reboot: System will try to boot ACRN"
    echo "  2. If ACRN works: Login via SSH and verify"
    echo "  3. If ACRN fails: System auto-reverts to Ubuntu"
    echo "  4. Subsequent reboots: Back to Ubuntu default"
    echo ""
    echo "⚠️  SAFETY: If you lose connection, just reboot remotely"
    echo "   and it will come back with Ubuntu!"
    echo ""
    echo "After reboot, verify ACRN with:"
    echo "  dmesg | grep -i acrn"
    echo "  cat /proc/cmdline"
    echo ""
    echo "If ACRN works, make it permanent with:"
    echo "  sudo ./26_verify_and_set_acrn_boot.sh --set-default"
    echo ""
    
    echo "Reboot now to test ACRN? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Rebooting in 5 seconds... (Ctrl+C to cancel)"
        sleep 5
        reboot
    else
        echo "Remember to reboot to test: sudo reboot"
    fi

elif [ "$MODE" == "--set-default" ]; then
    echo "MODE: Set ACRN as Permanent Default"
    echo ""
    
    echo "⚠️  WARNING: This will make ACRN the permanent default boot!"
    echo ""
    echo "Have you successfully tested ACRN with --test-once? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Please test ACRN first with: --test-once"
        exit 1
    fi
    
    verify_acrn_files || exit 1
    
    # Backup
    echo "Backing up GRUB configuration..."
    cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d-%H%M%S)
    echo "✓ Backup created"
    echo ""
    
    # Get ACRN entry number
    ACRN_ENTRY=$(awk '/^menuentry/ {count++} /menuentry.*ACRN/ {print count-1; exit}' /boot/grub/grub.cfg)
    
    if [ -z "$ACRN_ENTRY" ]; then
        echo "❌ Could not find ACRN entry number"
        exit 1
    fi
    
    echo "Setting ACRN (entry $ACRN_ENTRY) as default..."
    
    # Update GRUB default
    sed -i '/^GRUB_DEFAULT=/d' /etc/default/grub
    echo "GRUB_DEFAULT=$ACRN_ENTRY" >> /etc/default/grub
    
    # Set reasonable timeout
    sed -i '/^GRUB_TIMEOUT=/d' /etc/default/grub
    echo "GRUB_TIMEOUT=5" >> /etc/default/grub
    
    # Show menu
    sed -i '/^GRUB_TIMEOUT_STYLE=/d' /etc/default/grub
    echo "GRUB_TIMEOUT_STYLE=menu" >> /etc/default/grub
    
    # Update GRUB
    echo ""
    echo "Updating GRUB..."
    update-grub
    echo "✓ GRUB updated"
    echo ""
    
    check_current_default
    
    echo "=========================================="
    echo "✓ ACRN SET AS DEFAULT BOOT"
    echo "=========================================="
    echo ""
    echo "ACRN will now boot by default"
    echo "You can still select Ubuntu from GRUB menu (5 sec timeout)"
    echo ""
    echo "To revert: sudo ./26_verify_and_set_acrn_boot.sh --revert"
    echo ""

elif [ "$MODE" == "--revert" ]; then
    echo "MODE: Revert to Ubuntu Default"
    echo ""
    
    # Backup
    echo "Backing up GRUB configuration..."
    cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d-%H%M%S)
    echo "✓ Backup created"
    echo ""
    
    # Set default to 0 (Ubuntu)
    echo "Setting Ubuntu as default boot..."
    sed -i '/^GRUB_DEFAULT=/d' /etc/default/grub
    echo "GRUB_DEFAULT=0" >> /etc/default/grub
    
    # Update GRUB
    echo ""
    echo "Updating GRUB..."
    update-grub
    echo "✓ GRUB updated"
    echo ""
    
    check_current_default
    
    echo "=========================================="
    echo "✓ REVERTED TO UBUNTU DEFAULT"
    echo "=========================================="
    echo ""
    echo "Ubuntu will now boot by default"
    echo ""

else
    echo "❌ Unknown mode: $MODE"
    echo ""
    echo "Valid options:"
    echo "  --test-once    : Test ACRN on next boot only (safe)"
    echo "  --set-default  : Make ACRN permanent default"
    echo "  --revert       : Revert to Ubuntu default"
    exit 1
fi

