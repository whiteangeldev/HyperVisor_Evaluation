#!/bin/bash
#
# Script: 03_check_kernel_rt.sh
# Purpose: Check if PREEMPT_RT kernel is installed
# Usage: ./03_check_kernel_rt.sh

set -e

echo "========================================"
echo "Kernel PREEMPT_RT Check"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Current kernel version
KERNEL_VERSION=$(uname -r)
echo "Current Kernel: $KERNEL_VERSION"
echo ""

# Check kernel config for PREEMPT_RT
echo "1. Kernel Configuration:"
if [ -f /boot/config-${KERNEL_VERSION} ]; then
    CONFIG_FILE="/boot/config-${KERNEL_VERSION}"
elif [ -f /proc/config.gz ]; then
    echo "   Extracting from /proc/config.gz..."
    zcat /proc/config.gz > /tmp/kernel_config 2>/dev/null || true
    CONFIG_FILE="/tmp/kernel_config"
else
    echo "   ⚠️  Kernel config not found"
    CONFIG_FILE=""
fi

if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    if grep -q "CONFIG_PREEMPT_RT=y" "$CONFIG_FILE"; then
        echo "   ✓ PREEMPT_RT enabled in kernel config"
    elif grep -q "CONFIG_PREEMPT_RT_FULL=y" "$CONFIG_FILE"; then
        echo "   ✓ PREEMPT_RT_FULL enabled in kernel config"
    else
        echo "   ⚠️  PREEMPT_RT not found in kernel config"
    fi
fi
echo ""

# Check kernel name for RT
echo "2. Kernel Name:"
if echo "$KERNEL_VERSION" | grep -qi "rt\|preempt"; then
    echo "   ✓ RT kernel detected in version string"
else
    echo "   ⚠️  No RT indicator in kernel version"
fi
echo ""

# Check available RT kernels
echo "3. Available RT Kernels:"
RT_KERNELS=$(dpkg -l | grep -i "linux-image.*rt\|linux-image.*preempt" | awk '{print $2}' || true)
if [ -n "$RT_KERNELS" ]; then
    echo "$RT_KERNELS" | while read -r kernel; do
        echo "   - $kernel"
    done
else
    echo "   ⚠️  No RT kernels found in package list"
fi
echo ""

# Summary
echo "========================================"
echo "Note: PREEMPT_RT is recommended but not"
echo "strictly required for ACRN hypervisor."
echo "Service OS can use standard kernel."

