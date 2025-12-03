#!/bin/bash
#
# Script: 02_check_cpu_info.sh
# Purpose: Display CPU information for ACRN planning
# Usage: ./02_check_cpu_info.sh

set -e

echo "========================================"
echo "CPU Information"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Total CPU cores
TOTAL_CPUS=$(nproc)
echo "Total CPU Cores: $TOTAL_CPUS"
echo ""

# CPU details
echo "CPU Details:"
lscpu | grep -E "Model name|CPU\(s\)|Thread|Core|Socket|NUMA"
echo ""

# CPU topology
echo "CPU Topology:"
if [ -d /sys/devices/system/cpu/cpu0/topology ]; then
    echo "CPU 0 topology:"
    cat /sys/devices/system/cpu/cpu0/topology/* 2>/dev/null | grep -v "^$" || true
fi
echo ""

# NUMA nodes
if [ -d /sys/devices/system/node ]; then
    NUMA_NODES=$(ls -d /sys/devices/system/node/node* 2>/dev/null | wc -l)
    echo "NUMA Nodes: $NUMA_NODES"
    if [ "$NUMA_NODES" -gt 1 ]; then
        echo "NUMA Node CPU mapping:"
        for node in /sys/devices/system/node/node*; do
            if [ -f "$node/cpulist" ]; then
                NODE_NUM=$(basename "$node" | sed 's/node//')
                CPUS=$(cat "$node/cpulist")
                echo "  Node $NODE_NUM: CPUs $CPUS"
            fi
        done
    fi
    echo ""
fi

# CPU flags
echo "CPU Flags (first CPU):"
grep "^flags" /proc/cpuinfo | head -1 | tr ' ' '\n' | grep -E "vmx|svm|ept|vpid" || echo "  (no relevant flags found)"
echo ""

# Recommended CPU allocation (example)
echo "========================================"
echo "Recommended CPU Allocation (Example):"
echo "========================================"
echo "Service OS (SOS): 0-$((TOTAL_CPUS/2 - 1))"
echo "RT VM: $((TOTAL_CPUS/2))-$((TOTAL_CPUS*3/4 - 1))"
echo "GPOS VM: $((TOTAL_CPUS*3/4))-$((TOTAL_CPUS - 1))"
echo ""
echo "Adjust based on your requirements!"

