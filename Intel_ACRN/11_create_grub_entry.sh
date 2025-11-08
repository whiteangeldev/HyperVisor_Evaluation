#!/bin/bash
#
# Script: 11_create_grub_entry.sh
# Purpose: Create GRUB entry for ACRN hypervisor boot
# Usage: sudo ./11_create_grub_entry.sh

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

echo "========================================"
echo "Create ACRN GRUB Entry"
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
    # Try symlink
    if [ -L /boot/vmlinuz ]; then
        KERNEL=$(readlink -f /boot/vmlinuz)
    else
        echo "⚠️  Kernel not found at $KERNEL"
        echo "   Available kernels:"
        ls -1 /boot/vmlinuz-* 2>/dev/null | head -3
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

# Get GRUB parameters from current config
GRUB_PARAMS=$(grep "^GRUB_CMDLINE_LINUX=" /etc/default/grub | sed 's/^GRUB_CMDLINE_LINUX=//' | tr -d '"' || echo "")

# Create GRUB entry
GRUB_ENTRY="/etc/grub.d/40_custom_acrn"

cat > "$GRUB_ENTRY" << EOF
#!/bin/sh
exec tail -n +3 \$0
# ACRN Hypervisor Boot Entry
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

menuentry 'ACRN Hypervisor' --class ubuntu --class gnu-linux --class gnu --class os {
    recordfail
    load_video
    insmod gzio
    insmod part_gpt
    insmod ext2
    
    echo 'Loading ACRN Hypervisor...'
    multiboot2 /boot/acrn.bin
    
    echo 'Loading Service VM kernel...'
    module2 $KERNEL root=UUID=$ROOT_UUID ro $GRUB_PARAMS
    
    echo 'Loading Service VM initrd...'
    module2 $INITRD
}
EOF

chmod +x "$GRUB_ENTRY"
echo "✓ Created GRUB entry: $GRUB_ENTRY"
echo ""

# Update GRUB
echo "Updating GRUB..."
update-grub > /dev/null 2>&1
echo "✓ GRUB updated"
echo ""

# Verify entry was created
if grep -q "ACRN Hypervisor" /boot/grub/grub.cfg 2>/dev/null; then
    echo "✓ ACRN entry found in GRUB menu"
else
    echo "⚠️  ACRN entry not found in grub.cfg (may need to check manually)"
fi

echo ""
echo "========================================"
echo "✓ ACRN GRUB Entry Created"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Review GRUB entry: cat $GRUB_ENTRY"
echo "2. Reboot and select 'ACRN Hypervisor' from GRUB menu"
echo "3. After boot, run: ./12_verify_acrn.sh"

