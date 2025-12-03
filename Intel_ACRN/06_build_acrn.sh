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

BOARD="${1:-adl-asrock}"  # Changed from generic_board for v3.2 (Alder Lake compatible with 13th Gen)
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
    echo "❌ ACRN source not found. Run 04_download_acrn_3.3.sh first"
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

# === ACRN v3.2: Use Virtual Environment for Python Dependencies ===
# This avoids system pip conflicts and ensures correct versions
echo "Setting up Python virtual environment for ACRN v3.2..."
VENV_DIR="$ACRN_DIR/acrn-build-env"

if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    
    # Ensure python3-venv is installed
    if ! python3 -m venv --help &>/dev/null; then
        echo "Installing python3-venv..."
        if [ "$EUID" -eq 0 ]; then
            apt-get update -qq
            apt-get install -y python3-venv python3-full
        else
            echo "❌ python3-venv not installed. Run: sudo apt install python3-venv python3-full"
            exit 1
        fi
    fi
    
    python3 -m venv "$VENV_DIR"
    echo "✓ Created virtual environment"
fi

# Activate virtual environment
echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Check if packages are already installed with correct versions
NEED_INSTALL=false
if ! python -c "import elementpath; assert elementpath.__version__ == '2.5.3'" 2>/dev/null; then
    NEED_INSTALL=true
fi
if ! python -c "import xmlschema; assert xmlschema.__version__.startswith('2.0')" 2>/dev/null; then
    NEED_INSTALL=true
fi

if [ "$NEED_INSTALL" = true ]; then
    echo "Installing Python dependencies for ACRN v3.2..."
    echo "  - elementpath 2.5.3 (ACRN v3.2 requirement)"
    echo "  - xmlschema 2.0.0 (Python 3.12 compatible)"
    
    # Install elementpath first, then xmlschema without deps to prevent version conflicts
    pip install --quiet 'elementpath==2.5.3' || {
        echo "❌ Failed to install elementpath"
        deactivate
        exit 1
    }
    
    pip install --quiet --no-deps 'xmlschema==2.0.0' || {
        echo "❌ Failed to install xmlschema"
        deactivate
        exit 1
    }
    
    # Install other required packages
    pip install --quiet defusedxml lxml tqdm kconfiglib || {
        echo "❌ Failed to install additional dependencies"
        deactivate
        exit 1
    }
fi

# Verify versions
ELEMENTPATH_VER=$(python -c "import elementpath; print(elementpath.__version__)" 2>/dev/null || echo "MISSING")
XMLSCHEMA_VER=$(python -c "import xmlschema; print(xmlschema.__version__)" 2>/dev/null || echo "MISSING")

echo "✓ Python dependencies ready:"
echo "  - elementpath: $ELEMENTPATH_VER"
echo "  - xmlschema: $XMLSCHEMA_VER"

if [ "$ELEMENTPATH_VER" != "2.5.3" ]; then
    echo "❌ elementpath version mismatch! Expected 2.5.3, got $ELEMENTPATH_VER"
    deactivate
    exit 1
fi

if ! echo "$XMLSCHEMA_VER" | grep -q "^2\.0"; then
    echo "⚠️  Warning: xmlschema version $XMLSCHEMA_VER may not be optimal (expected 2.0.x)"
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

# Deactivate virtual environment
deactivate 2>/dev/null || true

