#!/bin/bash
#
# Script: 21_build_acrn.sh
# Purpose: Build Intel ACRN hypervisor
# Usage: ./21_build_acrn.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
BUILD_LOG="$LOG_DIR/acrn_build.log"
ACRN_DIR="$PROJECT_ROOT/acrn-hypervisor"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "Build Intel ACRN Hypervisor"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

if [ ! -d "$ACRN_DIR" ]; then
    echo "❌ ERROR: ACRN source directory not found: $ACRN_DIR"
    echo "Run ./scripts/20_download_acrn.sh first"
    exit 1
fi

{
    echo "========================================"
    echo "ACRN BUILD LOG"
    echo "========================================"
    echo "Build Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Source: $ACRN_DIR"
    echo ""
    
    echo "Step 1: Enter ACRN directory..."
    cd "$ACRN_DIR"
    echo "Current directory: $(pwd)"
    echo ""
    
    echo "Step 2: Clean previous builds (if any)..."
    make clean || echo "No previous build to clean"
    echo ""
    
    echo "Step 3: Configure build..."
    # Use industry configuration as baseline
    # Options: industry, hybrid, hybrid_rt
    BOARD="generic"
    SCENARIO="industry"
    
    echo "Board: $BOARD"
    echo "Scenario: $SCENARIO"
    echo ""
    
    # For modern ACRN, use the configurator
    if [ -f "misc/config_tools/configurator/pyodide/Makefile" ]; then
        echo "Detected ACRN 3.x+ with new build system"
        echo "Using industry scenario for real-time workloads"
        echo ""
    fi
    
    echo "Step 4: Build hypervisor..."
    echo "This may take 10-30 minutes depending on system performance..."
    echo ""
    
    # Build with parallel jobs
    NPROC=$(nproc)
    JOBS=$((NPROC > 4 ? 4 : NPROC))
    
    echo "Building with $JOBS parallel jobs..."
    
    # Standard ACRN build
    make -j"$JOBS" hypervisor BOARD="$BOARD" SCENARIO="$SCENARIO"
    
    echo ""
    echo "✓ Hypervisor build complete"
    echo ""
    
    echo "Step 5: Build device model..."
    make -j"$JOBS" devicemodel
    echo "✓ Device model build complete"
    echo ""
    
    echo "Step 6: Build tools..."
    make -j"$JOBS" tools
    echo "✓ Tools build complete"
    echo ""
    
    echo "Step 7: Verify build outputs..."
    echo "Checking for hypervisor binary..."
    
    if [ -f build/hypervisor/acrn.bin ] || [ -f build/hypervisor/acrn.32.out ]; then
        echo "✓ Hypervisor binary found"
        ls -lh build/hypervisor/acrn.* 2>/dev/null | head -5
    else
        echo "⚠ Hypervisor binary location may vary"
        find build -name "acrn.*" -type f | head -5
    fi
    echo ""
    
    echo "Checking for device model..."
    if [ -f build/devicemodel/acrn-dm ]; then
        echo "✓ Device model found"
        ls -lh build/devicemodel/acrn-dm
    else
        find build -name "acrn-dm" -type f | head -5
    fi
    echo ""
    
    echo "========================================"
    echo "Build Complete"
    echo "========================================"
    echo "✓ ACRN hypervisor built successfully"
    echo "Build directory: $ACRN_DIR/build"
    echo ""
    echo "Next steps:"
    echo "1. Install ACRN: sudo ./scripts/22_install_acrn.sh"
    echo "2. Configure ACRN: ./scripts/23_configure_acrn.sh"
    echo ""
    
} 2>&1 | tee "$BUILD_LOG"

echo "✓ Build log saved to: $BUILD_LOG"
echo ""

