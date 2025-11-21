#!/bin/bash
#
# Script: 05_install_build_deps.sh
# Purpose: Install build dependencies for ACRN
# Usage: sudo ./05_install_build_deps.sh

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

echo "========================================"
echo "Install ACRN Build Dependencies"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Update package list
echo "Updating package list..."
apt-get update -qq

# Essential build tools
echo "Installing essential build tools..."
apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
    cmake \
    ninja-build \
    python3 \
    python3-pip

# ACRN specific dependencies
echo "Installing ACRN build dependencies..."
apt-get install -y \
    libsystemd-dev \
    libpciaccess-dev \
    libusb-1.0-0-dev \
    libevent-dev \
    libxml2-dev \
    libxml2-utils \
    xsltproc \
    doxygen \
    graphviz \
    libblkid-dev \
    uuid-dev \
    liblz4-tool \
    libssl-dev \
    libsndfile1-dev \
    libasound2-dev \
    libpulse-dev \
    libcap-ng-dev \
    libattr1-dev \
    libpixman-1-dev \
    libsdl2-dev \
    libsdl2-image-dev \
    libsdl2-ttf-dev \
    libsdl2-gfx-dev \
    libc6-dev-i386 \
    gcc-multilib \
    g++-multilib \
    libc6-dev \
    libncurses5-dev \
    libncursesw5-dev \
    flex \
    bison \
    libtool \
    automake \
    autoconf \
    pkg-config \
    libglib2.0-dev \
    libpixman-1-dev \
    acpica-tools

# Python packages required by ACRN config tools
# Based on misc/config_tools/requirements.txt
# Note: elementpath must be >=2.5.0 but <3.0.0 (TypedElement removed in 3.x)
# Note: xmlschema must be >=2.0.0 for Python 3.12 compatibility
echo "Installing Python packages..."
pip3 install --break-system-packages \
    kconfiglib \
    defusedxml \
    lxml \
    "elementpath>=2.5.0,<3.0.0" \
    "xmlschema>=2.0.0" \
    tqdm 2>/dev/null || \
pip3 install \
    kconfiglib \
    defusedxml \
    lxml \
    "elementpath>=2.5.0,<3.0.0" \
    "xmlschema>=2.0.0" \
    tqdm || true

echo ""
echo "========================================"
echo "✓ Build dependencies installed"
echo "========================================"

