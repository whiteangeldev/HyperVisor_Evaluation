#!/bin/bash
#
# Script: 22_install_acrn_deps.sh
# Purpose: Install dependencies for Intel ACRN
# Usage: sudo ./22_install_acrn_deps.sh
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
INSTALL_LOG="$LOG_DIR/acrn_deps_install.log"
 
mkdir -p "$LOG_DIR"
 
echo "========================================"
echo "Intel ACRN Dependencies Installation"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
 
{
    echo "========================================"
    echo "ACRN DEPENDENCIES INSTALLATION LOG"
    echo "========================================"
    echo "Installation Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo ""
    
    echo "Step 1: Update package lists..."
    apt update
    echo "✓ Package lists updated"
    echo ""
    
    echo "Step 2: Install build dependencies..."
    DEBIAN_FRONTEND=noninteractive apt install -y \
        build-essential \
        git \
        make \
        gcc \
        g++ \
        pkg-config \
        libssl-dev \
        libpciaccess-dev \
        uuid-dev \
        libsystemd-dev \
        libevent-dev \
        libxml2-dev \
        libxml2-utils \
        libusb-1.0-0-dev \
        libext2fs-dev \
        libnuma-dev \
        libblkid-dev \
        libsdl2-dev \
        libpixman-1-dev \
        libcjson-dev \
        python3 \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        xsltproc \
        wget \
        curl \
        bc \
        bison \
        flex \
        libelf-dev \
        openssl \
        dwarves \
        zstd \
        iasl \
        nasm
    
    echo "✓ Build dependencies installed"
    echo ""
    
    echo "Step 3: Install Python dependencies..."
    # Note: ACRN 3.2 requires older elementpath version for compatibility
    pip3 install --break-system-packages lxml tqdm defusedxml "elementpath==3.0.2" || \
        pip3 install lxml tqdm defusedxml "elementpath==3.0.2"
    echo "✓ Python dependencies installed"
    echo ""
    
    echo "Step 4: Install QEMU and virtualization tools..."
    DEBIAN_FRONTEND=noninteractive apt install -y \
        qemu-kvm \
        qemu-utils \
        ovmf \
        bridge-utils \
        iproute2
    
    echo "✓ Virtualization tools installed"
    echo ""
    
    echo "Step 5: Verify installations..."
    echo "Build tools:"
    gcc --version | head -1
    make --version | head -1
    python3 --version
    echo ""
    
    echo "Python packages:"
    pip3 list | grep -E "(lxml|xmlschema)" || echo "Python packages installed"
    echo ""
    
    echo "========================================"
    echo "Installation Complete"
    echo "========================================"
    echo "✓ All ACRN dependencies installed successfully"
    echo ""
    echo "Next steps:"
    echo "1. Download ACRN: ./scripts/23_download_acrn.sh"
    echo "2. Build ACRN: ./scripts/24_build_acrn.sh"
    echo ""
    
} 2>&1 | tee "$INSTALL_LOG"
 
echo "✓ Installation log saved to: $INSTALL_LOG"
echo ""
