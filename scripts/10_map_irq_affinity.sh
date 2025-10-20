#!/bin/bash
#
# Script: 10_map_irq_affinity.sh
# Purpose: Document current IRQ affinity mappings
# Usage: ./10_map_irq_affinity.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
OUTPUT_FILE="$LOG_DIR/irq_affinity_before.log"

mkdir -p "$LOG_DIR"

echo "========================================"
echo "IRQ Affinity Mapping"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

{
    echo "========================================"
    echo "IRQ AFFINITY BASELINE"
    echo "========================================"
    echo "Mapping Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo ""
    
    echo "========================================"
    echo "SYSTEM CPU INFORMATION"
    echo "========================================"
    echo "Online CPUs: $(cat /sys/devices/system/cpu/online)"
    if [ -f /sys/devices/system/cpu/isolated ]; then
        ISOLATED=$(cat /sys/devices/system/cpu/isolated)
        if [ -n "$ISOLATED" ]; then
            echo "Isolated CPUs: $ISOLATED"
        else
            echo "Isolated CPUs: None"
        fi
    fi
    echo ""
    
    echo "========================================"
    echo "IRQ BALANCE SERVICE STATUS"
    echo "========================================"
    systemctl status irqbalance --no-pager || echo "irqbalance not active"
    echo ""
    
    echo "========================================"
    echo "IRQ AFFINITY MAPPINGS"
    echo "========================================"
    printf "%-6s %-40s %-15s %-10s\n" "IRQ" "DEVICE/NAME" "CPU_LIST" "MASK"
    printf "%-6s %-40s %-15s %-10s\n" "---" "--------" "--------" "----"
    
    for irq_dir in /proc/irq/*; do
        if [ -d "$irq_dir" ] && [ "$(basename "$irq_dir")" != "default_smp_affinity" ]; then
            irq_num=$(basename "$irq_dir")
            
            # Skip non-numeric directories
            if ! [[ "$irq_num" =~ ^[0-9]+$ ]]; then
                continue
            fi
            
            # Get IRQ name/device
            if [ -f "$irq_dir/actions" ]; then
                irq_name=$(cat "$irq_dir/actions" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
            else
                irq_name="unknown"
            fi
            
            # Get CPU affinity list
            if [ -f "$irq_dir/smp_affinity_list" ]; then
                cpu_list=$(cat "$irq_dir/smp_affinity_list" 2>/dev/null || echo "N/A")
            else
                cpu_list="N/A"
            fi
            
            # Get CPU affinity mask
            if [ -f "$irq_dir/smp_affinity" ]; then
                cpu_mask=$(cat "$irq_dir/smp_affinity" 2>/dev/null || echo "N/A")
            else
                cpu_mask="N/A"
            fi
            
            # Truncate name if too long
            if [ ${#irq_name} -gt 38 ]; then
                irq_name="${irq_name:0:35}..."
            fi
            
            printf "%-6s %-40s %-15s %-10s\n" "$irq_num" "$irq_name" "$cpu_list" "$cpu_mask"
        fi
    done
    
    echo ""
    
    echo "========================================"
    echo "IRQ DISTRIBUTION SUMMARY"
    echo "========================================"
    
    # Count IRQs per CPU
    for cpu in $(cat /sys/devices/system/cpu/online | tr ',' ' ' | sed 's/-/ /g'); do
        if [[ "$cpu" =~ ^[0-9]+$ ]]; then
            count=0
            for irq_dir in /proc/irq/*/smp_affinity_list; do
                if [ -f "$irq_dir" ]; then
                    affinity=$(cat "$irq_dir" 2>/dev/null || echo "")
                    if echo "$affinity" | grep -qE "(^|,)${cpu}(,|$)"; then
                        ((count++))
                    fi
                fi
            done
            echo "CPU $cpu: $count IRQs"
        fi
    done
    
    echo ""
    
    echo "========================================"
    echo "DEFAULT SMP AFFINITY"
    echo "========================================"
    if [ -f /proc/irq/default_smp_affinity ]; then
        echo "Default mask: $(cat /proc/irq/default_smp_affinity)"
    fi
    
    echo ""
    
} | tee "$OUTPUT_FILE"

echo ""
echo "✓ IRQ affinity mapping completed"
echo "✓ Output saved to: $OUTPUT_FILE"
echo ""
echo "Summary: $(wc -l < "$OUTPUT_FILE") lines documented"
echo ""

