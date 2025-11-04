#!/bin/bash
#
# Script: 25_install_acrn.sh
# Purpose: Install Intel ACRN hypervisor to system
# Usage: sudo ./25_install_acrn.sh
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
INSTALL_LOG="$LOG_DIR/acrn_install.log"
ACRN_DIR="$PROJECT_ROOT/acrn-hypervisor"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "Install Intel ACRN Hypervisor"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

if [ ! -d "$ACRN_DIR/build" ]; then
    echo "❌ ERROR: ACRN build directory not found"
    echo "Run ./scripts/21_build_acrn.sh first"
    exit 1
fi

{
    echo "========================================"
    echo "ACRN INSTALLATION LOG"
    echo "========================================"
    echo "Installation Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Source: $ACRN_DIR"
    echo ""
    
    echo "Step 1: Install hypervisor and tools..."
    cd "$ACRN_DIR"
    
    # Install to system
    make install
    
    echo "✓ ACRN components installed"
    echo ""
    
    echo "Step 2: Create ACRN directory structure..."
    mkdir -p /etc/acrn
    mkdir -p /var/lib/acrn
    mkdir -p /usr/share/acrn
    echo "✓ Directories created"
    echo ""
    
    echo "Step 3: Verify installation..."
    echo "Checking installed files:"
    
    if [ -f /usr/bin/acrn-dm ]; then
        echo "✓ Device model: /usr/bin/acrn-dm"
        ls -lh /usr/bin/acrn-dm
    else
        echo "⚠ Device model not found at /usr/bin/acrn-dm"
    fi
    
    if [ -f /usr/bin/acrnctl ]; then
        echo "✓ Control tool: /usr/bin/acrnctl"
        ls -lh /usr/bin/acrnctl
    else
        echo "⚠ Control tool not found at /usr/bin/acrnctl"
    fi
    
    if [ -d /usr/share/acrn ]; then
        echo "✓ ACRN share directory exists"
        ls -la /usr/share/acrn | head -10
    fi
    echo ""
    
    echo "Step 4: Copy hypervisor binary to /boot..."
    if [ -f build/hypervisor/acrn.bin ]; then
        cp build/hypervisor/acrn.bin /boot/acrn.bin
        echo "✓ Copied acrn.bin to /boot/"
    elif [ -f build/hypervisor/acrn.32.out ]; then
        cp build/hypervisor/acrn.32.out /boot/acrn.32.out
        echo "✓ Copied acrn.32.out to /boot/"
    else
        echo "⚠ Warning: Hypervisor binary not found in expected location"
        echo "Searching for hypervisor binary..."
        find build -name "acrn.*" -type f
    fi
    echo ""
    
    echo "Step 5: Update GRUB for ACRN..."
    echo "Creating ACRN GRUB entry..."
    
    # Backup existing GRUB config
    if [ -f /etc/default/grub ]; then
        cp /etc/default/grub /etc/default/grub.bak.acrn
        echo "✓ Backed up GRUB config"
    fi
    
    # Add ACRN multiboot entry to GRUB
    cat > /etc/grub.d/40_custom_acrn << 'EOF'
#!/bin/sh
exec tail -n +3 $0
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
    module2 /boot/vmlinuz root=UUID=REPLACEME ro intel_iommu=on 
    
    echo 'Loading Service VM initrd...'
    module2 /boot/initrd.img
}
EOF
    
    # Get root UUID
    ROOT_UUID=$(findmnt -n -o UUID /)
    sed -i "s/REPLACEME/$ROOT_UUID/" /etc/grub.d/40_custom_acrn
    
    chmod +x /etc/grub.d/40_custom_acrn
    echo "✓ Created ACRN GRUB entry"
    echo ""
    
    echo "Step 6: Update GRUB..."
    update-grub
    echo "✓ GRUB updated"
    echo ""
    
    echo "Step 7: Load ACRN kernel modules (if available)..."
    if [ -f /lib/modules/$(uname -r)/kernel/drivers/acrn/acrn.ko ]; then
        modprobe acrn || echo "Module load will work after reboot"
    else
        echo "⚠ ACRN kernel module not found (will be loaded on boot)"
    fi
    echo ""
    
    echo "========================================"
    echo "Installation Complete"
    echo "========================================"
    echo "✓ ACRN hypervisor installed successfully"
    echo ""
    echo "Files installed:"
    echo "  - Hypervisor: /boot/acrn.bin (or acrn.32.out)"
    echo "  - Device Model: /usr/bin/acrn-dm"
    echo "  - Tools: /usr/bin/acrnctl, acrnlog, etc."
    echo "  - GRUB entry: /etc/grub.d/40_custom_acrn"
    echo ""
    echo "⚠️  IMPORTANT: Review and edit GRUB entry before booting!"
    echo "Edit /etc/grub.d/40_custom_acrn to ensure correct kernel paths"
    echo ""
    echo "Next steps:"
    echo "1. Configure ACRN: ./scripts/26_configure_acrn.sh"
    echo "2. Review GRUB entry: sudo cat /etc/grub.d/40_custom_acrn"
    echo "3. Reboot and select 'ACRN Hypervisor' from GRUB menu"
    echo ""
    
} 2>&1 | tee "$INSTALL_LOG"

echo "✓ Installation log saved to: $INSTALL_LOG"
echo ""

