# Quick Fix Steps for ACRN Boot Issue

## Current Status
✅ Diagnostic confirmed: `intel_iommu=on` is missing from Service VM kernel parameters

## Next Steps

### Step 1: Run the Fix Script
```bash
sudo ./15_fix_grub_entry.sh
```

This will:
- Extract useful parameters from your existing entry (like `earlyprintk`, `no_timer_check`)
- Preserve ACRN hypervisor parameters (`hvlog=2 console=ttyS0 uart=port@0x3f8`)
- Add the missing `intel_iommu=on` parameter
- Regenerate the GRUB entry

### Step 2: Verify the Fix
```bash
# Check the GRUB entry file
cat /etc/grub.d/40_custom_acrn

# Verify intel_iommu=on is in the compiled config
sudo grep -A 25 'ACRN Hypervisor' /boot/grub/grub.cfg | grep intel_iommu
```

You should see `intel_iommu=on` in the Service VM kernel parameters.

### Step 3: Reboot and Test
```bash
sudo reboot
```

When GRUB menu appears:
- Select "ACRN Hypervisor" (or "ACRN Hypervisor (Safe Boot)" if that's what appears)
- The system should now boot successfully

### Step 4: Verify ACRN is Running
After successful boot:
```bash
./12_verify_acrn.sh
```

You should see:
- ✓ /dev/acrn directory exists
- ✓ ACRN tools available
- ✓ ACRN Verification: PASSED

## What the Fix Does

The fix script will:
1. **Preserve your existing parameters**:
   - `earlyprintk=ttyS0`
   - `no_timer_check`
   - `quiet splash`
   - ACRN hypervisor params: `hvlog=2 console=ttyS0 uart=port@0x3f8`

2. **Add missing critical parameter**:
   - `intel_iommu=on` (required for Service VM)

3. **Ensure proper console**:
   - `console=tty0 console=ttyS0,115200n8`

## Expected Result

After the fix, your GRUB entry will have:
```
module2 /boot/vmlinuz-6.14.0-35-generic root=UUID=... ro console=tty0 console=ttyS0,115200n8 intel_iommu=on earlyprintk=ttyS0 no_timer_check quiet splash
```

The `intel_iommu=on` parameter is what was missing and causing the boot failure.

