#!/bin/bash
#
# Script: 12_verify_acrn.sh
# Purpose: Verify ACRN hypervisor is running
# Usage: ./12_verify_acrn.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/acrn_verification.log"

log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "========================================"
log "ACRN Verification"
log "========================================"
log "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
log ""

ERRORS=0
WARNINGS=0

# Check if running under ACRN
log "1. Checking if running under ACRN hypervisor..."
if [ -d /dev/acrn ]; then
    log "   ✓ /dev/acrn directory exists"
    ACRN_DEVICES=$(ls /dev/acrn/ 2>/dev/null | wc -l)
    log "   ✓ Found $ACRN_DEVICES ACRN device(s)"
else
    log "   ❌ /dev/acrn not found - not running under ACRN"
    ERRORS=$((ERRORS + 1))
fi
log ""

# Check ACRN tools
log "2. Checking ACRN tools..."
if command -v acrn-dm &> /dev/null; then
    ACRN_DM_VERSION=$(acrn-dm --version 2>/dev/null || echo "unknown")
    log "   ✓ acrn-dm found (version: $ACRN_DM_VERSION)"
else
    log "   ❌ acrn-dm not found"
    ERRORS=$((ERRORS + 1))
fi

if command -v acrnctl &> /dev/null; then
    log "   ✓ acrnctl found"
else
    log "   ⚠️  acrnctl not found"
    WARNINGS=$((WARNINGS + 1))
fi

if command -v acrnlog &> /dev/null; then
    log "   ✓ acrnlog found"
else
    log "   ⚠️  acrnlog not found"
    WARNINGS=$((WARNINGS + 1))
fi
log ""

# Check hypervisor log
log "3. Checking ACRN hypervisor log..."
if [ -f /var/log/acrn/acrn.log ] || [ -f /tmp/acrn.log ]; then
    log "   ✓ ACRN log file found"
    if command -v acrnlog &> /dev/null; then
        log "   Recent log entries:"
        acrnlog -t 2>/dev/null | tail -5 | sed 's/^/      /' || true
    fi
else
    log "   ⚠️  ACRN log file not found"
    WARNINGS=$((WARNINGS + 1))
fi
log ""

# Check CPU isolation
log "4. Checking CPU isolation..."
if [ -f /sys/devices/system/cpu/isolated ]; then
    ISOLATED=$(cat /sys/devices/system/cpu/isolated 2>/dev/null || echo "")
    if [ -n "$ISOLATED" ]; then
        log "   ✓ Isolated CPUs: $ISOLATED"
    else
        log "   ⚠️  No CPUs marked as isolated"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    log "   ⚠️  Cannot check CPU isolation"
    WARNINGS=$((WARNINGS + 1))
fi
log ""

# Check IOMMU
log "5. Checking IOMMU..."
if [ -d /sys/kernel/iommu_groups ]; then
    IOMMU_GROUPS=$(find /sys/kernel/iommu_groups -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    log "   ✓ IOMMU groups: $IOMMU_GROUPS"
else
    log "   ❌ IOMMU groups not found"
    ERRORS=$((ERRORS + 1))
fi
log ""

# Check VMs (if acrnctl available)
log "6. Checking ACRN VMs..."
if command -v acrnctl &> /dev/null; then
    if acrnctl list 2>/dev/null | grep -q .; then
        log "   VMs:"
        acrnctl list 2>/dev/null | sed 's/^/      /' || true
    else
        log "   ⚠️  No VMs running (this is normal if VMs not started yet)"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    log "   ⚠️  Cannot check VMs (acrnctl not available)"
    WARNINGS=$((WARNINGS + 1))
fi
log ""

# Check kernel version
log "7. System Information:"
log "   Kernel: $(uname -r)"
log "   OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'unknown')"
log "   CPUs: $(nproc)"
log ""

# Summary
log "========================================"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    log "✓ ACRN Verification: PASSED"
    log "   ACRN hypervisor is running correctly"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    log "⚠️  ACRN Verification: PASSED with warnings ($WARNINGS)"
    log "   ACRN is running but some optional features missing"
    exit 0
else
    log "❌ ACRN Verification: FAILED ($ERRORS errors, $WARNINGS warnings)"
    log ""
    log "Troubleshooting:"
    log "1. Check if you booted with ACRN GRUB entry"
    log "2. Verify ACRN binary: ls -lh /boot/acrn.bin"
    log "3. Check dmesg: dmesg | grep -i acrn"
    log "4. Review installation logs in: $LOG_DIR"
    exit 1
fi

