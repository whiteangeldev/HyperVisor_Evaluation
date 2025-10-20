#!/bin/bash
#
# Script: 25_master_setup_xen.sh
# Purpose: Master orchestration script for Xen hypervisor setup
# Usage: ./25_master_setup_xen.sh
#
# This script guides through the complete Xen setup process
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================="
echo "RT HYPERVISOR POC - XEN SETUP (MASTER SCRIPT)"
echo "=============================================="
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "This script will guide you through Milestone 1"
echo "setup for Xen RT hypervisor."
echo ""
echo "⚠️  WARNING: Some steps require root and system reboots"
echo ""
read -p "Press Enter to continue or Ctrl+C to abort..."
echo ""

# Phase 1: System Inventory
echo "=============================================="
echo "PHASE 1: System Inventory and Baseline"
echo "=============================================="
echo ""

echo "Step 1.1: Collecting system information..."
"$SCRIPT_DIR/01_collect_system_info.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 1.2: Checking virtualization support..."
"$SCRIPT_DIR/02_check_virt_support.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 1.3: Backing up current configuration..."
"$SCRIPT_DIR/03_backup_current_config.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

# Phase 2: GRUB Configuration
echo "=============================================="
echo "PHASE 2: GRUB Configuration"
echo "=============================================="
echo ""

echo "Step 2.1: Generating GRUB configuration..."
"$SCRIPT_DIR/04_generate_grub_config.sh"
echo ""
echo "Generated GRUB parameters. Review before applying:"
cat "$SCRIPT_DIR/../configs/grub_cmdline.txt" | tail -5
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 2.2: Apply GRUB configuration..."
echo "⚠️  This requires root privileges"
read -p "Run: sudo $SCRIPT_DIR/05_update_grub.sh [Press Enter to acknowledge]"
echo ""

echo "Step 2.3: System reboot required"
echo "⚠️  After reboot, run this script again to continue"
echo ""
read -p "Reboot now? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Please run this script again after reboot!"
    sleep 2
    sudo reboot
else
    echo "Reboot manually when ready, then re-run this script"
    exit 0
fi

# Phase 3: Verify GRUB and Install Xen
# (This section runs after reboot)
echo "=============================================="
echo "PHASE 3: Xen Installation"
echo "=============================================="
echo ""

echo "Step 3.1: Verifying IOMMU status after reboot..."
"$SCRIPT_DIR/06_pre_xen_check.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 3.2: Installing Xen hypervisor..."
echo "⚠️  This requires root privileges"
read -p "Run: sudo $SCRIPT_DIR/07_install_xen.sh [Press Enter to acknowledge]"
echo ""

echo "Step 3.3: Configuring Xen RT scheduler..."
"$SCRIPT_DIR/08_configure_xen_rt.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 3.4: Applying Xen configuration..."
echo "⚠️  This requires root privileges"
read -p "Run: sudo $SCRIPT_DIR/09_apply_xen_config.sh [Press Enter to acknowledge]"
echo ""

echo "Step 3.5: Reboot into Xen required"
echo "⚠️  After reboot, verify Xen with: xl info"
echo ""
read -p "Reboot now? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "After reboot, run Phase 4 scripts for IRQ configuration"
    sleep 2
    sudo reboot
else
    echo "Reboot manually when ready"
    exit 0
fi

# Phase 4: IRQ Configuration
# (Run after Xen reboot)
echo "=============================================="
echo "PHASE 4: IRQ Affinity Configuration"
echo "=============================================="
echo ""

echo "Step 4.1: Mapping current IRQ affinity..."
"$SCRIPT_DIR/10_map_irq_affinity.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 4.2: Generating IRQ affinity script..."
"$SCRIPT_DIR/11_generate_irq_script.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 4.3: Creating IRQ affinity service..."
"$SCRIPT_DIR/12_create_irq_service.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 4.4: Disabling irqbalance and setting IRQ affinity..."
echo "⚠️  This requires root privileges"
echo "Run the following commands:"
echo "  sudo systemctl stop irqbalance"
echo "  sudo systemctl disable irqbalance"
echo "  sudo $SCRIPT_DIR/set_irq_affinity.sh"
echo "  sudo $SCRIPT_DIR/13_install_irq_service.sh"
echo ""
read -p "Press Enter when complete..."
echo ""

# Phase 5: Validation
echo "=============================================="
echo "PHASE 5: Validation and Verification"
echo "=============================================="
echo ""

echo "Step 5.1: Verifying CPU isolation..."
"$SCRIPT_DIR/14_verify_isolation.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 5.2: Verifying IOMMU groups..."
"$SCRIPT_DIR/15_verify_iommu.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 5.3: Verifying Xen status..."
"$SCRIPT_DIR/16_verify_xen.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 5.4: Generating final report..."
"$SCRIPT_DIR/17_generate_report.sh"
echo ""

echo "=============================================="
echo "MILESTONE 1 SETUP COMPLETE (XEN)"
echo "=============================================="
echo ""
echo "✓ System inventory collected"
echo "✓ GRUB configured with isolation parameters"
echo "✓ Xen hypervisor installed and running"
echo "✓ IRQ affinity configured"
echo "✓ Validation complete"
echo ""
echo "Report generated: docs/milestone1_report.md"
echo ""
echo "Next: Proceed to Milestone 2 (VM configuration)"
echo ""

