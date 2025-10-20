#!/bin/bash
#
# Script: 09f_deep_xen_diagnosis.sh
# Purpose: Deep diagnosis of why Xen won't boot
# Usage: sudo ./09f_deep_xen_diagnosis.sh
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Run as: sudo $0"
    exit 1
fi

echo "=========================================="
echo "DEEP XEN BOOT DIAGNOSIS"
echo "=========================================="
echo ""

echo "1. BOOT MODE (UEFI vs BIOS)"
echo "=========================================="
if [ -d /sys/firmware/efi ]; then
    echo "❌ BOOT MODE: UEFI"
    echo ""
    echo "   THIS IS THE PROBLEM!"
    echo "   Xen on UEFI requires xen.efi, not xen.gz"
    echo ""
    BOOT_MODE="UEFI"
else
    echo "✓ BOOT MODE: Legacy BIOS"
    echo "   Xen .gz format should work"
    BOOT_MODE="BIOS"
fi
echo ""

echo "2. SECURE BOOT STATUS"
echo "=========================================="
if [ -f /sys/firmware/efi/efivars/SecureBoot-* ]; then
    SECUREBOOT=$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | awk '{print $NF}')
    if [ "$SECUREBOOT" = "1" ]; then
        echo "❌ SECURE BOOT: ENABLED"
        echo "   Xen may be blocked by Secure Boot!"
        echo ""
    else
        echo "✓ SECURE BOOT: DISABLED"
    fi
else
    echo "✓ SECURE BOOT: Not applicable (BIOS mode or disabled)"
fi
echo ""

echo "3. XEN BINARIES IN /boot"
echo "=========================================="
ls -lh /boot/xen* 2>/dev/null || echo "No Xen files"
echo ""

if [ "$BOOT_MODE" = "UEFI" ]; then
    if [ -f /boot/xen-4.17-amd64.efi ]; then
        echo "✓ Found xen-4.17-amd64.efi (needed for UEFI)"
    else
        echo "❌ Missing xen-4.17-amd64.efi (REQUIRED for UEFI boot)"
        echo "   Only have .gz which won't work in UEFI mode"
    fi
fi
echo ""

echo "4. ACTUAL GRUB XEN ENTRY CONTENT"
echo "=========================================="
echo "First Xen entry details:"
sed -n '/^menuentry.*Xen.*{/,/^}/p' /boot/grub/grub.cfg | head -30
echo ""

echo "5. GRUB BOOT ORDER"
echo "=========================================="
echo "Current GRUB_DEFAULT:"
grep "^GRUB_DEFAULT" /etc/default/grub
echo ""
echo "Saved entry:"
grub-editenv list 2>/dev/null || echo "No saved entry"
echo ""
echo "Actual menu order:"
grep "^menuentry" /boot/grub/grub.cfg | nl -v 0 | head -5
echo ""

echo "6. BOOTLOADER CHECK"
echo "=========================================="
if [ -d /sys/firmware/efi ]; then
    echo "EFI boot entries:"
    efibootmgr 2>/dev/null || echo "efibootmgr not installed"
else
    echo "MBR boot (GRUB in /boot/grub/)"
fi
echo ""

echo "7. LAST BOOT LOG"
echo "=========================================="
echo "Checking what actually booted:"
journalctl -b | grep -i "kernel.*command line" | head -2
echo ""

echo "=========================================="
echo "DIAGNOSIS COMPLETE"
echo "=========================================="
echo ""

if [ "$BOOT_MODE" = "UEFI" ]; then
    echo "🔴 ROOT CAUSE FOUND: UEFI BOOT MODE"
    echo ""
    echo "Your system uses UEFI, but Xen is configured for BIOS."
    echo ""
    echo "SOLUTIONS:"
    echo ""
    echo "Option 1: Use Xen EFI binary (Recommended)"
    echo "  1. Check if xen.efi exists: ls -la /boot/*.efi"
    echo "  2. If not, may need different Xen package or build"
    echo "  3. GRUB needs multiboot2 (not multiboot) for UEFI"
    echo ""
    echo "Option 2: Switch to BIOS/Legacy boot mode"
    echo "  - Change in BIOS/UEFI firmware settings"
    echo "  - May require OS reinstall"
    echo ""
    echo "Option 3: Try KVM instead of Xen"
    echo "  - KVM works better with UEFI"
    echo "  - Or use Intel ACRN (supports UEFI)"
    echo ""
else
    echo "Boot mode is BIOS - Xen should work."
    echo ""
    echo "Check:"
    echo "1. Look at section 4 - is the Xen entry properly formatted?"
    echo "2. Is there a 'multiboot' line loading /boot/xen*.gz?"
    echo "3. Try: sudo grub-reboot 1 && sudo reboot"
    echo "   (This forces one-time boot to entry 1)"
fi
echo ""

