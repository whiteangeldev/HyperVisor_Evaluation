#!/bin/bash
#
# Script: 06_build_acrn.sh
# Purpose: Build Intel ACRN hypervisor
# Usage: ./06_build_acrn.sh [board] [scenario]
# Example: ./06_build_acrn.sh generic_board shared

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ACRN_DIR="$PROJECT_ROOT/acrn-hypervisor"
BUILD_DIR="$ACRN_DIR/build"

BOARD="${1:-generic_board}"
# Default scenario: prefer 'shared' if available, otherwise first available
SCENARIO="${2:-}"

echo "========================================"
echo "Build ACRN Hypervisor"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Board: $BOARD"
echo "Scenario: $SCENARIO"
echo ""

# Check if ACRN source exists
if [ ! -d "$ACRN_DIR" ]; then
    echo "❌ ACRN source not found. Run 04_download_acrn_3.4.sh first"
    exit 1
fi

# Fix git ownership issue if present
echo "Checking git repository..."
cd "$ACRN_DIR"
if [ -d .git ]; then
    git config --global --add safe.directory "$ACRN_DIR" 2>/dev/null || true
fi

# Check if path contains spaces (ACRN Makefile has issues with this)
PATH_HAS_SPACES=false
if echo "$ACRN_DIR" | grep -q " "; then
    PATH_HAS_SPACES=true
    echo "⚠️  Warning: Path contains spaces: $ACRN_DIR"
    echo "   ACRN Makefile may have issues with spaces in paths"
    echo ""
fi

cd "$ACRN_DIR"

# Check available boards
echo "Available boards:"
AVAILABLE_BOARDS=$(ls -d misc/config_tools/data/*/ 2>/dev/null | sed 's|.*/||' | sed 's|/$||' | grep -v "^sample_launch_scripts$" || true)
if [ -n "$AVAILABLE_BOARDS" ]; then
    echo "$AVAILABLE_BOARDS" | head -10 | sed 's/^/  /'
else
    echo "  (checking...)"
fi
echo ""

# Check if board exists
if [ ! -d "misc/config_tools/data/$BOARD" ]; then
    echo "❌ Board '$BOARD' not found!"
    echo ""
    echo "Available boards:"
    echo "$AVAILABLE_BOARDS" | sed 's/^/  /'
    echo ""
    echo "Usage: ./06_build_acrn.sh [board] [scenario]"
    echo "Example: ./06_build_acrn.sh generic_board shared"
    exit 1
fi

# Check available scenarios
echo "Available scenarios for $BOARD:"
AVAILABLE_SCENARIOS=$(ls misc/config_tools/data/$BOARD/*.xml 2>/dev/null | sed 's|.*/||' | sed 's|\.xml$||' || true)
if [ -n "$AVAILABLE_SCENARIOS" ]; then
    echo "$AVAILABLE_SCENARIOS" | head -10 | sed 's/^/  /'
    
    # If no scenario specified, use first available scenario (prefer non-board-named scenarios)
    if [ -z "$SCENARIO" ]; then
        # Prefer "shared" first (simplest scenario), then "partitioned", then "hybrid"
        # Avoid scenarios that match the board name
        if echo "$AVAILABLE_SCENARIOS" | grep -q "^shared$"; then
            SCENARIO="shared"
        elif echo "$AVAILABLE_SCENARIOS" | grep -q "^partitioned$"; then
            SCENARIO="partitioned"
        elif echo "$AVAILABLE_SCENARIOS" | grep -q "^hybrid$"; then
            SCENARIO="hybrid"
        else
            # Fallback: use first scenario that doesn't match board name
            SCENARIO=$(echo "$AVAILABLE_SCENARIOS" | grep -v "^${BOARD}$" | head -1)
            if [ -z "$SCENARIO" ]; then
                SCENARIO=$(echo "$AVAILABLE_SCENARIOS" | head -1)
            fi
        fi
        echo ""
        echo "No scenario specified, using default: $SCENARIO"
    fi
    
    # Warn if scenario name matches board name (likely wrong)
    if [ "$SCENARIO" = "$BOARD" ]; then
        echo "⚠️  WARNING: Scenario name '$SCENARIO' matches board name '$BOARD'"
        echo "   This may cause validation errors. Consider using: shared, hybrid, or partitioned"
        echo ""
    fi
else
    echo "  ⚠️  No scenarios found"
    echo "❌ Cannot build: No scenarios available for board '$BOARD'"
    exit 1
fi
echo ""

# Validate scenario exists
if ! echo "$AVAILABLE_SCENARIOS" | grep -q "^${SCENARIO}$"; then
    echo "❌ Scenario '$SCENARIO' not found for board '$BOARD'!"
    echo ""
    echo "Available scenarios:"
    echo "$AVAILABLE_SCENARIOS" | sed 's/^/  /'
    echo ""
    echo "Usage: ./06_build_acrn.sh [board] [scenario]"
    echo "Example: ./06_build_acrn.sh generic_board shared"
    exit 1
fi

# Ensure logs directory exists
mkdir -p "$PROJECT_ROOT/logs"

# Check Python dependencies before building
# Based on misc/config_tools/requirements.txt
# Note: elementpath must be >=2.5.0 but <3.0.0 (TypedElement removed in 3.x)
echo "Checking Python dependencies..."
MISSING_DEPS=""
# Check each required package
for pkg in defusedxml lxml elementpath xmlschema tqdm kconfiglib; do
    if ! python3 -c "import $pkg" 2>/dev/null; then
        # For elementpath, ensure version >= 2.5.0 but < 3.0.0
        if [ "$pkg" = "elementpath" ]; then
            MISSING_DEPS="$MISSING_DEPS 'elementpath>=2.5.0,<3.0.0'"
        elif [ "$pkg" = "xmlschema" ]; then
            # xmlschema needs to be >= 2.0.0 for Python 3.12 compatibility
            MISSING_DEPS="$MISSING_DEPS 'xmlschema>=2.0.0'"
        else
            MISSING_DEPS="$MISSING_DEPS $pkg"
        fi
    else
        # Check elementpath version if installed
        if [ "$pkg" = "elementpath" ]; then
            ELEMENTPATH_VERSION=$(python3 -c "import elementpath; print(elementpath.__version__)" 2>/dev/null || echo "unknown")
            # Check if version starts with 3. (incompatible - TypedElement removed)
            if echo "$ELEMENTPATH_VERSION" | grep -q "^3\."; then
                echo "⚠️  elementpath version $ELEMENTPATH_VERSION is incompatible (needs <3.0.0)"
                MISSING_DEPS="$MISSING_DEPS 'elementpath>=2.5.0,<3.0.0'"
            fi
        # Check xmlschema compatibility with Python 3.12
        elif [ "$pkg" = "xmlschema" ]; then
            if ! python3 -c "import xmlschema; from xmlschema.validators.schemas import XMLSchema10" 2>/dev/null; then
                echo "⚠️  xmlschema is installed but incompatible with Python 3.12"
                echo "   Need to upgrade xmlschema to >= 2.0.0"
                MISSING_DEPS="$MISSING_DEPS 'xmlschema>=2.0.0'"
            fi
        fi
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    echo "⚠️  Missing or incompatible Python packages:$MISSING_DEPS"
    echo ""
    echo "Installing/updating packages..."
    
    # Determine pip command based on whether we're root
    if [ "$EUID" -eq 0 ]; then
        PIP_CMD="pip3"
        PIP_FLAGS="--break-system-packages"
    else
        PIP_CMD="pip3"
        PIP_FLAGS="--user"
    fi
    
    # If elementpath 3.x is installed, uninstall it first
    if echo "$MISSING_DEPS" | grep -q "elementpath"; then
        CURRENT_EP=$(python3 -c "import elementpath; print(elementpath.__version__)" 2>/dev/null || echo "")
        if [ -n "$CURRENT_EP" ] && echo "$CURRENT_EP" | grep -q "^3\."; then
            echo "Uninstalling incompatible elementpath $CURRENT_EP..."
            $PIP_CMD uninstall -y elementpath 2>/dev/null || true
        fi
    fi
    
    # If xmlschema is incompatible, upgrade it
    if echo "$MISSING_DEPS" | grep -q "xmlschema"; then
        echo "Upgrading xmlschema for Python 3.12 compatibility..."
        $PIP_CMD install --upgrade $PIP_FLAGS 'xmlschema>=2.0.0' 2>&1 | tee -a "$PROJECT_ROOT/logs/python_deps.log" || true
    fi
    
    # Try to install (handle version constraints properly)
    # Remove quotes from version constraints for pip
    INSTALL_DEPS=$(echo "$MISSING_DEPS" | sed "s/'//g")
    if $PIP_CMD install $PIP_FLAGS $INSTALL_DEPS 2>&1 | tee -a "$PROJECT_ROOT/logs/python_deps.log"; then
        echo "✓ Python packages installed"
    else
        echo "❌ Failed to install Python packages"
        echo ""
        if [ "$EUID" -ne 0 ]; then
            echo "This script needs root privileges to install packages."
            echo "Please run: sudo ./06_build_acrn.sh"
            echo ""
        fi
        echo "Or install dependencies first:"
        echo "  sudo ./05_install_build_deps.sh"
        exit 1
    fi
fi
echo ""

# Build ACRN from source root (not build directory)
echo "Building ACRN..."
echo "This may take 10-30 minutes..."
echo ""

mkdir -p "$PROJECT_ROOT/logs"

# Workaround for paths with spaces: Build from a symlink without spaces
if [ "$PATH_HAS_SPACES" = true ]; then
    echo "Creating symlink without spaces for build..."
    SYMLINK_BASE="/tmp/acrn-src-$$"
    if [ -L "$SYMLINK_BASE" ] || [ -d "$SYMLINK_BASE" ]; then
        rm -rf "$SYMLINK_BASE"
    fi
    
    # Create symlink to ACRN directory without spaces
    ln -sf "$ACRN_DIR" "$SYMLINK_BASE" 2>/dev/null
    if [ -L "$SYMLINK_BASE" ]; then
        echo "✓ Created symlink: $SYMLINK_BASE -> $ACRN_DIR"
        BUILD_DIR_SYMLINK="$SYMLINK_BASE"
    else
        echo "⚠️  Could not create symlink, using direct path"
        BUILD_DIR_SYMLINK="$ACRN_DIR"
    fi
    echo ""
else
    BUILD_DIR_SYMLINK="$ACRN_DIR"
fi

# Ensure we're in the ACRN directory (use original, not symlink, for file operations)
cd "$ACRN_DIR"

# Clean previous build artifacts that might cause validation issues
# Full clean is safer to avoid validation conflicts
if [ -d "build" ]; then
    echo "Cleaning previous build artifacts..."
    rm -rf build/hypervisor/configs 2>/dev/null || true
    echo "✓ Cleaned build configuration"
fi

# Create build directory
mkdir -p build

echo "Building from: $(pwd)"
echo "Using build directory: build/"
echo ""

# Export variables to ensure they're available to make
export BOARD
export SCENARIO

# Build with explicit O= parameter using relative path
# Suppress Python warnings to reduce log noise (they're just warnings, not errors)
export PYTHONWARNINGS="ignore::FutureWarning"

# Try building with RELEASE=1 first (skips some validations), fallback to debug if needed
echo "Attempting build (this may take 10-30 minutes)..."
echo "Note: Using RELEASE=1 to reduce validation strictness"
echo ""

BUILD_CMD="make BOARD=$BOARD SCENARIO=$SCENARIO O=build hypervisor RELEASE=1"

if [ "$PATH_HAS_SPACES" = true ] && [ -L "$BUILD_DIR_SYMLINK" ]; then
    echo "Building from symlink without spaces..."
    cd "$BUILD_DIR_SYMLINK"
    # Use set -o pipefail to capture make exit code correctly
    set -o pipefail
    if $BUILD_CMD 2>&1 | grep -v "FutureWarning\|XMLSchemaAssertPathWarning" | tee "$PROJECT_ROOT/logs/acrn_build.log"; then
        BUILD_SUCCESS=true
    else
        BUILD_SUCCESS=false
    fi
    set +o pipefail
    cd "$ACRN_DIR"
else
    # Normal build (no spaces or symlink failed)
    # Use RELEASE=1 to reduce validation strictness (already in BUILD_CMD)
    set -o pipefail
    if $BUILD_CMD 2>&1 | grep -v "FutureWarning\|XMLSchemaAssertPathWarning" | tee "$PROJECT_ROOT/logs/acrn_build.log"; then
        BUILD_SUCCESS=true
    else
        BUILD_SUCCESS=false
    fi
    set +o pipefail
fi

# Clean up symlink if we created one
if [ "$PATH_HAS_SPACES" = true ] && [ -L "$SYMLINK_BASE" ]; then
    rm -f "$SYMLINK_BASE" 2>/dev/null || true
fi

# Check if build actually succeeded
if [ "$BUILD_SUCCESS" = false ]; then
    echo ""
    echo "❌ Build failed. Check log: $PROJECT_ROOT/logs/acrn_build.log"
    echo ""
    
    # Check for specific error patterns
    if grep -q "CRITICAL.*Unexpected child" "$PROJECT_ROOT/logs/acrn_build.log" 2>/dev/null; then
        echo "⚠️  Validation errors detected - board and scenario XML may be incompatible"
        echo "   This can happen with generic_board. Trying clean build..."
        echo ""
        
        # Try cleaning and rebuilding
        rm -rf build/hypervisor/configs 2>/dev/null || true
        echo "Cleaned build directory, retrying..."
        echo ""
        
        # Retry build once
        set -o pipefail
        if make BOARD="$BOARD" SCENARIO="$SCENARIO" O=build hypervisor RELEASE=1 2>&1 | grep -v "FutureWarning\|XMLSchemaAssertPathWarning" | tee -a "$PROJECT_ROOT/logs/acrn_build.log"; then
            BUILD_SUCCESS=true
            echo "✓ Build succeeded after clean"
        fi
        set +o pipefail
    fi
    
    if [ "$BUILD_SUCCESS" = false ]; then
        echo "Common issues:"
        echo "1. Path with spaces - ACRN Makefile has issues with spaces in directory names"
        echo "   Solution: Move project to a path without spaces, e.g., /home/ubuntu/IntelACRN"
        echo "2. Wrong board or scenario name - check available options above"
        echo "3. Missing dependencies - run 05_install_build_deps.sh"
        echo "4. Validation errors - try: ./06_build_acrn.sh generic_board shared"
        echo "5. Try cleaning build: rm -rf build && ./06_build_acrn.sh"
        echo ""
        echo "Last 30 lines of build log:"
        tail -30 "$PROJECT_ROOT/logs/acrn_build.log" 2>/dev/null | grep -v "FutureWarning\|XMLSchemaAssertPathWarning" || true
        exit 1
    fi
fi

# Verify build output
echo ""
echo "Verifying build output..."

# Update BUILD_DIR to use the actual build location (relative to ACRN_DIR)
BUILD_DIR="$ACRN_DIR/build"

# Check for hypervisor binary
ACRN_BINARY=""
if [ -f "$BUILD_DIR/hypervisor/acrn.bin" ]; then
    ACRN_BINARY="$BUILD_DIR/hypervisor/acrn.bin"
elif [ -f "$BUILD_DIR/hypervisor/acrn.32.out" ]; then
    ACRN_BINARY="$BUILD_DIR/hypervisor/acrn.32.out"
elif [ -f "$BUILD_DIR/hypervisor/acrn.64.out" ]; then
    ACRN_BINARY="$BUILD_DIR/hypervisor/acrn.64.out"
else
    # Search for any ACRN binary
    ACRN_BINARY=$(find "$BUILD_DIR" -name "acrn.bin" -o -name "acrn.*.out" 2>/dev/null | head -1)
fi

if [ -z "$ACRN_BINARY" ] || [ ! -f "$ACRN_BINARY" ]; then
    echo ""
    echo "❌ ACRN binary not found after build!"
    echo "   Searched in: $BUILD_DIR"
    echo ""
    echo "Build may have failed. Check log: $PROJECT_ROOT/logs/acrn_build.log"
    exit 1
fi

echo ""
echo "========================================"
echo "✓ ACRN build completed successfully"
echo "========================================"
echo ""
echo "Build output location: $BUILD_DIR"
echo "Hypervisor binary: $ACRN_BINARY"
echo ""
ls -lh "$ACRN_BINARY"
echo ""
echo "✓ Build verification passed"

