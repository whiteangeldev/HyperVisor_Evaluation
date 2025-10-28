#!/bin/bash
#
# Script: 11_cleanup_failed_build.sh
# Purpose: Clean up failed Xen build to start fresh
# Usage: sudo ./11_cleanup_failed_build.sh
#

if [ "$EUID" -ne 0 ]; then
    echo "❌ Run as: sudo $0"
    exit 1
fi

echo "=========================================="
echo "Cleanup Failed Xen Build"
echo "=========================================="
echo ""

BUILD_DIR="/usr/local/src/xen-rtds-build"

if [ -d "$BUILD_DIR" ]; then
    echo "Found build directory: $BUILD_DIR"
    
    # Show size
    SIZE=$(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1)
    echo "Current size: $SIZE"
    echo ""
    
    read -p "Remove build directory? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" = "yes" ]; then
        echo "Removing..."
        rm -rf "$BUILD_DIR"
        echo "✓ Build directory removed"
        echo ""
        
        # Show freed space
        echo "✓ Disk space freed: $SIZE"
    else
        echo "Cleanup cancelled"
        exit 0
    fi
else
    echo "No build directory found at $BUILD_DIR"
    echo "Nothing to clean up"
fi

echo ""
echo "✓ Cleanup complete"
echo ""
echo "You can now run the build script again:"
echo "  sudo ./scripts/30b_build_xen_minimal.sh  (recommended, faster)"
echo "  sudo ./scripts/30_build_xen_with_rtds.sh (full build, fixed)"
echo ""


