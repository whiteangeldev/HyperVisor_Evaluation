#!/bin/bash
#
# Script: 01_collect_system_info.sh
# Purpose: Collect comprehensive system information for baseline documentation
# Usage: ./01_collect_system_info.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
OUTPUT_FILE="$LOG_DIR/system_info.log"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "System Information Collection"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

{
    echo "========================================"
    echo "SYSTEM INFORMATION BASELINE"
    echo "========================================"
    echo "Collection Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo ""
    
    echo "========================================"
    echo "OS INFORMATION"
    echo "========================================"
    cat /etc/os-release
    echo ""
    uname -a
    echo ""
    
    echo "========================================"
    echo "CPU INFORMATION"
    echo "========================================"
    lscpu
    echo ""
    
    echo "========================================"
    echo "CPU FLAGS (First Processor)"
    echo "========================================"
    grep -m1 "^flags" /proc/cpuinfo | sed 's/flags\s*:\s*//' | tr ' ' '\n' | sort
    echo ""
    
    echo "========================================"
    echo "VMX FLAGS (Virtualization Features)"
    echo "========================================"
    grep -m1 "^vmx flags" /proc/cpuinfo || echo "No VMX flags found"
    echo ""
    
    echo "========================================"
    echo "MEMORY INFORMATION"
    echo "========================================"
    free -h
    echo ""
    cat /proc/meminfo | head -20
    echo ""
    
    echo "========================================"
    echo "PCI DEVICES"
    echo "========================================"
    lspci -nn
    echo ""
    
    echo "========================================"
    echo "NETWORK INTERFACES"
    echo "========================================"
    ip link show
    echo ""
    ip addr show
    echo ""
    
    echo "========================================"
    echo "BLOCK DEVICES"
    echo "========================================"
    lsblk
    echo ""
    
    echo "========================================"
    echo "KERNEL VERSION"
    echo "========================================"
    uname -r
    echo ""
    
    echo "========================================"
    echo "CURRENT KERNEL CMDLINE"
    echo "========================================"
    cat /proc/cmdline
    echo ""
    
    echo "========================================"
    echo "GRUB CONFIGURATION"
    echo "========================================"
    if [ -f /etc/default/grub ]; then
        cat /etc/default/grub
    else
        echo "GRUB config not found"
    fi
    echo ""
    
    echo "========================================"
    echo "INSTALLED KERNEL PACKAGES"
    echo "========================================"
    dpkg -l | grep -E "linux-image|linux-headers" || echo "No kernel packages found"
    echo ""
    
    echo "========================================"
    echo "SYSTEMD SERVICES STATUS"
    echo "========================================"
    systemctl list-units --type=service --state=running | head -30
    echo ""
    
} > "$OUTPUT_FILE" 2>&1

echo "✓ System information collected successfully"
echo "✓ Output saved to: $OUTPUT_FILE"
echo ""
echo "Summary:"
grep "Model name:" "$OUTPUT_FILE" || echo "CPU info collected"
grep "PRETTY_NAME" "$OUTPUT_FILE" || echo "OS info collected"
echo ""

