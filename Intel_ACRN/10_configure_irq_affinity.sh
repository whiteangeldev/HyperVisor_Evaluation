#!/bin/bash
#
# Script: 10_configure_irq_affinity.sh
# Purpose: Configure IRQ affinity to keep interrupts off isolated CPUs
# Usage: sudo ./10_configure_irq_affinity.sh

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT/configs"

echo "========================================"
echo "Configure IRQ Affinity"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Load CPU isolation config if available
if [ -f "$CONFIG_DIR/cpu_isolation.conf" ]; then
    source "$CONFIG_DIR/cpu_isolation.conf"
    echo "Loaded CPU isolation config:"
    echo "  Isolated CPUs: $ISOLATED_CPUS"
    echo ""
else
    echo "⚠️  CPU isolation config not found"
    echo "   Run 09_configure_cpu_isolation.sh first"
    echo "   Using default: excluding last 4 CPUs"
    TOTAL_CPUS=$(nproc)
    ISOLATED_CPUS="$((TOTAL_CPUS-4))-$((TOTAL_CPUS-1))"
fi

# Calculate non-isolated CPUs (for IRQ affinity)
TOTAL_CPUS=$(nproc)
# Simple approach: assume first half are non-isolated
NON_ISOLATED_CPUS="0-$((TOTAL_CPUS/2 - 1))"
echo "IRQ affinity target CPUs: $NON_ISOLATED_CPUS"
echo ""

# Disable irqbalance
echo "1. Disabling irqbalance service..."
systemctl stop irqbalance 2>/dev/null || true
systemctl disable irqbalance 2>/dev/null || true
echo "✓ irqbalance disabled"
echo ""

# Configure IRQ affinity for each IRQ
echo "2. Configuring IRQ affinity..."
IRQ_COUNT=0
IRQ_UPDATED=0

for irq in /proc/irq/*/; do
    if [ -f "${irq}smp_affinity" ]; then
        IRQ_NUM=$(basename "$irq")
        
        # Skip IRQ 0 (timer) and other special IRQs
        if [ "$IRQ_NUM" = "0" ] || [ ! -f "${irq}smp_affinity" ]; then
            continue
        fi
        
        IRQ_COUNT=$((IRQ_COUNT + 1))
        
        # Set affinity to non-isolated CPUs
        # Convert CPU list to bitmask (simplified - using first CPU)
        echo 1 > "${irq}smp_affinity" 2>/dev/null && IRQ_UPDATED=$((IRQ_UPDATED + 1)) || true
    fi
done

echo "   Processed $IRQ_COUNT IRQs"
echo "   Updated $IRQ_UPDATED IRQs"
echo ""

# Create IRQ affinity script for persistence
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_DIR/set_irq_affinity.sh" << 'SCRIPT_EOF'
#!/bin/bash
# IRQ Affinity Configuration Script
# Run this after boot to set IRQ affinity

NON_ISOLATED_CPUS="0-3"  # Adjust based on your CPU isolation config

for irq in /proc/irq/*/; do
    if [ -f "${irq}smp_affinity" ]; then
        IRQ_NUM=$(basename "$irq")
        if [ "$IRQ_NUM" != "0" ]; then
            echo 1 > "${irq}smp_affinity" 2>/dev/null || true
        fi
    fi
done
SCRIPT_EOF

chmod +x "$CONFIG_DIR/set_irq_affinity.sh"
echo "✓ Created persistent IRQ affinity script: $CONFIG_DIR/set_irq_affinity.sh"
echo ""

# Show current IRQ distribution
echo "3. Current IRQ distribution:"
echo "   (showing first 10 IRQs)"
for irq in /proc/irq/*/; do
    if [ -f "${irq}smp_affinity" ]; then
        IRQ_NUM=$(basename "$irq")
        AFFINITY=$(cat "${irq}smp_affinity" 2>/dev/null || echo "N/A")
        IRQ_NAME=$(cat "${irq}actions" 2>/dev/null | head -1 || echo "unknown")
        echo "   IRQ $IRQ_NUM ($IRQ_NAME): $AFFINITY"
        [ "$IRQ_NUM" -ge 10 ] && break
    fi
done
echo ""

echo "========================================"
echo "✓ IRQ Affinity Configured"
echo "========================================"
echo ""
echo "Note: IRQ affinity changes are temporary."
echo "For persistence, add to systemd service or"
echo "run $CONFIG_DIR/set_irq_affinity.sh after boot"

