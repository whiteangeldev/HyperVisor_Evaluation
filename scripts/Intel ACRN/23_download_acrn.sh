#!/bin/bash
#
# Script: 20_download_acrn.sh
# Purpose: Download Intel ACRN source code
# Usage: ./20_download_acrn.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
DOWNLOAD_LOG="$LOG_DIR/acrn_download.log"
ACRN_DIR="$PROJECT_ROOT/acrn-hypervisor"

# ACRN version to download (use stable release)
ACRN_VERSION="v3.2"
ACRN_REPO="https://github.com/projectacrn/acrn-hypervisor.git"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "Download Intel ACRN Source Code"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Version: $ACRN_VERSION"
echo ""

{
    echo "========================================"
    echo "ACRN DOWNLOAD LOG"
    echo "========================================"
    echo "Download Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Version: $ACRN_VERSION"
    echo "Repository: $ACRN_REPO"
    echo ""
    
    if [ -d "$ACRN_DIR" ]; then
        echo "⚠ ACRN directory already exists: $ACRN_DIR"
        echo "Checking if it's a git repository..."
        
        if [ -d "$ACRN_DIR/.git" ]; then
            echo "✓ Found existing ACRN git repository"
            cd "$ACRN_DIR"
            
            echo "Current branch/tag:"
            git branch -v || true
            echo ""
            
            echo "Fetching latest changes..."
            git fetch --all --tags
            echo ""
            
            echo "Checking out $ACRN_VERSION..."
            git checkout "$ACRN_VERSION"
            echo ""
            
            echo "✓ ACRN repository updated to $ACRN_VERSION"
        else
            echo "✗ Directory exists but is not a git repository"
            echo "Please remove or rename: $ACRN_DIR"
            exit 1
        fi
    else
        echo "Step 1: Cloning ACRN repository..."
        git clone "$ACRN_REPO" "$ACRN_DIR"
        echo "✓ Repository cloned"
        echo ""
        
        echo "Step 2: Checking out version $ACRN_VERSION..."
        cd "$ACRN_DIR"
        git checkout "$ACRN_VERSION"
        echo "✓ Checked out $ACRN_VERSION"
        echo ""
    fi
    
    echo "Step 3: Verify download..."
    cd "$ACRN_DIR"
    echo "Current directory: $(pwd)"
    echo ""
    
    echo "Git status:"
    git status
    echo ""
    
    echo "Git log (last commit):"
    git log -1 --oneline
    echo ""
    
    echo "Directory structure:"
    ls -la
    echo ""
    
    echo "========================================"
    echo "Download Complete"
    echo "========================================"
    echo "✓ ACRN source code downloaded successfully"
    echo "Location: $ACRN_DIR"
    echo "Version: $ACRN_VERSION"
    echo ""
    echo "Next steps:"
    echo "1. Review ACRN documentation: cat $ACRN_DIR/README.rst"
    echo "2. Build ACRN: ./scripts/21_build_acrn.sh"
    echo ""
    
} 2>&1 | tee "$DOWNLOAD_LOG"

echo "✓ Download log saved to: $DOWNLOAD_LOG"
echo ""

