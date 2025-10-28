#!/bin/bash
#
# Script: 10_install_xen_build_deps.sh
# Purpose: Install ALL Xen build dependencies at once
# Usage: sudo ./10_install_xen_build_deps.sh
#

if [ "$EUID" -ne 0 ]; then
    echo "❌ Run as: sudo $0"
    exit 1
fi

echo "=========================================="
echo "Install ALL Xen Build Dependencies"
echo "=========================================="
echo ""
echo "This installs every dependency needed to build Xen from source."
echo ""

apt-get update

echo "Installing comprehensive dependency list..."
echo ""

apt-get install -y \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    bison \
    flex \
    git \
    wget \
    curl \
    python3 \
    python3-dev \
    python3-setuptools \
    python3-pip \
    pkg-config \
    libncurses-dev \
    libssl-dev \
    libpci-dev \
    libaio-dev \
    libyajl-dev \
    libpixman-1-dev \
    libc6-dev \
    zlib1g-dev \
    uuid-dev \
    libx11-dev \
    xz-utils \
    bzip2 \
    patch \
    kmod \
    bridge-utils \
    iproute2 \
    acpica-tools \
    gawk \
    libglib2.0-dev \
    libsystemd-dev \
    ninja-build \
    meson \
    libfdt-dev \
    libnl-3-dev \
    libnl-route-3-dev \
    libxml2-dev \
    libxslt1-dev \
    libjpeg-dev \
    libpng-dev \
    libvncserver-dev \
    libsdl1.2-dev \
    libcurl4-openssl-dev \
    libbz2-dev \
    libext2fs-dev \
    gettext \
    markdown \
    pandoc \
    texinfo \
    liblzma-dev \
    libzstd-dev \
    libnuma-dev \
    libcap-ng-dev

echo ""
echo "✓ All dependencies installed successfully!"
echo ""
echo "Installed packages:"
echo "  • Core build tools: gcc, make, cmake, ninja"
echo "  • Python tools: python3, pip, setuptools"
echo "  • Libraries: glib, systemd, pixman, yajl, etc."
echo "  • Compression: zlib, bzip2, lzma, zstd"
echo "  • Graphics: SDL, VNC, X11"
echo "  • Network: libnl3"
echo "  • And more..."
echo ""
echo "You can now build Xen with:"
echo "  sudo ./scripts/30b_build_xen_minimal.sh"
echo ""

