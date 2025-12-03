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

# Check if ACRN binary exists (prefer ELF format)
ACRN_BINARY=""
if [ -f /boot/acrn.32.out ]; then
    ACRN_BINARY="/boot/acrn.32.out"
elif [ -f /boot/acrn.64.out ]; then
    ACRN_BINARY="/boot/acrn.64.out"
elif [ -f /boot/acrn.bin ]; then
    ACRN_BINARY="/boot/acrn.bin"
    # Check if it's ELF or raw binary
    if ! file /boot/acrn.bin | grep -q "ELF.*executable"; then
        echo "⚠️  WARNING: /boot/acrn.bin is NOT an ELF executable"
        echo "   GRUB multiboot2 requires ELF format"
        echo "   Boot may fail!"
        echo ""
    fi
else
    echo "❌ ACRN binary not found in /boot/"
    echo "   Run 07_install_acrn_binary.sh first"
    exit 1
fi

echo "Using ACRN binary: $ACRN_BINARY"
file "$ACRN_BINARY"
echo ""

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

# Remove existing console parameters to avoid duplicates
GRUB_PARAMS=$(echo "$GRUB_PARAMS" | sed 's/console=[^ ]*//g' | sed 's/  */ /g' | sed 's/^ //' | sed 's/ $//')

# Ensure intel_iommu=on is included (CRITICAL for ACRN Service VM)
if ! echo "$GRUB_PARAMS" | grep -q "intel_iommu=on"; then
    if [ -n "$GRUB_PARAMS" ]; then
        GRUB_PARAMS="$GRUB_PARAMS intel_iommu=on"
    else
        GRUB_PARAMS="intel_iommu=on"
    fi
    echo "✓ Added intel_iommu=on to Service VM parameters"
fi

# Add console parameters for Service VM
CONSOLE_PARAMS="console=tty0 console=ttyS0,115200n8"
if [ -n "$GRUB_PARAMS" ]; then
    SERVICE_VM_PARAMS="$CONSOLE_PARAMS $GRUB_PARAMS"
else
    SERVICE_VM_PARAMS="$CONSOLE_PARAMS"
fi

# Create GRUB entry
GRUB_ENTRY="/etc/grub.d/40_custom_acrn"

cat > "$GRUB_ENTRY" << EOF
#!/bin/sh
exec tail -n +3 \$0
# ACRN Hypervisor Boot Entry (v3.2)
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

menuentry 'ACRN Hypervisor' --class ubuntu --class gnu-linux --class gnu --class os {
    recordfail
    load_video
    insmod gzio
    insmod part_gpt
    insmod ext2
    
    echo 'Loading ACRN Hypervisor...'
    # ACRN hypervisor (ELF format required for multiboot2)
    multiboot2 $ACRN_BINARY
    
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
echo "✓ Created GRUB entry: $GRUB_ENTRY"
echo ""

# Ensure GRUB menu is visible (user mentioned needing to set this manually)
GRUB_DEFAULT_FILE="/etc/default/grub"
if [ -f "$GRUB_DEFAULT_FILE" ]; then
    # Check if GRUB_TIMEOUT is set and > 0
    if ! grep -q "^GRUB_TIMEOUT=" "$GRUB_DEFAULT_FILE" || grep -q "^GRUB_TIMEOUT=0" "$GRUB_DEFAULT_FILE"; then
        echo "⚠️  GRUB_TIMEOUT is 0 or not set - menu may be hidden"
        echo "   Consider setting GRUB_TIMEOUT=5 in /etc/default/grub"
        echo "   Or set GRUB_HIDDEN_TIMEOUT=0 to always show menu"
    fi
fi
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
