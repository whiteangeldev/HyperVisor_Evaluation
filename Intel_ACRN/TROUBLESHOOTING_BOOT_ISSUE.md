# ACRN Boot Issue Troubleshooting Guide

## Problem Description

When selecting "ACRN Hypervisor" from the GRUB menu, the system shows:
```
Loading ACRN Hypervisor
WARNING: no console will be available
Loading service VM kernel...
Loading service vm initrd...
```
Then the system hangs or fails to boot.

## Root Cause Analysis

Based on the error messages and GRUB configuration, the most likely issues are:

1. **Missing `intel_iommu=on` in Service VM kernel parameters** (CRITICAL)
   - The GRUB entry may not be passing `intel_iommu=on` to the Service VM kernel
   - This is required for ACRN to function properly

2. **ACRN binary compatibility issues**
   - The binary may not be multiboot2 compatible
   - The binary may have been built for wrong board/scenario

3. **Missing or incorrect console configuration**
   - Service VM needs proper console parameters to boot

## Check Results Analysis

### Script 01-03 Results: ✅ CORRECT

The check results from scripts 01-03 are **correct and appropriate**:

- ✅ **01_check_bios_iommu.sh**: All checks passed
  - Intel CPU detected
  - VT-x supported
  - IOMMU detected
  - IOMMU groups found (16 groups)
  - `intel_iommu=on` found in GRUB (for normal boot)

- ✅ **02_check_cpu_info.sh**: Results are correct
  - 14 CPU cores detected (0-13)
  - CPU flags include: vmx, ept, vpid, ept_ad (all required)
  - Recommended CPU allocation provided

- ⚠️ **03_check_kernel_rt.sh**: Warnings are acceptable
  - PREEMPT_RT not found (this is OK - not strictly required)
  - Standard kernel can be used for Service OS

**Note**: These scripts check the *host system* configuration. They don't verify the ACRN GRUB entry configuration, which is where the problem likely lies.

## What You Need on Client Side

### Step 1: Run Diagnostic Script

```bash
sudo ./14_diagnose_boot_issue.sh
```

This will identify:
- Missing `intel_iommu=on` in GRUB entry
- Missing or incorrect kernel/initrd paths
- ACRN binary issues
- Other configuration problems

### Step 2: Fix GRUB Entry

```bash
sudo ./15_fix_grub_entry.sh
```

This script will:
- Ensure `intel_iommu=on` is included in Service VM kernel parameters
- Add proper console parameters
- Preserve other GRUB settings
- Regenerate GRUB configuration

### Step 3: Verify the Fix

```bash
# Check the GRUB entry
cat /etc/grub.d/40_custom_acrn

# Verify it's in compiled config
grep -A 25 'ACRN Hypervisor' /boot/grub/grub.cfg | grep intel_iommu
```

You should see `intel_iommu=on` in the Service VM kernel parameters.

### Step 4: Reboot and Test

```bash
sudo reboot
```

Select "ACRN Hypervisor" from GRUB menu.

### Step 5: Verify ACRN is Running

After successful boot:
```bash
./12_verify_acrn.sh
```

## Manual Fix (If Scripts Don't Work)

If you need to manually fix the GRUB entry:

1. Edit the GRUB entry:
   ```bash
   sudo nano /etc/grub.d/40_custom_acrn
   ```

2. Find the line with `module2` that loads the kernel. It should look like:
   ```
   module2 /boot/vmlinuz-6.14.0-35-generic root=UUID=... ro console=tty0 console=ttyS0,115200n8
   ```

3. **CRITICAL**: Ensure `intel_iommu=on` is in that line:
   ```
   module2 /boot/vmlinuz-6.14.0-35-generic root=UUID=... ro intel_iommu=on console=tty0 console=ttyS0,115200n8
   ```

4. Update GRUB:
   ```bash
   sudo update-grub
   ```

5. Verify:
   ```bash
   grep -A 25 'ACRN Hypervisor' /boot/grub/grub.cfg
   ```

## Additional Troubleshooting

### If Boot Still Fails After Fix

1. **Check ACRN Binary**:
   ```bash
   file /boot/acrn.bin
   ls -lh /boot/acrn.bin
   ```
   - Should be a valid ELF executable
   - Size should be reasonable (typically > 1MB)

2. **Check Boot Logs** (after failed boot attempt):
   ```bash
   dmesg | grep -i acrn
   journalctl -b -1 | grep -i acrn
   ```

3. **Verify ACRN Build**:
   - Check if ACRN was built for the correct board/scenario
   - Review build logs: `logs/acrn_build.log`

4. **Check Hardware Compatibility**:
   - Ensure CPU supports all required features (already verified by script 01)
   - Check if there are any hardware-specific issues

### Common Issues

1. **"WARNING: no console will be available"**
   - This is a GRUB warning, not necessarily fatal
   - The Service VM console parameters should handle output

2. **Hangs after loading initrd**
   - Usually means Service VM kernel is trying to boot but failing
   - Most common cause: Missing `intel_iommu=on`
   - Second most common: ACRN binary incompatibility

3. **ACRN binary not found**
   - Run: `sudo ./07_install_acrn_binary.sh`

## Expected Behavior After Fix

After applying the fix and rebooting:

1. GRUB menu appears
2. Select "ACRN Hypervisor"
3. See messages:
   - "Loading ACRN Hypervisor..."
   - "Loading Service VM kernel..."
   - "Loading Service VM initrd..."
4. System boots normally (may take longer than normal boot)
5. After boot, `/dev/acrn` directory exists
6. `./12_verify_acrn.sh` shows ACRN is running

## Summary

**The check results from scripts 01-03 are correct.** The issue is that the ACRN GRUB entry is missing `intel_iommu=on` in the Service VM kernel parameters. This is a common oversight because:

- The host system has `intel_iommu=on` in `/etc/default/grub` (for normal boot)
- But the custom ACRN GRUB entry needs to explicitly include it for the Service VM

Run the diagnostic and fix scripts to resolve this issue.

