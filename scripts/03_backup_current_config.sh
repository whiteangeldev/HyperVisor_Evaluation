#!/bin/bash
#
# Script: 03_backup_current_config.sh
# Purpose: Backup current system configuration before making changes
# Usage: ./03_backup_current_config.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/configs/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "========================================"
echo "Backup Current Configuration"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Backup kernel command line
if [ -f /proc/cmdline ]; then
    cp /proc/cmdline "$BACKUP_DIR/cmdline_${TIMESTAMP}.txt"
    echo "✓ Backed up: /proc/cmdline"
fi

# Backup GRUB configuration (if readable)
if [ -f /etc/default/grub ]; then
    if [ -r /etc/default/grub ]; then
        cp /etc/default/grub "$BACKUP_DIR/grub_${TIMESTAMP}.bak"
        echo "✓ Backed up: /etc/default/grub"
    else
        echo "⚠ Cannot read /etc/default/grub (needs sudo)"
        echo "  Run: sudo cp /etc/default/grub $BACKUP_DIR/grub_${TIMESTAMP}.bak"
    fi
fi

# Backup current CPU online status
if [ -d /sys/devices/system/cpu ]; then
    cat /sys/devices/system/cpu/online > "$BACKUP_DIR/cpu_online_${TIMESTAMP}.txt" 2>/dev/null || true
    if [ -f /sys/devices/system/cpu/isolated ]; then
        cat /sys/devices/system/cpu/isolated > "$BACKUP_DIR/cpu_isolated_${TIMESTAMP}.txt" 2>/dev/null || true
    fi
    echo "✓ Backed up: CPU online/isolated status"
fi

# Backup IRQ affinity (current state)
IRQ_BACKUP="$BACKUP_DIR/irq_affinity_${TIMESTAMP}.txt"
{
    echo "IRQ Affinity Backup - $(date)"
    echo "================================"
    for irq in /proc/irq/*/smp_affinity_list; do
        if [ -f "$irq" ]; then
            irq_num=$(echo "$irq" | sed 's/.*\/irq\/\([0-9]*\)\/.*/\1/')
            affinity=$(cat "$irq" 2>/dev/null || echo "N/A")
            echo "IRQ $irq_num: $affinity"
        fi
    done
} > "$IRQ_BACKUP" 2>/dev/null || true
echo "✓ Backed up: IRQ affinity settings"

# Backup network configuration
ip addr show > "$BACKUP_DIR/network_${TIMESTAMP}.txt" 2>/dev/null || true
ip link show >> "$BACKUP_DIR/network_${TIMESTAMP}.txt" 2>/dev/null || true
echo "✓ Backed up: Network configuration"

# Create a summary file
SUMMARY_FILE="$BACKUP_DIR/backup_summary_${TIMESTAMP}.txt"
{
    echo "Configuration Backup Summary"
    echo "============================"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo ""
    echo "Files backed up:"
    ls -lh "$BACKUP_DIR" | grep "$TIMESTAMP"
    echo ""
    echo "Current kernel cmdline:"
    cat /proc/cmdline
    echo ""
} > "$SUMMARY_FILE"

echo "✓ Created backup summary"
echo ""
echo "Backup completed successfully!"
echo "Backup location: $BACKUP_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""
ls -lh "$BACKUP_DIR" | grep "$TIMESTAMP"
echo ""

