#!/bin/bash
#
# Script: 17_clean_grub_entry.sh
# Purpose: Clean and regenerate GRUB entry without duplicates
# Usage: sudo ./17_clean_grub_entry.sh

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

echo "========================================"
echo "Clean ACRN GRUB Entry"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if ACRN binary exists
if [ ! -f /boot/acrn.bin ]; then
    echo "❌ ACRN binary not found: /boot/acrn.bin"
    echo "   Run 07_install_acrn_binary.sh first"
    exit 1
fi

# Get root UUID
ROOT_UUID=$(findmnt -n -o UUID /)
if [ -z "$ROOT_UUID" ]; then
    echo "❌ Could not determine root filesystem UUID"
    exit 1
fi

echo "Root UUID: $ROOT_UUID"
echo ""

# Find kernel and initrd
KERNEL="/boot/vmlinuz-$(uname -r)"
INITRD="/boot/initrd.img-$(uname -r)"

if [ ! -f "$KERNEL" ]; then
    if [ -L /boot/vmlinuz ]; then
        KERNEL=$(readlink -f /boot/vmlinuz)
    else
        KERNEL=$(ls -t /boot/vmlinuz-* 2>/dev/null | head -1)
        if [ -z "$KERNEL" ]; then
            echo "❌ No kernel found"
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
            echo "⚠️  Initrd not found, will use symlink"
            INITRD="/boot/initrd.img"
        fi
    fi
fi

echo "Kernel: $KERNEL"
echo "Initrd: $INITRD"
echo ""

# Get GRUB parameters from /etc/default/grub (clean source)
GRUB_PARAMS=$(grep "^GRUB_CMDLINE_LINUX=" /etc/default/grub | sed 's/^GRUB_CMDLINE_LINUX=//' | tr -d '"' || echo "")

# Remove existing console parameters to avoid duplicates
GRUB_PARAMS=$(echo "$GRUB_PARAMS" | sed 's/console=[^ ]*//g' | sed 's/  */ /g' | sed 's/^ //' | sed 's/ $//')

# Remove any kernel paths that might have been included
GRUB_PARAMS=$(echo "$GRUB_PARAMS" | sed "s|$KERNEL||g" | sed 's|/boot/vmlinuz[^ ]*||g' | sed 's/  */ /g' | sed 's/^ //' | sed 's/ $//')

# Ensure intel_iommu=on is included
if ! echo "$GRUB_PARAMS" | grep -q "intel_iommu=on"; then
    if [ -n "$GRUB_PARAMS" ]; then
        GRUB_PARAMS="$GRUB_PARAMS intel_iommu=on"
    else
        GRUB_PARAMS="intel_iommu=on"
    fi
    echo "✓ Added intel_iommu=on to parameters"
fi

# Add console parameters for Service VM
CONSOLE_PARAMS="console=tty0 console=ttyS0,115200n8"
if [ -n "$GRUB_PARAMS" ]; then
    SERVICE_VM_PARAMS="$CONSOLE_PARAMS $GRUB_PARAMS"
else
    SERVICE_VM_PARAMS="$CONSOLE_PARAMS"
fi

# Check for ACRN hypervisor parameters from existing entry (if any)
ACRN_HV_PARAMS=""
EXISTING_ENTRY="/etc/grub.d/40_custom_acrn"
if [ -f "$EXISTING_ENTRY" ]; then
    # Extract parameters after acrn.bin, but exclude any paths
    ACRN_HV_PARAMS=$(grep "multiboot2.*acrn.bin" "$EXISTING_ENTRY" | sed 's/.*multiboot2[^ ]* //' | sed 's|/boot/acrn.bin||' | sed 's|acrn.bin||' | sed 's|/boot/||g' | sed 's|/.*||g' | sed 's/  */ /g' | sed 's/^ //' | sed 's/ $//' || echo "")
    # Only keep valid ACRN parameters (hvlog, console, uart, etc.)
    ACRN_HV_PARAMS=$(echo "$ACRN_HV_PARAMS" | grep -oE '(hvlog=|console=|uart=)[^ ]*' | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ //' | sed 's/ $//' || echo "")
    if [ -n "$ACRN_HV_PARAMS" ]; then
        echo "Found ACRN hypervisor parameters: $ACRN_HV_PARAMS"
    fi
fi

echo "Service VM parameters: $SERVICE_VM_PARAMS"
echo ""

# Backup existing GRUB entry
GRUB_ENTRY="/etc/grub.d/40_custom_acrn"
if [ -f "$GRUB_ENTRY" ]; then
    BACKUP_FILE="${GRUB_ENTRY}.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$GRUB_ENTRY" "$BACKUP_FILE"
    echo "✓ Backed up existing GRUB entry to: $BACKUP_FILE"
fi

# Create clean GRUB entry
cat > "$GRUB_ENTRY" << EOF
#!/bin/sh
exec tail -n +3 \$0
# ACRN Hypervisor Boot Entry
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Clean version without duplicates

menuentry 'ACRN Hypervisor' --class ubuntu --class gnu-linux --class gnu --class os {
    recordfail
    load_video
    insmod gzio
    insmod part_gpt
    insmod ext2
    
    echo 'Loading ACRN Hypervisor...'
    # ACRN hypervisor with parameters
    multiboot2 /boot/acrn.bin $ACRN_HV_PARAMS
    
    echo 'Loading Service VM kernel...'
    # Service VM kernel with root, console, IOMMU, and other parameters
    # CRITICAL: intel_iommu=on is required for Service VM
    module2 $KERNEL root=UUID=$ROOT_UUID ro $SERVICE_VM_PARAMS
    
    echo 'Loading Service VM initrd...'
    module2 $INITRD
    
    boot
}
EOF

chmod +x "$GRUB_ENTRY"
echo "✓ Created clean GRUB entry: $GRUB_ENTRY"
echo ""

# Verify the entry has intel_iommu=on and no duplicate kernel paths
if grep -q "intel_iommu=on" "$GRUB_ENTRY"; then
    echo "✓ Verified: intel_iommu=on is in GRUB entry"
else
    echo "❌ ERROR: intel_iommu=on not found in GRUB entry!"
    exit 1
fi

# Check for duplicate kernel paths
KERNEL_COUNT=$(grep "module2.*vmlinuz" "$GRUB_ENTRY" | grep -o "$KERNEL" | wc -l || echo "0")
if [ "$KERNEL_COUNT" -gt 1 ]; then
    echo "⚠️  WARNING: Kernel path appears multiple times in entry"
    echo "   This may cause boot issues"
else
    echo "✓ Verified: No duplicate kernel paths"
fi
echo ""

# Update GRUB
echo "Updating GRUB..."
if update-grub > /dev/null 2>&1; then
    echo "✓ GRUB updated"
else
    echo "⚠️  update-grub had warnings (may be normal)"
fi
echo ""

# Verify entry was created in grub.cfg
if grep -q "ACRN Hypervisor" /boot/grub/grub.cfg 2>/dev/null; then
    echo "✓ ACRN entry found in grub.cfg"
    
    # Check if intel_iommu=on is in the compiled config
    if grep -A 20 "ACRN Hypervisor" /boot/grub/grub.cfg | grep -q "intel_iommu=on"; then
        echo "✓ Verified: intel_iommu=on is in compiled grub.cfg"
    else
        echo "⚠️  intel_iommu=on not found in compiled grub.cfg"
        echo "   This may be a GRUB parsing issue"
    fi
    
    # Check for duplicate kernel paths in compiled config
    MODULE2_LINE=$(grep -A 20 "ACRN Hypervisor" /boot/grub/grub.cfg | grep "module2.*vmlinuz" | head -1)
    if echo "$MODULE2_LINE" | grep -o "$KERNEL" | wc -l | grep -q "^1$"; then
        echo "✓ Verified: No duplicate kernel paths in compiled config"
    else
        echo "⚠️  WARNING: Duplicate kernel paths may still exist in compiled config"
        echo "   Module2 line: $MODULE2_LINE"
    fi
else
    echo "⚠️  ACRN entry not found in grub.cfg (may need manual check)"
fi

echo ""
echo "========================================"
echo "✓ GRUB Entry Cleaned"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Review the cleaned entry: cat $GRUB_ENTRY"
echo "2. Verify compiled config: grep -A 25 'ACRN Hypervisor' /boot/grub/grub.cfg"
echo "3. Reboot and select 'ACRN Hypervisor' from GRUB menu"
echo "4. After boot, run: ./12_verify_acrn.sh"

