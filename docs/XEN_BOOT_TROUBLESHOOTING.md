# Xen Boot Troubleshooting Guide

## Problem: "Can't find hypervisor information in sysfs!"

This error means you're not booting into Xen - you're booting the regular Linux kernel instead.

---

## Quick Fix

### Step 1: Fix GRUB Configuration

```bash
# As ubuntu user
cd ~/rt-hypervisor-poc/scripts
sudo ./09b_fix_xen_grub.sh
```

This script will:
- Verify Xen is installed
- Ensure grub-xen-host is installed
- Create symbolic links
- **Force GRUB to regenerate with Xen entries**

### Step 2: Make GRUB Menu Visible (Optional)

If you want to see the GRUB menu at boot:

```bash
sudo nano /etc/default/grub
```

Change these lines:
```
GRUB_TIMEOUT_STYLE=menu    # Change from 'hidden' if present
GRUB_TIMEOUT=5             # Set to 5 seconds (or more)
```

Then update GRUB:
```bash
sudo update-grub
```

### Step 3: Reboot and Select Xen

```bash
sudo reboot
```

**At boot:**
1. **Hold SHIFT key** to show GRUB menu (if not visible)
2. Look for entry like: **"Xen hypervisor ..."** or **"Ubuntu ... with Xen ..."**
3. Select it and press Enter

### Step 4: Verify Xen is Running

After boot:
```bash
# Should show Xen information (not error)
sudo xl info

# Check scheduler (should show rtds or credit2)
sudo xl info | grep xen_scheduler

# Check if you're in Xen
ls /sys/hypervisor/
# Should show: compilation  properties  type  uuid  version
```

---

## Understanding the Issue

### Why This Happens

1. **Xen is installed** but GRUB didn't create boot entries
2. **grub-xen-host** needs to be properly configured
3. GRUB needs to be regenerated to detect Xen

### GRUB Entry Structure

A proper Xen GRUB entry looks like:
```
menuentry 'Ubuntu ... with Xen hypervisor' {
    multiboot2  /boot/xen-4.17-amd64.gz ...
    module2     /boot/vmlinuz-... root=...
    module2     /boot/initrd.img-...
}
```

---

## Manual Verification

### Check Xen Files in /boot

```bash
ls -la /boot/ | grep xen
```

Should show:
- `xen-4.17-amd64.gz` - The hypervisor
- `xen-4.17-amd64.config` - Config
- `xen.gz` - Symbolic link (may be missing)

### Check GRUB Configuration

```bash
grep "menuentry.*Xen" /boot/grub/grub.cfg
```

Should show Xen boot entries. If empty, GRUB needs regeneration.

### Check Xen GRUB Config

```bash
cat /etc/default/grub.d/xen.cfg
```

Should contain:
```
GRUB_CMDLINE_XEN_DEFAULT="sched=rtds dom0_max_vcpus=4 ..."
```

---

## Alternative: Set Xen as Default Boot

If Xen entries exist but you want it to boot automatically:

### Option 1: Use GRUB Entry Number

```bash
# Find Xen entry number
grep -n "menuentry.*Xen" /boot/grub/grub.cfg | head -1
# Note the number (e.g., line 123)

# Edit GRUB default
sudo nano /etc/default/grub

# Set GRUB_DEFAULT to entry number (0-indexed)
# If Xen is first entry, use:
GRUB_DEFAULT=0

# Update GRUB
sudo update-grub
```

### Option 2: Use Saved Entry

```bash
# Edit GRUB
sudo nano /etc/default/grub

# Add these lines:
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true

# Update GRUB
sudo update-grub

# Boot into Xen once, then it becomes default
```

---

## Troubleshooting: Still Not Working?

### 1. Check if GRUB is in UEFI or BIOS Mode

```bash
[ -d /sys/firmware/efi ] && echo "UEFI" || echo "BIOS"
```

**If UEFI**: Xen needs special configuration
- May need `xen-4.17-amd64.efi` instead of `.gz`
- GRUB configuration differs

### 2. Check Boot Logs

```bash
# See what was attempted
sudo journalctl -b | grep -i grub
sudo journalctl -b | grep -i xen
```

### 3. Reinstall Xen

If all else fails:
```bash
sudo apt remove --purge xen-*
sudo apt autoremove
sudo apt install xen-hypervisor-amd64 xen-tools xen-utils-common grub-xen-host
sudo update-grub
sudo reboot
```

---

## How to Know You're Running Xen

### ✅ Running Xen (Success)

```bash
$ sudo xl info
host                   : AMS764973
release                : 6.8.0-85-generic
...
xen_scheduler          : rtds    # ← RT scheduler active!
xen_version            : 4.17.4-pre
```

### ✅ Also Check

```bash
$ uname -r
6.8.0-85-generic  # ← Normal kernel version

$ ls /sys/hypervisor/
compilation  properties  type  uuid  version  # ← Xen sysfs present
```

### ❌ NOT Running Xen (Problem)

```bash
$ sudo xl info
ERROR:  Can't find hypervisor information in sysfs!  # ← Not in Xen

$ ls /sys/hypervisor/
ls: cannot access '/sys/hypervisor/': No such file or directory
```

---

## GRUB Menu Not Showing?

### Force GRUB Menu to Appear

1. **During boot**: Hold **SHIFT** key (BIOS) or **ESC** key (UEFI)

2. **Make it permanent**:
```bash
sudo nano /etc/default/grub

# Change/add:
GRUB_TIMEOUT=10
GRUB_TIMEOUT_STYLE=menu
# Comment out:
# GRUB_HIDDEN_TIMEOUT=0

sudo update-grub
sudo reboot
```

---

## Summary Checklist

- [ ] Xen installed: `ls /boot/xen-*.gz`
- [ ] grub-xen-host installed: `dpkg -l | grep grub-xen-host`
- [ ] GRUB updated: `sudo update-grub`
- [ ] Xen entries in GRUB: `grep "menuentry.*Xen" /boot/grub/grub.cfg`
- [ ] Rebooted and selected Xen from GRUB menu
- [ ] Verified: `sudo xl info` works without error
- [ ] RT scheduler active: `sudo xl info | grep xen_scheduler` shows `rtds`

---

## Quick Command Reference

```bash
# Fix GRUB for Xen
sudo ./scripts/09b_fix_xen_grub.sh

# Show GRUB entries
grep "menuentry" /boot/grub/grub.cfg

# Update GRUB
sudo update-grub

# Check current boot
sudo xl info                    # Should NOT error
ls /sys/hypervisor/            # Should exist
uname -r                       # Shows kernel version

# Check scheduler
sudo xl info | grep xen_scheduler
```

---

*Last Updated: 2025-10-17*

