#!/bin/bash
#
# Script: 09_configure_cpu_isolation.sh
# Purpose: Configure CPU isolation parameters for ACRN
# Usage: sudo ./09_configure_cpu_isolation.sh [sos_cpus] [rt_cpus] [gpos_cpus]
# Example: sudo ./09_configure_cpu_isolation.sh "0,1,2,3" "4,5" "6,7"

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT/configs"

TOTAL_CPUS=$(nproc)

# Default CPU allocation (if not provided)
SOS_CPUS="${1:-0-$((TOTAL_CPUS/2 - 1))}"
RT_CPUS="${2:-$((TOTAL_CPUS/2))-$((TOTAL_CPUS*3/4 - 1))}"
GPOS_CPUS="${3:-$((TOTAL_CPUS*3/4))-$((TOTAL_CPUS - 1))}"

echo "========================================"
echo "Configure CPU Isolation"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Total CPUs: $TOTAL_CPUS"
echo ""
echo "CPU Allocation:"
echo "  Service OS (SOS): $SOS_CPUS"
echo "  RT VM: $RT_CPUS"
echo "  GPOS VM: $GPOS_CPUS"
echo ""

# Combine isolated CPUs (RT + GPOS)
ISOLATED_CPUS="$RT_CPUS,$GPOS_CPUS"
# Remove duplicates and sort
ISOLATED_CPUS=$(echo "$ISOLATED_CPUS" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')

echo "Isolated CPUs (for RT+GPOS): $ISOLATED_CPUS"
echo ""

GRUB_FILE="/etc/default/grub"
BACKUP_FILE="${GRUB_FILE}.backup.$(date +%Y%m%d-%H%M%S)"

# Backup GRUB config
if [ -f "$GRUB_FILE" ]; then
    cp "$GRUB_FILE" "$BACKUP_FILE"
    echo "✓ Backed up GRUB config"
else
    echo "❌ GRUB config not found"
    exit 1
fi

# Get current GRUB_CMDLINE_LINUX
CURRENT_CMD=$(grep "^GRUB_CMDLINE_LINUX=" "$GRUB_FILE" | sed 's/^GRUB_CMDLINE_LINUX=//' | tr -d '"' || echo "")

# Remove existing isolation parameters
CURRENT_CMD=$(echo "$CURRENT_CMD" | sed 's/isolcpus=[^ ]*//g' | sed 's/nohz_full=[^ ]*//g' | sed 's/rcu_nocbs=[^ ]*//g' | sed 's/  */ /g' | sed 's/^ //' | sed 's/ $//')

# Add isolation parameters
ISOLATION_PARAMS="isolcpus=$ISOLATED_CPUS nohz_full=$ISOLATED_CPUS rcu_nocbs=$ISOLATED_CPUS"

if [ -z "$CURRENT_CMD" ]; then
    NEW_CMD="$ISOLATION_PARAMS"
else
    NEW_CMD="$CURRENT_CMD $ISOLATION_PARAMS"
fi

# Update GRUB file
sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"$NEW_CMD\"|" "$GRUB_FILE"

echo "✓ Added CPU isolation parameters to GRUB"
echo ""
echo "New GRUB_CMDLINE_LINUX:"
grep "^GRUB_CMDLINE_LINUX=" "$GRUB_FILE"
echo ""

# Save configuration
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_DIR/cpu_isolation.conf" << EOF
# CPU Isolation Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Total CPUs: $TOTAL_CPUS

SOS_CPUS="$SOS_CPUS"
RT_CPUS="$RT_CPUS"
GPOS_CPUS="$GPOS_CPUS"
ISOLATED_CPUS="$ISOLATED_CPUS"

# GRUB Parameters:
# isolcpus=$ISOLATED_CPUS
# nohz_full=$ISOLATED_CPUS
# rcu_nocbs=$ISOLATED_CPUS
EOF

echo "✓ Configuration saved to: $CONFIG_DIR/cpu_isolation.conf"
echo ""

# Update GRUB
echo "Updating GRUB..."
update-grub > /dev/null 2>&1
echo "✓ GRUB updated"
echo ""

echo "========================================"
echo "✓ CPU Isolation Configured"
echo "========================================"
echo ""
echo "⚠️  REBOOT REQUIRED for changes to take effect"
echo "After reboot, isolated CPUs will be: $ISOLATED_CPUS"

