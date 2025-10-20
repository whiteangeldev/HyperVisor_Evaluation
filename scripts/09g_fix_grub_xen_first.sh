#!/bin/bash
#
# Script: 09g_fix_grub_xen_first.sh
# Purpose: Fix GRUB syntax error and create proper Xen first entry
# Usage: sudo ./09g_fix_grub_xen_first.sh
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Run as: sudo $0"
    exit 1
fi

echo "=========================================="
echo "Fix GRUB Xen Entry"
echo "=========================================="
echo ""

# Remove broken custom file if exists
if [ -f /etc/grub.d/06_xen_first ]; then
    echo "Removing broken custom entry..."
    rm /etc/grub.d/06_xen_first
    echo "✓ Removed"
fi

# Get root UUID
ROOT_UUID=$(findmnt -n -o UUID /)
echo "Root UUID: $ROOT_UUID"
echo ""

# Create proper custom Xen entry
echo "Creating custom Xen entry (will be first)..."

cat > /etc/grub.d/06_xen_first << EOF
#!/bin/sh
exec tail -n +3 \$0

menuentry 'Xen Hypervisor RT (First Boot)' {
    insmod part_gpt
    insmod ext2
    set root='hd0,gpt2'
    search --no-floppy --fs-uuid --set=root 100d0553-886a-4ef1-89f5-62a019731801
    
    echo 'Loading Xen hypervisor...'
    multiboot2 /xen.gz placeholder sched=rtds dom0_max_vcpus=4 dom0_vcpus_pin=0-3 dom0_mem=3899M,max:3899M
    
    echo 'Loading Linux kernel...'
    module2 /vmlinuz-6.8.0-85-generic placeholder root=UUID=${ROOT_UUID} ro intel_iommu=on iommu=pt isolcpus=4-7 nohz_full=4-7 rcu_nocbs=4-7 nosoftlockup nohz=on rcu_nocb_poll idle=poll processor.max_cstate=1 intel_idle.max_cstate=0 intel_pstate=disable tsc=reliable clocksource=tsc
    
    echo 'Loading initrd...'
    module2 --nounzip /initrd.img-6.8.0-85-generic
}
EOF

chmod +x /etc/grub.d/06_xen_first
echo "✓ Created /etc/grub.d/06_xen_first"
echo ""

# Ensure GRUB_DEFAULT is set to 0
echo "Setting GRUB_DEFAULT=0..."
if grep -q "^GRUB_DEFAULT=" /etc/default/grub; then
    sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/' /etc/default/grub
else
    echo 'GRUB_DEFAULT=0' >> /etc/default/grub
fi
echo "✓ Set GRUB_DEFAULT=0"
echo ""

# Test GRUB configuration
echo "Testing GRUB configuration..."
if grub-script-check /etc/grub.d/06_xen_first; then
    echo "✓ Syntax is valid"
else
    echo "❌ Syntax error detected"
    echo "Removing file..."
    rm /etc/grub.d/06_xen_first
    exit 1
fi
echo ""

# Update GRUB
echo "Updating GRUB..."
update-grub 2>&1 | tail -20

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ GRUB updated successfully!"
    echo ""
    echo "Verifying Xen is first entry..."
    grep "^menuentry" /boot/grub/grub.cfg | head -1
    echo ""
    echo "=========================================="
    echo "Fix Complete"
    echo "=========================================="
    echo ""
    echo "✓ Custom Xen entry created as FIRST entry"
    echo "✓ GRUB_DEFAULT=0 (will boot first entry)"
    echo ""
    echo "Reboot now: sudo reboot"
else
    echo "❌ GRUB update failed"
    exit 1
fi



