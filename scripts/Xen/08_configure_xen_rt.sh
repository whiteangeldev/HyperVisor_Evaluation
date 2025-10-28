#!/bin/bash
#
# Script: 08_configure_xen_rt.sh
# Purpose: Generate Xen configuration for RT scheduler
# Usage: ./08_configure_xen_rt.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT/configs"
XEN_CONFIG="$CONFIG_DIR/xen_rt.cfg"

mkdir -p "$CONFIG_DIR"

echo "========================================"
echo "Xen RT Scheduler Configuration"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Detect CPU information
TOTAL_CPUS=$(nproc)
echo "Total CPUs: $TOTAL_CPUS"

# CPU allocation for Dom0
# Match the kernel isolation: CPUs 0-3 for housekeeping, 4-7 for RT
if [ "$TOTAL_CPUS" -ge 8 ]; then
    DOM0_CPUS="4"
    DOM0_PIN="0-3"
    GUEST_CPUS="4-7"
elif [ "$TOTAL_CPUS" -ge 4 ]; then
    DOM0_CPUS="2"
    DOM0_PIN="0,1"
    GUEST_CPUS="2-$((TOTAL_CPUS-1))"
else
    DOM0_CPUS="1"
    DOM0_PIN="0"
    GUEST_CPUS="1"
fi

echo "Dom0 CPUs: $DOM0_CPUS (pinned to $DOM0_PIN)"
echo "Guest CPUs: $GUEST_CPUS"
echo ""

# Calculate memory allocation
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_MB=$((TOTAL_MEM_KB / 1024))
DOM0_MEM_MB=$((TOTAL_MEM_MB / 4))  # 25% for Dom0

echo "Total Memory: ${TOTAL_MEM_MB}MB"
echo "Dom0 Memory: ${DOM0_MEM_MB}MB"
echo ""

# Create Xen configuration file
cat > "$XEN_CONFIG" << EOF
# Xen RT Scheduler Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# System: $(hostname)

# ============================================
# HYPERVISOR CONFIGURATION
# ============================================

# Use Real-Time Deferrable Server (RTDS) scheduler
# This provides deterministic scheduling for RT guests
sched=rtds

# ============================================
# DOM0 CONFIGURATION
# ============================================

# Limit Dom0 to specific CPUs (housekeeping cores)
dom0_max_vcpus=${DOM0_CPUS}
dom0_vcpus_pin=${DOM0_PIN}

# Set Dom0 memory
dom0_mem=${DOM0_MEM_MB}M,max:${DOM0_MEM_MB}M

# ============================================
# CPU CONFIGURATION
# ============================================

# Reserve CPUs for RT guests (exclude from Dom0)
# These CPUs will be dedicated to guest VMs
# cpupool-numa-split=yes

# ============================================
# CONSOLE CONFIGURATION
# ============================================

# Console settings for debugging
console=vga,com1
com1=115200,8n1

# ============================================
# LOGGING
# ============================================

# Enable hypervisor logging
loglvl=all
guest_loglvl=all

# ============================================
# NOTES
# ============================================
# 
# RT Scheduler (RTDS):
# - Provides hard real-time guarantees
# - Budget-based scheduling
# - Configure guest VCPUs with period and budget
#
# Dom0 Isolation:
# - Dom0 is pinned to CPUs ${DOM0_PIN}
# - RT guests should be pinned to CPUs ${GUEST_CPUS}
# - This prevents Dom0 from interfering with RT workloads
#
# After reboot, verify with:
#   xl info
#   xl sched-rtds -s
#
EOF

echo "✓ Xen RT configuration generated"
echo "✓ Output saved to: $XEN_CONFIG"
echo ""
echo "Configuration summary:"
cat "$XEN_CONFIG"
echo ""
echo "Next steps:"
echo "1. Review configuration: cat $XEN_CONFIG"
echo "2. Apply to system: sudo ./09_apply_xen_config.sh"
echo ""

