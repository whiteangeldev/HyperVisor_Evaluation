#!/bin/bash
#
# Script: 12_build_xen_minimal.sh
# Purpose: Build Xen from source with RTDS (minimal dependencies, faster)
# Usage: sudo ./12_build_xen_minimal.sh
#
# This version skips documentation building for faster compilation
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Run as: sudo $0"
    exit 1
fi

echo "=========================================="
echo "Build Xen from Source with RTDS (Minimal)"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This will:"
echo "  • Take 20-40 minutes (faster than full build)"
echo "  • Require ~3GB disk space"
echo "  • Download and compile Xen 4.17"
echo "  • Replace your existing Xen installation"
echo "  • Skip documentation building"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Step 1: Install Essential Build Dependencies"
echo "=========================================="

apt-get update
apt-get install -y \
    build-essential \
    gcc \
    make \
    bison \
    flex \
    git \
    wget \
    python3 \
    python3-dev \
    python3-setuptools \
    libncurses-dev \
    libssl-dev \
    libpci-dev \
    libaio-dev \
    libyajl-dev \
    libpixman-1-dev \
    libc6-dev \
    zlib1g-dev \
    uuid-dev \
    libx11-dev \
    xz-utils \
    bzip2 \
    patch \
    kmod \
    bridge-utils \
    iproute2 \
    acpica-tools \
    gawk \
    pkg-config \
    libglib2.0-dev \
    libsystemd-dev \
    ninja-build

echo "✓ Essential dependencies installed"
echo ""

# Create build directory
BUILD_DIR="/usr/local/src/xen-rtds-build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "Step 2: Download Xen Source"
echo "=========================================="

XEN_VERSION="4.17.4"
if [ ! -f "xen-$XEN_VERSION.tar.gz" ]; then
    echo "Downloading Xen $XEN_VERSION..."
    wget https://downloads.xenproject.org/release/xen/$XEN_VERSION/xen-$XEN_VERSION.tar.gz
else
    echo "Source tarball already exists, using cached version"
fi

if [ -d "xen-$XEN_VERSION" ]; then
    echo "Removing old source directory..."
    rm -rf "xen-$XEN_VERSION"
fi

echo "Extracting..."
tar xzf xen-$XEN_VERSION.tar.gz
cd xen-$XEN_VERSION

echo "✓ Xen source ready"
echo ""

echo "Step 3: Configure Build"
echo "=========================================="

# Create minimal config file
cat > .config << EOF
# Xen Minimal Build Configuration with RTDS Scheduler
# This builds only the hypervisor and essential tools

# Enable RTDS scheduler
CONFIG_SCHED_RTDS=y
CONFIG_SCHED_CREDIT=y
CONFIG_SCHED_CREDIT2=y
CONFIG_SCHED_NULL=y

# Skip documentation
CONFIG_DOCS=n
EOF

echo "Configuration:"
cat .config
echo ""

echo "Step 4: Configure Xen (without docs)"
echo "=========================================="

./configure \
    --prefix=/usr \
    --enable-systemd \
    --disable-docs \
    --disable-stubdom

echo "✓ Configure complete"
echo ""

echo "Step 5: Build Xen Hypervisor (20-40 minutes)"
echo "=========================================="
echo "Started at: $(date)"
echo ""
echo "Building hypervisor and essential tools only..."

# Build only xen hypervisor and tools (skip docs and stubdom)
make -j$(nproc) xen
make -j$(nproc) tools

echo ""
echo "✓ Build complete at: $(date)"
echo ""

echo "Step 6: Backup Current Xen Installation"
echo "=========================================="

BACKUP_DIR="/root/xen-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [ -f /boot/xen.gz ]; then
    echo "Backing up current Xen..."
    cp -r /boot/xen* "$BACKUP_DIR/" 2>/dev/null || true
    cp -r /usr/lib/xen "$BACKUP_DIR/lib-xen" 2>/dev/null || true
    cp -r /etc/xen "$BACKUP_DIR/etc-xen" 2>/dev/null || true
    echo "✓ Backup saved to: $BACKUP_DIR"
fi
echo ""

echo "Step 7: Install Xen"
echo "=========================================="

# Install hypervisor
make install-xen

# Install tools
make install-tools

echo "✓ Xen installed"
echo ""

echo "Step 8: Update Initramfs and GRUB"
echo "=========================================="

# Update initramfs
echo "Updating initramfs..."
update-initramfs -u

# Update GRUB
echo "Updating GRUB..."
update-grub

echo "✓ Boot configuration updated"
echo ""

echo "Step 9: Verify Build"
echo "=========================================="

echo "Checking installed Xen version..."
ls -lh /boot/xen*

echo ""
echo "Checking GRUB entries..."
grep -c "^menuentry.*Xen" /boot/grub/grub.cfg || echo "0"
echo "Xen menu entries found"

echo ""

echo "=========================================="
echo "✓ Build Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  • Xen $XEN_VERSION built with RTDS support"
echo "  • Installed to: /usr"
echo "  • Boot files in: /boot"
echo "  • Backup saved to: $BACKUP_DIR"
echo ""
echo "Build time was faster because:"
echo "  ✓ Skipped documentation building"
echo "  ✓ Skipped stubdom building"
echo "  ✓ Built only hypervisor + essential tools"
echo ""
echo "Next Steps:"
echo ""
echo "1. REBOOT into new Xen:"
echo "   sudo reboot"
echo ""
echo "2. After reboot, check you're running custom Xen:"
echo "   sudo xl info | grep xen_version"
echo "   # Should show: 4.17.4"
echo ""
echo "3. Fix the 'placeholder' GRUB issue:"
echo "   sudo ~/milestone1/scripts/09h_fix_xen_scheduler.sh"
echo "   sudo reboot"
echo ""
echo "4. Verify RTDS is available:"
echo "   sudo xl cpupool-create name=\"test\" sched=\"rtds\""
echo "   sudo xl cpupool-list"
echo "   sudo xl cpupool-destroy test"
echo ""
echo "5. If RTDS works, set up RT cpupool:"
echo "   sudo ~/milestone1/scripts/10_setup_rtds_cpupool.sh"
echo ""
echo "⚠️  REBOOT NOW: sudo reboot"
echo ""

