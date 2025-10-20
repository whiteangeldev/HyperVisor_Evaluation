#!/bin/bash
#
# Script: 26_master_setup_acrn.sh
# Purpose: Master orchestration script for Intel ACRN setup
# Usage: ./26_master_setup_acrn.sh
#
# This script guides through the complete ACRN setup process
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================="
echo "RT HYPERVISOR POC - ACRN SETUP (MASTER SCRIPT)"
echo "=============================================="
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "This script will guide you through Milestone 1"
echo "setup for Intel ACRN hypervisor."
echo ""
echo "⚠️  WARNING: Some steps require root and system reboots"
echo "⚠️  ACRN build process may take 15-30 minutes"
echo ""
read -p "Press Enter to continue or Ctrl+C to abort..."
echo ""

# Phase 1: Prerequisites
echo "=============================================="
echo "PHASE 1: Prerequisites and System Check"
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

echo "Step 1.3: ACRN pre-installation check..."
"$SCRIPT_DIR/18_pre_acrn_check.sh"
echo ""
echo "Review the pre-check results above."
read -p "Continue with ACRN installation? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup aborted. Address issues and re-run."
    exit 1
fi
echo ""

# Phase 2: GRUB Configuration (if not already done)
echo "=============================================="
echo "PHASE 2: GRUB Configuration"
echo "=============================================="
echo ""

echo "Checking if GRUB is already configured..."
if grep -q "intel_iommu=on" /proc/cmdline && grep -q "isolcpus" /proc/cmdline; then
    echo "✓ GRUB appears to be configured already"
else
    echo "⚠ GRUB needs configuration"
    echo ""
    
    echo "Step 2.1: Backing up current configuration..."
    "$SCRIPT_DIR/03_backup_current_config.sh"
    echo ""
    
    echo "Step 2.2: Generating GRUB configuration..."
    "$SCRIPT_DIR/04_generate_grub_config.sh"
    echo ""
    
    echo "Step 2.3: Apply GRUB configuration..."
    echo "⚠️  This requires root privileges"
    read -p "Run: sudo $SCRIPT_DIR/05_update_grub.sh [Press Enter to acknowledge]"
    echo ""
    
    echo "Step 2.4: System reboot required"
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
fi

read -p "Press Enter to continue..."
echo ""

# Phase 3: Install Dependencies
echo "=============================================="
echo "PHASE 3: Install ACRN Dependencies"
echo "=============================================="
echo ""

echo "Step 3.1: Installing build dependencies..."
echo "⚠️  This requires root privileges and ~500MB download"
read -p "Continue? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Run: sudo $SCRIPT_DIR/19_install_acrn_deps.sh"
    read -p "Press Enter when installation is complete..."
else
    echo "Skipping dependency installation"
fi
echo ""

# Phase 4: Download and Build ACRN
echo "=============================================="
echo "PHASE 4: Download and Build ACRN"
echo "=============================================="
echo ""

echo "Step 4.1: Downloading ACRN source code..."
"$SCRIPT_DIR/20_download_acrn.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 4.2: Building ACRN hypervisor..."
echo "⚠️  This will take 15-30 minutes"
read -p "Continue with build? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/21_build_acrn.sh"
else
    echo "Build skipped. Run ./scripts/21_build_acrn.sh manually"
    exit 0
fi
echo ""
read -p "Press Enter to continue..."
echo ""

# Phase 5: Install ACRN
echo "=============================================="
echo "PHASE 5: Install ACRN to System"
echo "=============================================="
echo ""

echo "Step 5.1: Installing ACRN hypervisor..."
echo "⚠️  This requires root privileges"
read -p "Run: sudo $SCRIPT_DIR/22_install_acrn.sh [Press Enter to acknowledge]"
echo ""

echo "Step 5.2: Configuring ACRN for RT..."
"$SCRIPT_DIR/23_configure_acrn.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 5.3: Review GRUB configuration..."
echo "⚠️  IMPORTANT: Verify ACRN GRUB entry before rebooting"
echo ""
echo "Run: sudo cat /etc/grub.d/40_custom_acrn"
echo "Edit if needed: sudo nano /etc/grub.d/40_custom_acrn"
echo ""
read -p "Press Enter when GRUB entry is verified..."
echo ""

echo "Step 5.4: Reboot into ACRN"
echo "⚠️  Select 'ACRN Hypervisor' from GRUB menu"
echo ""
read -p "Reboot now? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "After reboot:"
    echo "1. Select 'ACRN Hypervisor' from GRUB"
    echo "2. Run: ./scripts/24_verify_acrn.sh"
    echo "3. Run: ./scripts/27_final_report.sh"
    sleep 3
    sudo reboot
else
    echo "Reboot manually and select ACRN from GRUB"
    exit 0
fi

# Phase 6: Verification (after ACRN reboot)
echo "=============================================="
echo "PHASE 6: Verification"
echo "=============================================="
echo ""

echo "Step 6.1: Verifying ACRN status..."
"$SCRIPT_DIR/24_verify_acrn.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 6.2: Verifying CPU isolation..."
"$SCRIPT_DIR/14_verify_isolation.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 6.3: Verifying IOMMU groups..."
"$SCRIPT_DIR/15_verify_iommu.sh"
echo ""
read -p "Press Enter to continue..."
echo ""

echo "Step 6.4: Generating final report..."
"$SCRIPT_DIR/27_final_report.sh"
echo ""

echo "=============================================="
echo "MILESTONE 1 SETUP COMPLETE (ACRN)"
echo "=============================================="
echo ""
echo "✓ System prerequisites verified"
echo "✓ ACRN hypervisor built and installed"
echo "✓ GRUB configured"
echo "✓ System booted into ACRN"
echo "✓ Validation complete"
echo ""
echo "Report generated: docs/milestone1_acrn_report.md"
echo ""
echo "Next: Proceed to Milestone 2 (VM configuration)"
echo ""

