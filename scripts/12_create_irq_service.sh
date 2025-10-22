#!/bin/bash
#
# Script: 12_create_irq_service.sh
# Purpose: Generate systemd service for persistent IRQ affinity
# Usage: ./12_create_irq_service.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT/configs"
SERVICE_FILE="$CONFIG_DIR/irq-affinity.service"
IRQ_SCRIPT="$SCRIPT_DIR/set_irq_affinity.sh"

mkdir -p "$CONFIG_DIR"

echo "========================================"
echo "Create IRQ Affinity Systemd Service"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Generate systemd service file
# NOTE: The script will be installed to /usr/local/bin/ by 13_install_irq_service.sh
cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=IRQ Affinity Configuration for RT Hypervisor
After=network.target
Before=xen.service libvirtd.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/set_irq_affinity.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "✓ Systemd service file created"
echo "✓ Output saved to: $SERVICE_FILE"
echo ""
echo "Service details:"
cat "$SERVICE_FILE"
echo ""
echo "NOTE: The service references /usr/local/bin/set_irq_affinity.sh"
echo "      This will be installed by the next step (13_install_irq_service.sh)"
echo ""
echo "Next steps:"
echo "1. Review the service: cat $SERVICE_FILE"
echo "2. Install service: sudo ./scripts/13_install_irq_service.sh"
echo ""

