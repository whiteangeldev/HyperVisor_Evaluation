#!/bin/bash
#
# Script: 28_auto_boot_acrn.sh
# Purpose: Automatically configure and boot ACRN (safe with validation)
# Usage: sudo ./28_auto_boot_acrn.sh [--permanent|--test-once|--revert]
#

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/acrn_boot_setup.log"

mkdir -p "$LOG_DIR"

# Log function
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "========================================"
log "ACRN Auto-Boot Setup"
log "========================================"
log "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
log ""

MODE="${1:-}"

# Function to check if GRUB entry has intel_iommu=on
check_grub_entry_validity() {
    log "Checking ACRN GRUB entry validity..."
    
    if [ ! -f /etc/grub.d/40_custom_acrn ]; then
        log "❌ ACRN GRUB entry not found!"
        return 1
    fi
    
    # Check if module2 line has intel_iommu=on
    if grep -q "module2.*intel_iommu=on" /etc/grub.d/40_custom_acrn; then
        log "✓ GRUB entry has intel_iommu=on"
        return 0
    else
        log "❌ GRUB entry MISSING intel_iommu=on"
        log "   This MUST be fixed or ACRN will fail to boot!"
        return 1
    fi
}

# Function to fix GRUB entry
fix_grub_entry() {
    log ""
    log "=========================================="
    log "Fixing ACRN GRUB Entry"
    log "=========================================="
    
    # Backup
    log "Backing up current GRUB entry..."
    cp /etc/grub.d/40_custom_acrn /etc/grub.d/40_custom_acrn.backup.$(date +%Y%m%d-%H%M%S)
    log "✓ Backup created"
    
    # Get root UUID
    ROOT_UUID=$(findmnt -n -o UUID /)
    log "Root UUID: $ROOT_UUID"
    
    # Create corrected GRUB entry
    log "Creating corrected ACRN GRUB entry..."
    cat > /etc/grub.d/40_custom_acrn << EOF
#!/bin/sh
exec tail -n +3 \$0
# ACRN Hypervisor Boot Entry (Auto-configured)

menuentry 'ACRN Hypervisor' --class ubuntu --class gnu-linux --class gnu --class os {
    recordfail
    load_video
    insmod gzio
    insmod part_gpt
    insmod ext2
    
    echo 'Loading ACRN Hypervisor...'
    multiboot2 /boot/acrn.bin
    
    echo 'Loading Service VM kernel...'
    module2 /boot/vmlinuz root=UUID=$ROOT_UUID ro intel_iommu=on
    
    echo 'Loading Service VM initrd...'
    module2 /boot/initrd.img
}
EOF
    
    chmod +x /etc/grub.d/40_custom_acrn
    log "✓ GRUB entry fixed with intel_iommu=on"
    
    # Update GRUB
    log ""
    log "Updating GRUB..."
    update-grub >> "$LOG_FILE" 2>&1
    log "✓ GRUB updated"
    
    return 0
}

# Function to verify ACRN files
verify_acrn_installation() {
    log ""
    log "Verifying ACRN Installation..."
    log "------------------------------"
    
    local errors=0
    
    if [ -f /boot/acrn.bin ]; then
        log "✓ /boot/acrn.bin exists"
    elif [ -f /boot/acrn.32.out ]; then
        log "✓ /boot/acrn.32.out exists"
    else
        log "❌ No ACRN hypervisor binary in /boot/"
        errors=$((errors + 1))
    fi
    
    if [ -f /usr/bin/acrn-dm ]; then
        log "✓ /usr/bin/acrn-dm exists"
    else
        log "❌ /usr/bin/acrn-dm not found"
        errors=$((errors + 1))
    fi
    
    if [ -f /boot/vmlinuz ]; then
        log "✓ Kernel symlink exists"
    else
        log "❌ /boot/vmlinuz not found"
        errors=$((errors + 1))
    fi
    
    if [ -f /boot/initrd.img ]; then
        log "✓ Initrd symlink exists"
    else
        log "❌ /boot/initrd.img not found"
        errors=$((errors + 1))
    fi
    
    log ""
    
    if [ $errors -gt 0 ]; then
        log "❌ ACRN installation incomplete ($errors errors)"
        return 1
    else
        log "✓ ACRN installation verified"
        return 0
    fi
}

# Function to set ACRN as default boot
set_acrn_default() {
    log ""
    log "=========================================="
    log "Setting ACRN as Default Boot"
    log "=========================================="
    
    # Find ACRN entry number
    log "Finding ACRN entry number in GRUB..."
    ACRN_ENTRY=$(awk '/^menuentry/ {count++} /menuentry.*ACRN/ {print count-1; exit}' /boot/grub/grub.cfg)
    
    if [ -z "$ACRN_ENTRY" ]; then
        log "❌ Could not find ACRN entry in GRUB config"
        return 1
    fi
    
    log "✓ ACRN is entry number: $ACRN_ENTRY"
    
    # Backup GRUB config
    cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d-%H%M%S)
    log "✓ Backed up /etc/default/grub"
    
    # Update GRUB default
    sed -i '/^GRUB_DEFAULT=/d' /etc/default/grub
    echo "GRUB_DEFAULT=$ACRN_ENTRY" >> /etc/default/grub
    
    # Set timeout (visible menu for 5 seconds)
    sed -i '/^GRUB_TIMEOUT=/d' /etc/default/grub
    echo "GRUB_TIMEOUT=5" >> /etc/default/grub
    
    sed -i '/^GRUB_TIMEOUT_STYLE=/d' /etc/default/grub
    echo "GRUB_TIMEOUT_STYLE=menu" >> /etc/default/grub
    
    log ""
    log "Updating GRUB with new default..."
    update-grub >> "$LOG_FILE" 2>&1
    log "✓ GRUB updated - ACRN set as entry $ACRN_ENTRY"
    
    return 0
}

# Function to set test-once mode
set_test_once() {
    log ""
    log "=========================================="
    log "Setting ACRN for One-Time Test Boot"
    log "=========================================="
    
    # Find ACRN entry number
    ACRN_ENTRY=$(awk '/^menuentry/ {count++} /menuentry.*ACRN/ {print count-1; exit}' /boot/grub/grub.cfg)
    
    if [ -z "$ACRN_ENTRY" ]; then
        log "❌ Could not find ACRN entry"
        return 1
    fi
    
    log "✓ ACRN is entry number: $ACRN_ENTRY"
    log ""
    log "Setting one-time boot to ACRN..."
    grub-reboot "$ACRN_ENTRY"
    log "✓ Next boot will use ACRN (one time only)"
    log "  If ACRN fails, subsequent reboot will use Ubuntu"
    
    return 0
}

# Function to revert to Ubuntu
revert_to_ubuntu() {
    log ""
    log "=========================================="
    log "Reverting to Ubuntu Default"
    log "=========================================="
    
    cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d-%H%M%S)
    log "✓ Backed up /etc/default/grub"
    
    sed -i '/^GRUB_DEFAULT=/d' /etc/default/grub
    echo "GRUB_DEFAULT=0" >> /etc/default/grub
    
    log ""
    log "Updating GRUB..."
    update-grub >> "$LOG_FILE" 2>&1
    log "✓ GRUB updated - Ubuntu set as default"
    
    return 0
}

# Main execution
if [ -z "$MODE" ]; then
    log "No mode specified. Showing current status..."
    log ""
    
    verify_acrn_installation || { log "Fix ACRN installation first!"; exit 1; }
    
    log "Current GRUB Default:"
    grep "^GRUB_DEFAULT=" /etc/default/grub 2>/dev/null || log "  Not set (defaults to 0 - Ubuntu)"
    log ""
    
    if check_grub_entry_validity; then
        log "✓ ACRN GRUB entry is valid"
    else
        log "⚠️  ACRN GRUB entry needs fixing!"
    fi
    
    log ""
    log "=========================================="
    log "Available Options:"
    log "=========================================="
    log ""
    log "FIX and PERMANENTLY SET ACRN:"
    log "  sudo ./28_auto_boot_acrn.sh --permanent"
    log "  → Fixes GRUB entry + Sets ACRN as default"
    log ""
    log "TEST ONCE (safer):"
    log "  sudo ./28_auto_boot_acrn.sh --test-once"
    log "  → Boots ACRN only next reboot"
    log ""
    log "REVERT to Ubuntu:"
    log "  sudo ./28_auto_boot_acrn.sh --revert"
    log ""
    
elif [ "$MODE" == "--permanent" ]; then
    log "MODE: Set ACRN as Permanent Default (with auto-fix)"
    log ""
    
    verify_acrn_installation || exit 1
    
    # Check and fix GRUB entry if needed
    if ! check_grub_entry_validity; then
        log ""
        log "⚠️  GRUB entry is invalid - fixing automatically..."
        fix_grub_entry || exit 1
    fi
    
    # Set as default
    set_acrn_default || exit 1
    
    log ""
    log "=========================================="
    log "✅ ACRN CONFIGURED AS DEFAULT BOOT"
    log "=========================================="
    log ""
    log "Changes made:"
    log "  ✓ GRUB entry verified/fixed with intel_iommu=on"
    log "  ✓ ACRN set as default boot option"
    log "  ✓ GRUB menu visible for 5 seconds"
    log ""
    log "Next reboot will boot ACRN automatically!"
    log ""
    log "To revert: sudo ./28_auto_boot_acrn.sh --revert"
    log ""
    log "Log saved to: $LOG_FILE"
    
elif [ "$MODE" == "--test-once" ]; then
    log "MODE: Test ACRN One Time"
    log ""
    
    verify_acrn_installation || exit 1
    
    # Check and fix GRUB entry if needed
    if ! check_grub_entry_validity; then
        log ""
        log "⚠️  GRUB entry is invalid - fixing automatically..."
        fix_grub_entry || exit 1
    fi
    
    # Set test-once
    set_test_once || exit 1
    
    log ""
    log "=========================================="
    log "✅ ACRN SET FOR ONE-TIME TEST"
    log "=========================================="
    log ""
    log "NEXT BOOT: ACRN hypervisor"
    log "SUBSEQUENT BOOTS: Ubuntu (default)"
    log ""
    log "Log saved to: $LOG_FILE"
    
elif [ "$MODE" == "--revert" ]; then
    log "MODE: Revert to Ubuntu"
    log ""
    
    revert_to_ubuntu || exit 1
    
    log ""
    log "=========================================="
    log "✅ REVERTED TO UBUNTU DEFAULT"
    log "=========================================="
    log ""
    log "System will boot Ubuntu by default"
    log ""
    log "Log saved to: $LOG_FILE"
    
else
    log "❌ Unknown mode: $MODE"
    log ""
    log "Valid options:"
    log "  --permanent  : Fix GRUB entry and set ACRN as default"
    log "  --test-once  : Boot ACRN only next time (safe test)"
    log "  --revert     : Revert to Ubuntu default"
    exit 1
fi

log ""
log "Completed at: $(date '+%Y-%m-%d %H:%M:%S')"

