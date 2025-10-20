#!/bin/bash
#
# Script: 04_generate_grub_config.sh
# Purpose: Generate GRUB kernel parameters for IOMMU, CPU isolation, and RT tuning
# Usage: ./04_generate_grub_config.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT/configs"
OUTPUT_FILE="$CONFIG_DIR/grub_cmdline.txt"

mkdir -p "$CONFIG_DIR"

echo "========================================"
echo "Generate GRUB Configuration"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Detect CPU information
TOTAL_CPUS=$(nproc)
echo "Detected CPUs: $TOTAL_CPUS"

# CPU allocation strategy:
# - Reserve CPUs 0-3 for system/Dom0/housekeeping
# - Isolate CPUs 4-7 for RT guests
if [ "$TOTAL_CPUS" -ge 8 ]; then
    HOUSEKEEPING_CPUS="0,1,2,3"
    ISOLATED_CPUS="4-7"
elif [ "$TOTAL_CPUS" -ge 6 ]; then
    HOUSEKEEPING_CPUS="0,1"
    ISOLATED_CPUS="2-$((TOTAL_CPUS-1))"
elif [ "$TOTAL_CPUS" -ge 4 ]; then
    HOUSEKEEPING_CPUS="0,1"
    ISOLATED_CPUS="2-$((TOTAL_CPUS-1))"
else
    echo "⚠ Warning: Only $TOTAL_CPUS CPUs detected. Recommend 8+ for RT isolation."
    HOUSEKEEPING_CPUS="0"
    ISOLATED_CPUS="1-$((TOTAL_CPUS-1))"
fi

echo "Housekeeping CPUs: $HOUSEKEEPING_CPUS"
echo "Isolated CPUs: $ISOLATED_CPUS"
echo ""

# Detect if Intel or AMD
if grep -q "GenuineIntel" /proc/cpuinfo; then
    IOMMU_PARAM="intel_iommu=on"
    VENDOR="Intel"
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
    IOMMU_PARAM="amd_iommu=on"
    VENDOR="AMD"
else
    IOMMU_PARAM="intel_iommu=on"
    VENDOR="Unknown"
fi

echo "Detected CPU Vendor: $VENDOR"
echo "IOMMU Parameter: $IOMMU_PARAM"
echo ""

# Build kernel parameter string
GRUB_PARAMS="${IOMMU_PARAM} iommu=pt"
GRUB_PARAMS="${GRUB_PARAMS} isolcpus=${ISOLATED_CPUS}"
GRUB_PARAMS="${GRUB_PARAMS} nohz_full=${ISOLATED_CPUS}"
GRUB_PARAMS="${GRUB_PARAMS} rcu_nocbs=${ISOLATED_CPUS}"
GRUB_PARAMS="${GRUB_PARAMS} nosoftlockup"
GRUB_PARAMS="${GRUB_PARAMS} nohz=on"
GRUB_PARAMS="${GRUB_PARAMS} rcu_nocb_poll"
GRUB_PARAMS="${GRUB_PARAMS} idle=poll"
GRUB_PARAMS="${GRUB_PARAMS} processor.max_cstate=1"
GRUB_PARAMS="${GRUB_PARAMS} intel_idle.max_cstate=0"
GRUB_PARAMS="${GRUB_PARAMS} intel_pstate=disable"
GRUB_PARAMS="${GRUB_PARAMS} tsc=reliable"
GRUB_PARAMS="${GRUB_PARAMS} clocksource=tsc"

# Create configuration file
{
    echo "# GRUB Kernel Parameters for RT Hypervisor POC"
    echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# System: $(hostname)"
    echo "# Total CPUs: $TOTAL_CPUS"
    echo "# Housekeeping CPUs: $HOUSEKEEPING_CPUS"
    echo "# Isolated CPUs: $ISOLATED_CPUS"
    echo ""
    echo "# === PARAMETER EXPLANATION ==="
    echo "# ${IOMMU_PARAM}      - Enable IOMMU/VT-d for device passthrough"
    echo "# iommu=pt              - Use passthrough mode for better performance"
    echo "# isolcpus              - Isolate CPUs from general scheduler"
    echo "# nohz_full             - Disable scheduler tick on isolated CPUs"
    echo "# rcu_nocbs             - Offload RCU callbacks from isolated CPUs"
    echo "# nosoftlockup          - Disable soft lockup detector"
    echo "# nohz=on               - Enable NO_HZ mode"
    echo "# rcu_nocb_poll         - Poll for RCU callbacks"
    echo "# idle=poll             - Use polling idle loop (lowest latency, higher power)"
    echo "# processor.max_cstate  - Limit C-states for deterministic latency"
    echo "# intel_idle.max_cstate - Limit Intel idle driver C-states"
    echo "# intel_pstate=disable  - Disable P-state driver for fixed frequency"
    echo "# tsc=reliable          - Trust TSC as reliable clock source"
    echo "# clocksource=tsc       - Use TSC as primary clock source"
    echo ""
    echo "# === GRUB_CMDLINE_LINUX_DEFAULT ==="
    echo "$GRUB_PARAMS"
    echo ""
    echo "# === ALTERNATIVE (lower power, slightly higher latency) ==="
    echo "# Replace 'idle=poll' with 'mwait=0' if power consumption is a concern"
    echo ""
} > "$OUTPUT_FILE"

echo "✓ GRUB configuration generated successfully"
echo "✓ Output saved to: $OUTPUT_FILE"
echo ""
echo "Generated parameters:"
echo "$GRUB_PARAMS"
echo ""
echo "Next steps:"
echo "1. Review the configuration: cat $OUTPUT_FILE"
echo "2. Apply to system: sudo ./scripts/05_update_grub.sh"
echo ""

