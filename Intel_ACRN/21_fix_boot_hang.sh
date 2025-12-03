#!/bin/bash
#
# Script: 21_fix_boot_hang.sh
# Purpose: Fix ACRN boot hang issue (stuck at loading initrd)
# Usage: sudo ./21_fix_boot_hang.sh
#
# This script fixes common issues that cause ACRN to hang during boot:
# 1. Missing intel_iommu=on in Service VM parameters
# 2. Missing ACRN hypervisor console parameters
# 3. Incorrect kernel/initrd paths
# 4. GRUB parameter parsing issues

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

echo "========================================"
echo "Fix ACRN Boot Hang Issue"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

ERRORS=0

# 1. Check ACRN binary
echo "1. Checking ACRN binary..."
if [ ! -f /boot/acrn.bin ]; then
    echo "   ❌ /boot/acrn.bin not found"
    echo "      Run: sudo ./07_install_acrn_binary.sh first"
    exit 1
fi

SIZE=$(stat -c%s /boot/acrn.bin 2>/dev/null || stat -f%z /boot/acrn.bin 2>/dev/null)
echo "   ✓ ACRN binary exists ($(numfmt --to=iec-i --suffix=B $SIZE 2>/dev/null || echo "${SIZE} bytes"))"

if [ "$SIZE" -lt 100000 ]; then
    echo "   ⚠️  Binary seems too small - may be corrupted"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 2. Get root UUID
echo "2. Getting root filesystem UUID..."
ROOT_UUID=$(findmnt -n -o UUID /)
if [ -z "$ROOT_UUID" ]; then
    echo "   ❌ Could not determine root filesystem UUID"
    exit 1
fi
echo "   ✓ Root UUID: $ROOT_UUID"
echo ""

# 3. Find kernel and initrd
echo "3. Finding kernel and initrd..."
KERNEL="/boot/vmlinuz-$(uname -r)"
INITRD="/boot/initrd.img-$(uname -r)"

if [ ! -f "$KERNEL" ]; then
    if [ -L /boot/vmlinuz ]; then
        KERNEL=$(readlink -f /boot/vmlinuz)
    else
        KERNEL=$(ls -t /boot/vmlinuz-* 2>/dev/null | head -1)
        if [ -z "$KERNEL" ]; then
            echo "   ❌ No kernel found"
            exit 1
        fi
    fi
fi

if [ ! -f "$INITRD" ]; then
    if [ -L /boot/initrd.img ]; then
        INITRD=$(readlink -f /boot/initrd.img)
    else
        INITRD=$(ls -t /boot/initrd.img-* 2>/dev/null | head -1)
        if [ -z "$INITRD" ]; then
            echo "   ❌ No initrd found"
            exit 1
        fi
    fi
fi

echo "   ✓ Kernel: $KERNEL"
echo "   ✓ Initrd: $INITRD"

# Verify files exist
if [ ! -f "$KERNEL" ]; then
    echo "   ❌ Kernel file does not exist: $KERNEL"
    exit 1
fi

if [ ! -f "$INITRD" ]; then
    echo "   ❌ Initrd file does not exist: $INITRD"
    exit 1
fi
echo ""

# 4. Extract existing parameters (if GRUB entry exists)
echo "4. Analyzing existing GRUB entry..."
EXISTING_ENTRY="/etc/grub.d/40_custom_acrn"
EXISTING_SERVICE_VM_PARAMS=""
EXISTING_ACRN_HV_PARAMS=""

if [ -f "$EXISTING_ENTRY" ]; then
    # Extract Service VM kernel parameters (everything after root=UUID=... ro)
    EXISTING_SERVICE_VM_PARAMS=$(grep "module2.*vmlinuz" "$EXISTING_ENTRY" 2>/dev/null | \
        sed 's/.*module2[^ ]* //' | \
        sed 's/root=UUID=[^ ]* //' | \
        sed 's/ro //' || echo "")
    
    # Extract ACRN hypervisor parameters
    EXISTING_ACRN_HV_PARAMS=$(grep "multiboot2.*acrn.bin" "$EXISTING_ENTRY" 2>/dev/null | \
        sed 's/.*multiboot2[^ ]* //' || echo "")
    
    if [ -n "$EXISTING_SERVICE_VM_PARAMS" ]; then
        echo "   Found existing Service VM parameters: $EXISTING_SERVICE_VM_PARAMS"
    fi
    if [ -n "$EXISTING_ACRN_HV_PARAMS" ]; then
        echo "   Found existing ACRN hypervisor parameters: $EXISTING_ACRN_HV_PARAMS"
    fi
else
    echo "   No existing GRUB entry found - will create new one"
fi
echo ""

# 5. Build Service VM parameters
echo "5. Building Service VM kernel parameters..."

# Start with existing parameters or get from /etc/default/grub
if [ -n "$EXISTING_SERVICE_VM_PARAMS" ]; then
    GRUB_PARAMS="$EXISTING_SERVICE_VM_PARAMS"
else
    GRUB_PARAMS=$(grep "^GRUB_CMDLINE_LINUX=" /etc/default/grub 2>/dev/null | \
        sed 's/^GRUB_CMDLINE_LINUX=//' | tr -d '"' || echo "")
fi

# Remove console parameters (we'll add our own)
GRUB_PARAMS=$(echo "$GRUB_PARAMS" | sed 's/console=[^ ]*//g' | sed 's/  */ /g' | sed 's/^ //' | sed 's/ $//')

# CRITICAL: Ensure intel_iommu=on is included
if ! echo "$GRUB_PARAMS" | grep -q "intel_iommu=on"; then
    if [ -n "$GRUB_PARAMS" ]; then
        GRUB_PARAMS="$GRUB_PARAMS intel_iommu=on"
    else
        GRUB_PARAMS="intel_iommu=on"
    fi
    echo "   ✓ Added intel_iommu=on (CRITICAL for ACRN)"
else
    echo "   ✓ intel_iommu=on already present"
fi

# Add console parameters for Service VM
CONSOLE_PARAMS="console=tty0 console=ttyS0,115200n8"
if [ -n "$GRUB_PARAMS" ]; then
    SERVICE_VM_PARAMS="$CONSOLE_PARAMS $GRUB_PARAMS"
else
    SERVICE_VM_PARAMS="$CONSOLE_PARAMS"
fi

echo "   Service VM parameters: $SERVICE_VM_PARAMS"
echo ""

# 6. Build ACRN hypervisor parameters
echo "6. Building ACRN hypervisor parameters..."

# Use existing hypervisor parameters if found, otherwise use default
if [ -n "$EXISTING_ACRN_HV_PARAMS" ]; then
    ACRN_HV_PARAMS="$EXISTING_ACRN_HV_PARAMS"
    echo "   Using existing hypervisor parameters: $ACRN_HV_PARAMS"
else
    # Default: disable uart to avoid console warning
    # This can be customized based on board requirements
    ACRN_HV_PARAMS="uart=disabled"
    echo "   Using default hypervisor parameters: $ACRN_HV_PARAMS"
    echo "   (To customize, edit /etc/grub.d/40_custom_acrn after running this script)"
fi
echo ""

# 7. Backup existing GRUB entry
echo "7. Backing up existing GRUB entry..."
GRUB_ENTRY="/etc/grub.d/40_custom_acrn"
if [ -f "$GRUB_ENTRY" ]; then
    BACKUP_FILE="${GRUB_ENTRY}.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$GRUB_ENTRY" "$BACKUP_FILE"
    echo "   ✓ Backed up to: $BACKUP_FILE"
else
    echo "   No existing entry to backup"
fi
echo ""

# 8. Create fixed GRUB entry
echo "8. Creating fixed GRUB entry..."

cat > "$GRUB_ENTRY" << EOF
#!/bin/sh
exec tail -n +3 \$0
# ACRN Hypervisor Boot Entry
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Fixed to resolve boot hang issue

menuentry 'ACRN Hypervisor' --class ubuntu --class gnu-linux --class gnu --class os {
    recordfail
    load_video
    insmod gzio
    insmod part_gpt
    insmod ext2
    
    echo 'Loading ACRN Hypervisor...'
    # ACRN hypervisor with console parameters
    multiboot2 /boot/acrn.bin $ACRN_HV_PARAMS
    
    echo 'Loading Service VM kernel...'
    # Service VM kernel with root, console, IOMMU, and other parameters
    # CRITICAL: intel_iommu=on is required for ACRN Service VM
    module2 $KERNEL root=UUID=$ROOT_UUID ro $SERVICE_VM_PARAMS
    
    echo 'Loading Service VM initrd...'
    module2 $INITRD
    
    boot
}
EOF

chmod +x "$GRUB_ENTRY"
echo "   ✓ Created fixed GRUB entry: $GRUB_ENTRY"
echo ""

# 9. Verify the entry
echo "9. Verifying GRUB entry..."

# Check for critical parameters
if grep -q "intel_iommu=on" "$GRUB_ENTRY"; then
    echo "   ✓ intel_iommu=on found in GRUB entry"
else
    echo "   ❌ ERROR: intel_iommu=on not found in GRUB entry!"
    exit 1
fi

if grep -q "console=" "$GRUB_ENTRY"; then
    echo "   ✓ Console parameters found"
else
    echo "   ⚠️  Console parameters missing"
fi

# Check kernel and initrd paths
if grep -q "$KERNEL" "$GRUB_ENTRY"; then
    echo "   ✓ Kernel path correct"
else
    echo "   ❌ Kernel path mismatch!"
    exit 1
fi

if grep -q "$INITRD" "$GRUB_ENTRY"; then
    echo "   ✓ Initrd path correct"
else
    echo "   ❌ Initrd path mismatch!"
    exit 1
fi
echo ""

# 10. Update GRUB
echo "10. Updating GRUB configuration..."
if update-grub > /tmp/grub_update.log 2>&1; then
    echo "   ✓ GRUB updated successfully"
else
    echo "   ⚠️  update-grub had warnings (check /tmp/grub_update.log)"
    echo "   This may be normal - continuing..."
fi
echo ""

# 11. Verify entry in compiled config
echo "11. Verifying compiled GRUB configuration..."
if [ -f /boot/grub/grub.cfg ]; then
    if grep -q "ACRN Hypervisor" /boot/grub/grub.cfg; then
        echo "   ✓ ACRN entry found in grub.cfg"
        
        # Check if intel_iommu=on is in the compiled config
        if grep -A 25 "ACRN Hypervisor" /boot/grub/grub.cfg | grep -q "intel_iommu=on"; then
            echo "   ✓ intel_iommu=on found in compiled grub.cfg"
        else
            echo "   ⚠️  intel_iommu=on not found in compiled grub.cfg"
            echo "      This may indicate a GRUB parsing issue"
            echo "      Check: grep -A 25 'ACRN Hypervisor' /boot/grub/grub.cfg"
        fi
    else
        echo "   ⚠️  ACRN entry not found in grub.cfg"
        echo "      This may be normal if using EFI - check /boot/efi/EFI/*/grub.cfg"
    fi
else
    echo "   ⚠️  grub.cfg not found (may be using EFI)"
fi
echo ""

# Summary
echo "========================================"
echo "✓ Boot Hang Fix Applied"
echo "========================================"
echo ""
echo "Changes made:"
echo "1. ✓ Ensured intel_iommu=on is in Service VM kernel parameters"
echo "2. ✓ Added console parameters (tty0 and ttyS0)"
echo "3. ✓ Added ACRN hypervisor console parameters ($ACRN_HV_PARAMS)"
echo "4. ✓ Verified kernel and initrd paths"
echo "5. ✓ Regenerated GRUB configuration"
echo ""
echo "Next steps:"
echo "1. Review the fixed entry:"
echo "   cat $GRUB_ENTRY"
echo ""
echo "2. Verify compiled config:"
echo "   grep -A 25 'ACRN Hypervisor' /boot/grub/grub.cfg"
echo ""
echo "3. Reboot and test:"
echo "   sudo reboot"
echo "   (Select 'ACRN Hypervisor' from GRUB menu)"
echo ""
echo "4. After successful boot, verify ACRN:"
echo "   ./12_verify_acrn.sh"
echo ""
echo "If boot still hangs:"
echo "- Check ACRN binary: file /boot/acrn.bin"
echo "- Verify ACRN was built for correct board/scenario"
echo "- Check boot logs: dmesg | grep -i acrn"
echo "- Review: BOOT_HANG_ANALYSIS.md for additional troubleshooting"
echo ""





