#!/bin/bash
#
# Script: 04_download_acrn_3.3.sh
# Purpose: Download Intel ACRN 3.3 source code
# Usage: ./04_download_acrn_3.3.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ACRN_VERSION="3.3"
ACRN_DIR="$PROJECT_ROOT/acrn-hypervisor"
ACRN_URL="https://github.com/projectacrn/acrn-hypervisor.git"

echo "========================================"
echo "Download ACRN $ACRN_VERSION"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Installing git..."
    sudo apt-get update -qq
    sudo apt-get install -y git
fi

# Check if directory exists
if [ -d "$ACRN_DIR" ]; then
    echo "ACRN directory exists: $ACRN_DIR"
    echo "Checking if it's a git repository..."
    
    if [ -d "$ACRN_DIR/.git" ]; then
        echo "Existing git repository found"
        cd "$ACRN_DIR"
        
        # Check current branch/tag
        CURRENT_TAG=$(git describe --tags --exact-match 2>/dev/null || echo "")
        if [ "$CURRENT_TAG" = "v${ACRN_VERSION}" ]; then
            echo "✓ Already on ACRN v${ACRN_VERSION}"
            exit 0
        fi
        
        echo "Fetching latest changes..."
        git fetch --tags
        
        echo "Checking out v${ACRN_VERSION}..."
        git checkout "v${ACRN_VERSION}" || {
            echo "⚠️  Tag v${ACRN_VERSION} not found, trying branch..."
            git checkout "release_${ACRN_VERSION}" || {
                echo "⚠️  Branch not found, using master and checking out closest tag"
                git checkout master
                git pull
                # Try to find closest version tag
                CLOSEST_TAG=$(git tag | grep -E "^v?${ACRN_VERSION}" | head -1 || echo "")
                if [ -n "$CLOSEST_TAG" ]; then
                    git checkout "$CLOSEST_TAG"
                    echo "✓ Checked out $CLOSEST_TAG"
                else
                    echo "⚠️  Using master branch (may not be v${ACRN_VERSION})"
                fi
            }
        }
    else
        echo "Directory exists but not a git repo, removing..."
        rm -rf "$ACRN_DIR"
        echo "Cloning ACRN repository..."
        git clone "$ACRN_URL" "$ACRN_DIR"
        cd "$ACRN_DIR"
        git checkout "v${ACRN_VERSION}" 2>/dev/null || \
        git checkout "release_${ACRN_VERSION}" 2>/dev/null || {
            echo "⚠️  Using master branch"
        }
    fi
else
    echo "Cloning ACRN repository..."
    git clone "$ACRN_URL" "$ACRN_DIR"
    cd "$ACRN_DIR"
    
    # Try to checkout specific version
    echo "Checking out v${ACRN_VERSION}..."
    git checkout "v${ACRN_VERSION}" 2>/dev/null || \
    git checkout "release_${ACRN_VERSION}" 2>/dev/null || {
        echo "⚠️  Version tag not found, using master"
        echo "   Available tags:"
        git tag | grep -E "^v?3\." | tail -5 || true
    }
fi

echo ""
echo "========================================"
echo "✓ ACRN source downloaded"
echo "Location: $ACRN_DIR"
echo "Version: $(git describe --tags 2>/dev/null || echo 'unknown')"
echo "========================================"

