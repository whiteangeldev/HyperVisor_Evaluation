# ACRN Boot Hang Analysis and Fix

## Problem Description

When selecting "ACRN Hypervisor" from GRUB menu, the system shows:
```
Loading ACRN Hypervisor...
WARNING: no console will be available to OS
Loading Service VM kernel...
Loading Service VM initrd....
```

Then the system **hangs** at this point and does not proceed to boot the Service VM.

## Root Cause Analysis

Based on the symptoms and ACRN documentation, there are several potential causes:

### 1. **Missing `intel_iommu=on` in Service VM Kernel Parameters** (MOST LIKELY)
   - **Critical**: The Service VM kernel MUST have `intel_iommu=on` to function properly
   - Even if the script adds it, GRUB might not be passing it correctly
   - The parameter must be in the `module2` line for the Service VM kernel

### 2. **ACRN Hypervisor Console Configuration**
   - The "WARNING: no console will be available to OS" suggests ACRN hypervisor console is not configured
   - ACRN hypervisor needs console parameters passed via `multiboot2` command
   - Common parameters: `uart=disabled` or `uart=mmio@0x91526000` (board-specific)

### 3. **ACRN Binary Compatibility Issues**
   - Binary might be built for wrong board/scenario
   - Binary might not be multiboot2 compatible
   - Binary might be corrupted or incomplete

### 4. **Initrd Issues**
   - Initrd might be missing required drivers for ACRN
   - Initrd might be incompatible with ACRN boot process
   - Initrd path might be incorrect

### 5. **GRUB Parameter Parsing Issues**
   - GRUB might not be correctly parsing the parameters
   - Variable expansion might be failing
   - Parameters might be getting truncated

## Diagnostic Steps

### Step 1: Check Current GRUB Configuration

```bash
# Check the GRUB entry file
cat /etc/grub.d/40_custom_acrn

# Check the compiled GRUB config
grep -A 30 'ACRN Hypervisor' /boot/grub/grub.cfg

# Verify intel_iommu=on is present
grep -A 30 'ACRN Hypervisor' /boot/grub/grub.cfg | grep intel_iommu
```

### Step 2: Check ACRN Binary

```bash
# Check binary exists and size
ls -lh /boot/acrn.bin
file /boot/acrn.bin

# Check binary type
strings /boot/acrn.bin | grep -i "acrn\|version\|board" | head -10
```

### Step 3: Check Kernel and Initrd

```bash
# Verify kernel and initrd paths in GRUB entry match actual files
KERNEL=$(grep "module2.*vmlinuz" /etc/grub.d/40_custom_acrn | awk '{print $2}')
INITRD=$(grep "module2.*initrd" /etc/grub.d/40_custom_acrn | awk '{print $2}')

echo "Kernel: $KERNEL"
[ -f "$KERNEL" ] && echo "✓ Kernel exists" || echo "❌ Kernel missing"

echo "Initrd: $INITRD"
[ -f "$INITRD" ] && echo "✓ Initrd exists" || echo "❌ Initrd missing"
```

## Solutions

### Solution 1: Fix GRUB Entry (Most Common Fix)

The issue is likely that `intel_iommu=on` is not being properly passed to the Service VM kernel, or the ACRN hypervisor needs console parameters.

**Run the fix script:**
```bash
sudo ./21_fix_boot_hang.sh
```

This script will:
1. Verify all files exist
2. Ensure `intel_iommu=on` is in Service VM parameters
3. Add ACRN hypervisor console parameters (if needed)
4. Fix any parameter parsing issues
5. Regenerate GRUB configuration

### Solution 2: Manual GRUB Entry Fix

If the script doesn't work, manually edit the GRUB entry:

```bash
sudo nano /etc/grub.d/40_custom_acrn
```

Ensure the `module2` line for the Service VM kernel includes `intel_iommu=on`:
```
module2 /boot/vmlinuz-6.x.x-generic root=UUID=xxx ro intel_iommu=on console=tty0 console=ttyS0,115200n8
```

Then update GRUB:
```bash
sudo update-grub
```

### Solution 3: Add ACRN Hypervisor Console Parameters

If the hypervisor console warning persists, add console parameters to the `multiboot2` line:

```bash
sudo nano /etc/grub.d/40_custom_acrn
```

Change:
```
multiboot2 /boot/acrn.bin
```

To (for most Intel boards):
```
multiboot2 /boot/acrn.bin uart=disabled
```

Or (if you need serial console):
```
multiboot2 /boot/acrn.bin uart=mmio@0x91526000
```

### Solution 4: Rebuild ACRN with Correct Configuration

If the binary is incompatible, you may need to rebuild ACRN:

1. Check what board/scenario was used:
   ```bash
   # Check build logs or config
   find ../acrn-hypervisor -name "*.config" -o -name "*.log" | xargs grep -i "board\|scenario" | head -5
   ```

2. Rebuild with correct board/scenario:
   ```bash
   sudo ./06_build_acrn.sh
   sudo ./07_install_acrn_binary.sh
   ```

## Expected Behavior After Fix

After applying the fix:

1. GRUB menu appears
2. Select "ACRN Hypervisor"
3. See messages:
   - "Loading ACRN Hypervisor..." (no warning if console configured)
   - "Loading Service VM kernel..."
   - "Loading Service VM initrd..."
4. **System proceeds to boot** (may take 30-60 seconds)
5. Service VM boots normally
6. After boot, `/dev/acrn` directory exists
7. `./12_verify_acrn.sh` confirms ACRN is running

## Additional Troubleshooting

### If Still Hanging After Fix

1. **Check boot logs** (after failed boot, boot normally):
   ```bash
   dmesg | grep -i acrn
   journalctl -b -1 | grep -i acrn
   ```

2. **Try minimal GRUB entry** (test if parameters are the issue):
   ```bash
   # Create minimal entry with only essential parameters
   # This helps isolate the problem
   ```

3. **Check hardware compatibility**:
   ```bash
   # Verify CPU features
   ./01_check_bios_iommu.sh
   ./02_check_cpu_info.sh
   ```

4. **Check if ACRN binary is correct**:
   ```bash
   # Verify binary was built correctly
   file /boot/acrn.bin
   strings /boot/acrn.bin | head -20
   ```

## Summary

The most common cause of this hang is **missing `intel_iommu=on` in the Service VM kernel parameters**. The fix script (`21_fix_boot_hang.sh`) addresses this and other common issues.

If the fix script doesn't resolve the issue, the problem is likely:
- ACRN binary incompatibility (wrong board/scenario)
- Hardware incompatibility
- Missing drivers in initrd

In these cases, you may need to rebuild ACRN or check hardware compatibility.





