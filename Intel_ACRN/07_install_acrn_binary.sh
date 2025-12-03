#!/bin/bash
#
# Script: 07_install_acrn_binary.sh
# Purpose: Install ACRN binary and tools to system
# Usage: sudo ./07_install_acrn_binary.sh

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ACRN_DIR="$PROJECT_ROOT/acrn-hypervisor"
BUILD_DIR="$ACRN_DIR/build"

echo "========================================"
echo "Install ACRN Binary"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Find ACRN binary - PRIORITIZE ELF FORMAT (.32.out) for GRUB multiboot2
ACRN_BINARY=""
ACRN_INSTALL_NAME=""

if [ -f "$BUILD_DIR/hypervisor/acrn.32.out" ]; then
    ACRN_BINARY="$BUILD_DIR/hypervisor/acrn.32.out"
    ACRN_INSTALL_NAME="acrn.32.out"
elif [ -f "$BUILD_DIR/hypervisor/acrn.64.out" ]; then
    ACRN_BINARY="$BUILD_DIR/hypervisor/acrn.64.out"
    ACRN_INSTALL_NAME="acrn.64.out"
elif [ -f "$BUILD_DIR/hypervisor/acrn.bin" ]; then
    ACRN_BINARY="$BUILD_DIR/hypervisor/acrn.bin"
    ACRN_INSTALL_NAME="acrn.bin"
    echo "⚠️  WARNING: acrn.bin is raw binary format"
    echo "   GRUB multiboot2 requires ELF format (.32.out or .64.out)"
    echo "   This binary may not work with multiboot2!"
else
    echo "Searching for ACRN binary..."
    ACRN_BINARY=$(find "$BUILD_DIR" -name "acrn.*.out" -o -name "acrn.bin" 2>/dev/null | grep -E "acrn\.(32|64)\.out$" | head -1)
    if [ -z "$ACRN_BINARY" ]; then
        ACRN_BINARY=$(find "$BUILD_DIR" -name "acrn.bin" 2>/dev/null | head -1)
    fi
    if [ -n "$ACRN_BINARY" ]; then
        ACRN_INSTALL_NAME=$(basename "$ACRN_BINARY")
    fi
fi

if [ -z "$ACRN_BINARY" ] || [ ! -f "$ACRN_BINARY" ]; then
    echo "❌ ACRN binary not found. Run 06_build_acrn.sh first"
    exit 1
fi

echo "Found ACRN binary: $ACRN_BINARY"
file "$ACRN_BINARY"
ls -lh "$ACRN_BINARY"
echo ""

# Verify it's an ELF executable (required for GRUB multiboot2)
if file "$ACRN_BINARY" | grep -q "ELF.*executable"; then
    echo "✓ Binary is ELF executable (compatible with GRUB multiboot2)"
elif file "$ACRN_BINARY" | grep -q "data"; then
    echo "❌ WARNING: Binary is raw data format, NOT ELF!"
    echo "   GRUB multiboot2 command requires ELF format"
    echo "   Boot will likely FAIL!"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# Install hypervisor binary
echo "Installing ACRN hypervisor to /boot..."
cp "$ACRN_BINARY" "/boot/$ACRN_INSTALL_NAME"
chmod 644 "/boot/$ACRN_INSTALL_NAME"
echo "✓ Installed to /boot/$ACRN_INSTALL_NAME"

# Create symlink for compatibility
if [ "$ACRN_INSTALL_NAME" != "acrn.bin" ]; then
    ln -sf "/boot/$ACRN_INSTALL_NAME" /boot/acrn.bin
    echo "✓ Created symlink /boot/acrn.bin -> /boot/$ACRN_INSTALL_NAME"
fi
echo ""

# Install ACRN tools if available
if [ -d "$BUILD_DIR/devicemodel" ]; then
    echo "Installing ACRN tools..."
    
    # acrn-dm
    if [ -f "$BUILD_DIR/devicemodel/acrn-dm" ]; then
        cp "$BUILD_DIR/devicemodel/acrn-dm" /usr/bin/acrn-dm
        chmod +x /usr/bin/acrn-dm
        echo "✓ Installed acrn-dm"
    fi
    
    # acrnctl
    if [ -f "$BUILD_DIR/tools/acrnctl/acrnctl" ]; then
        cp "$BUILD_DIR/tools/acrnctl/acrnctl" /usr/bin/acrnctl
        chmod +x /usr/bin/acrnctl
        echo "✓ Installed acrnctl"
    fi
    
    # acrnlog
    if [ -f "$BUILD_DIR/tools/acrnlog/acrnlog" ]; then
        cp "$BUILD_DIR/tools/acrnlog/acrnlog" /usr/bin/acrnlog
        chmod +x /usr/bin/acrnlog
        echo "✓ Installed acrnlog"
    fi
fi

# Install from packages if tools not found in build
if ! command -v acrn-dm &> /dev/null; then
    echo ""
    echo "⚠️  acrn-dm not found in build. Trying to install from packages..."
    if command -v apt-get &> /dev/null; then
        apt-get update -qq
        apt-get install -y acrn-device-model acrn-tools 2>/dev/null || {
            echo "  Package not available - tools will need manual installation"
        }
    fi
fi

echo ""
echo "========================================"
echo "✓ ACRN installation completed"
echo "========================================"
echo ""
echo "Installed files:"
echo "  /boot/$ACRN_INSTALL_NAME"
[ -f /usr/bin/acrn-dm ] && echo "  /usr/bin/acrn-dm"
[ -f /usr/bin/acrnctl ] && echo "  /usr/bin/acrnctl"
[ -f /usr/bin/acrnlog ] && echo "  /usr/bin/acrnlog"
echo ""
echo "Next: Run sudo ./08_configure_grub_iommu.sh"
