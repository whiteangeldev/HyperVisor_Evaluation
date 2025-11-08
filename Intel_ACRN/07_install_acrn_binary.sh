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

# Find ACRN binary
ACRN_BINARY=""
if [ -f "$BUILD_DIR/hypervisor/acrn.bin" ]; then
    ACRN_BINARY="$BUILD_DIR/hypervisor/acrn.bin"
elif [ -f "$BUILD_DIR/hypervisor/acrn.32.out" ]; then
    ACRN_BINARY="$BUILD_DIR/hypervisor/acrn.32.out"
else
    echo "Searching for ACRN binary..."
    ACRN_BINARY=$(find "$BUILD_DIR" -name "acrn.bin" -o -name "acrn.*.out" 2>/dev/null | head -1)
fi

if [ -z "$ACRN_BINARY" ] || [ ! -f "$ACRN_BINARY" ]; then
    echo "❌ ACRN binary not found. Run 06_build_acrn.sh first"
    exit 1
fi

echo "Found ACRN binary: $ACRN_BINARY"
ls -lh "$ACRN_BINARY"
echo ""

# Install hypervisor binary
echo "Installing ACRN hypervisor to /boot..."
cp "$ACRN_BINARY" /boot/acrn.bin
chmod 644 /boot/acrn.bin
echo "✓ Installed to /boot/acrn.bin"
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
echo "  /boot/acrn.bin"
[ -f /usr/bin/acrn-dm ] && echo "  /usr/bin/acrn-dm"
[ -f /usr/bin/acrnctl ] && echo "  /usr/bin/acrnctl"
[ -f /usr/bin/acrnlog ] && echo "  /usr/bin/acrnlog"
echo ""

