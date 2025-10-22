#!/bin/bash
#
# Script: 13_install_irq_service.sh
# Purpose: Install and enable IRQ affinity systemd service
# Usage: sudo ./13_install_irq_service.sh
# ⚠️  REQUIRES ROOT PRIVILEGES
#

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ ERROR: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT/configs"
SERVICE_FILE="$CONFIG_DIR/irq-affinity.service"
IRQ_SCRIPT="$SCRIPT_DIR/set_irq_affinity.sh"
SYSTEMD_DIR="/etc/systemd/system"
INSTALL_DIR="/usr/local/bin"

echo "========================================"
echo "Install IRQ Affinity Service"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ ERROR: Service file not found: $SERVICE_FILE"
    echo "Run ./scripts/12_create_irq_service.sh first"
    exit 1
fi

if [ ! -f "$IRQ_SCRIPT" ]; then
    echo "❌ ERROR: IRQ affinity script not found: $IRQ_SCRIPT"
    echo "Run ./scripts/11_generate_irq_script.sh first"
    exit 1
fi

echo "Step 1: Copy IRQ affinity script to $INSTALL_DIR..."
cp "$IRQ_SCRIPT" "$INSTALL_DIR/set_irq_affinity.sh"
chmod +x "$INSTALL_DIR/set_irq_affinity.sh"
echo "✓ Script installed and made executable"
echo ""

echo "Step 2: Install service file to systemd..."
cp "$SERVICE_FILE" "$SYSTEMD_DIR/irq-affinity.service"
echo "✓ Service file installed"
echo ""

echo "Step 3: Reload systemd daemon..."
systemctl daemon-reload
echo "✓ Systemd daemon reloaded"
echo ""

echo "Step 3a: Disable irqbalance (if present)..."
if systemctl list-unit-files | grep -q "^irqbalance.service"; then
    echo "  Found irqbalance service, disabling it..."
    systemctl stop irqbalance 2>/dev/null || true
    systemctl disable irqbalance 2>/dev/null || true
    systemctl mask irqbalance 2>/dev/null || true
    echo "  ✓ irqbalance disabled and masked"
else
    echo "  ℹ irqbalance not installed (this is fine)"
fi
echo ""

echo "Step 4: Enable service..."
systemctl enable irq-affinity.service
echo "✓ Service enabled"
echo ""

echo "Step 5: Start service..."
systemctl start irq-affinity.service
echo "✓ Service started"
echo ""

echo "Step 6: Check service status..."
systemctl status irq-affinity.service --no-pager || true
echo ""

echo "========================================"
echo "Installation Complete"
echo "========================================"
echo "✓ IRQ affinity script installed at: $INSTALL_DIR/set_irq_affinity.sh"
echo "✓ IRQ affinity service installed and enabled"
echo "✓ Service is now running"
echo "✓ irqbalance disabled (if it was present)"
echo ""
echo "Service will run automatically on boot"
echo "To check status: systemctl status irq-affinity.service"
echo "To restart: sudo systemctl restart irq-affinity.service"
echo ""

