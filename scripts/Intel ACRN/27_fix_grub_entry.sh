#!/bin/bash
#
# Script: 27_fix_grub_entry.sh
# Purpose: Fix ACRN GRUB entry to include intel_iommu=on
# Usage: sudo ./27_fix_grub_entry.sh
#

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

echo "========================================"
echo "Fix ACRN GRUB Entry"
echo "========================================"
echo ""

# Check if ACRN GRUB entry exists
if [ ! -f /etc/grub.d/40_custom_acrn ]; then
    echo "❌ ACRN GRUB entry not found at /etc/grub.d/40_custom_acrn"
    echo "   Run ./25_install_acrn.sh first"
    exit 1
fi

echo "Current ACRN GRUB entry:"
echo "----------------------"
cat /etc/grub.d/40_custom_acrn
echo ""

# Backup
echo "Backing up GRUB entry..."
cp /etc/grub.d/40_custom_acrn /etc/grub.d/40_custom_acrn.backup.$(date +%Y%m%d-%H%M%S)
echo "✓ Backup created"
echo ""

# Get root UUID
ROOT_UUID=$(findmnt -n -o UUID /)
echo "Root partition UUID: $ROOT_UUID"
echo ""

# Fix the GRUB entry
echo "Fixing ACRN GRUB entry..."
cat > /etc/grub.d/40_custom_acrn << EOF
#!/bin/sh
exec tail -n +3 \$0
# ACRN Hypervisor Boot Entry

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
echo "✓ GRUB entry fixed"
echo ""

echo "Updated ACRN GRUB entry:"
echo "----------------------"
cat /etc/grub.d/40_custom_acrn
echo ""

echo "Updating GRUB..."
update-grub
echo "✓ GRUB updated"
echo ""

echo "=========================================="
echo "✓ ACRN GRUB Entry Fixed"
echo "=========================================="
echo ""
echo "Changes made:"
echo "  • Added intel_iommu=on (REQUIRED for ACRN)"
echo "  • Changed rw to ro (read-only root)"
echo "  • Removed unnecessary console parameters"
echo ""
echo "The ACRN entry now has the correct kernel parameters!"
echo ""

