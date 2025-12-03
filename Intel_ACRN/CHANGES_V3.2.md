# ACRN v3.2 Script Updates

## Summary
Updated installation scripts for ACRN v3.2 compatibility with Intel 13th Gen CPU (Raptor Lake) using Alder Lake (12th Gen) board configuration.

**Date:** December 3, 2025  
**Target Version:** ACRN v3.2  
**Board:** adl-asrock (Alder Lake - compatible with 13th Gen Raptor Lake)  
**Scenario:** shared

---

## Key Changes

### 1. **New Script: `04_download_acrn_3.2.sh`**
- Downloads and checks out ACRN v3.2 specifically
- Validates that correct version tag is available
- Shows available v3.x tags if version not found

**Usage:**
```bash
./04_download_acrn_3.2.sh
```

---

### 2. **Updated: `06_build_acrn.sh`**

#### Python Dependency Management
- **Uses Virtual Environment** instead of system pip
- Avoids dependency conflicts between xmlschema and elementpath
- Installs exact versions:
  - `elementpath==2.5.3` (ACRN v3.2 requirement)
  - `xmlschema==2.0.0` (Python 3.12 compatible)
- Uses `--no-deps` flag for xmlschema to prevent auto-upgrade of elementpath

#### Default Board
- Changed default board from `generic_board` to `adl-asrock`
- Alder Lake (12th Gen) configuration is compatible with 13th Gen Raptor Lake

#### Virtual Environment Location
- Created at: `~/acrn-hypervisor/acrn-build-env/`
- Automatically activated during build
- Deactivated after build completes

**Usage:**
```bash
./06_build_acrn.sh adl-asrock shared    # Explicit (recommended)
./06_build_acrn.sh                      # Uses adl-asrock by default
```

---

### 3. **Updated: `07_install_acrn_binary.sh`**

#### Binary Format Priority
- **Prioritizes ELF format** (acrn.32.out or acrn.64.out)
- Falls back to acrn.bin only if ELF not available
- Verifies binary type using `file` command

#### Safety Checks
- Warns if binary is raw data format (not ELF)
- Requires confirmation to proceed with non-ELF binary
- GRUB multiboot2 command requires ELF format!

#### Installation
- Installs as `/boot/acrn.32.out` (or appropriate name)
- Creates symlink `/boot/acrn.bin` for compatibility

**Usage:**
```bash
sudo ./07_install_acrn_binary.sh
```

---

### 4. **Updated: `11_create_grub_entry.sh`**

#### Fixed Boot Issues
- **REMOVED duplicate `boot` commands** (previously had 5 boot commands!)
- Now has single `boot` command at end of menuentry
- Fixed typo "hypervisorr" → "Hypervisor"

#### Binary Detection
- Checks for ELF binaries first (acrn.32.out, acrn.64.out)
- Falls back to acrn.bin
- Warns if acrn.bin is not ELF format

#### GRUB Entry
- Uses correct binary path in multiboot2 command
- Maintains all critical parameters (intel_iommu=on, console, etc.)
- Cleaner, more reliable boot sequence

**Usage:**
```bash
sudo ./11_create_grub_entry.sh
```

---

## Critical Fixes

### 1. **Python Dependency Conflict**
**Problem:** xmlschema 2.x auto-installs elementpath 4.x, but ACRN v3.2 needs elementpath 2.x

**Solution:** Virtual environment + `--no-deps` flag prevents version conflicts

### 2. **Wrong Binary Format**
**Problem:** acrn.bin (raw binary) doesn't work with GRUB multiboot2

**Solution:** Prioritize acrn.32.out (ELF format) which is required by multiboot2

### 3. **Duplicate Boot Commands**
**Problem:** GRUB entry had 5 `boot` commands, causing boot confusion

**Solution:** Single `boot` command at end of menuentry

### 4. **Hardware Compatibility**
**Problem:** generic_board not compatible with 13th Gen Intel CPU

**Solution:** Use adl-asrock board (12th Gen Alder Lake, compatible with 13th Gen)

---

## Installation Workflow for v3.2

```bash
# 1. Download ACRN v3.2
./04_download_acrn_3.2.sh

# 2. Install build dependencies (if not already done)
sudo ./05_install_build_deps.sh

# 3. Build ACRN with adl-asrock board
./06_build_acrn.sh adl-asrock shared
# Virtual environment will be created automatically
# Python dependencies will be installed correctly

# 4. Install binary
sudo ./07_install_acrn_binary.sh
# Will install acrn.32.out (ELF format)

# 5. Configure GRUB parameters
sudo ./08_configure_grub_iommu.sh
sudo ./09_configure_cpu_isolation.sh
sudo ./10_configure_irq_affinity.sh

# 6. Create GRUB entry
sudo ./11_create_grub_entry.sh
# Will use correct binary and single boot command

# 7. Reboot and test
sudo reboot
# Select "ACRN Hypervisor" from GRUB menu
```

---

## Verification Commands

```bash
# Check ACRN binary format
file /boot/acrn.32.out
# Should show: ELF 32-bit LSB executable

# Check Python versions (in build venv)
source ~/acrn-hypervisor/acrn-build-env/bin/activate
python -c "import elementpath, xmlschema; print(f'elementpath: {elementpath.__version__}, xmlschema: {xmlschema.__version__}')"
deactivate
# Should show: elementpath: 2.5.3, xmlschema: 2.0.0

# Check GRUB entry
sudo grep -A 20 "menuentry 'ACRN Hypervisor'" /boot/grub/grub.cfg
# Should show single boot command, correct binary path

# Check boot parameters
sudo grep "module2.*vmlinuz" /boot/grub/grub.cfg | grep "intel_iommu=on"
# Should show intel_iommu=on parameter
```

---

## Troubleshooting

### Build fails with elementpath error
**Symptom:** `AttributeError: type object 'XPath2Parser' has no attribute 'SYMBOLS'`

**Cause:** Wrong elementpath version (4.x instead of 2.x)

**Fix:** Delete virtual environment and rebuild
```bash
rm -rf ~/acrn-hypervisor/acrn-build-env
./06_build_acrn.sh adl-asrock shared
```

### Boot hangs at "Loading ACRN Hypervisor"
**Cause:** Wrong binary format (raw binary instead of ELF)

**Fix:** Check binary format and reinstall
```bash
file /boot/acrn.32.out
# Must show ELF executable
sudo ./07_install_acrn_binary.sh
sudo ./11_create_grub_entry.sh
```

### GRUB entry not appearing
**Cause:** GRUB timeout is 0

**Fix:** Set GRUB timeout
```bash
sudo nano /etc/default/grub
# Set: GRUB_TIMEOUT=5
sudo update-grub
```

---

## Files Modified

1. ✅ `04_download_acrn_3.2.sh` (NEW)
2. ✅ `06_build_acrn.sh` (UPDATED - virtual environment, default board)
3. ✅ `07_install_acrn_binary.sh` (UPDATED - ELF priority, verification)
4. ✅ `11_create_grub_entry.sh` (UPDATED - single boot command, binary detection)

---

## Next Steps

After applying these changes:

1. **Clean old build** (optional but recommended):
   ```bash
   cd ~/acrn-hypervisor
   make clean
   rm -rf build/
   rm -rf acrn-build-env/
   ```

2. **Follow installation workflow** (see above)

3. **Test boot** and verify ACRN starts correctly

4. **Check logs** if issues occur:
   ```bash
   dmesg | grep -i acrn
   journalctl -b | grep -i acrn
   ```

---

## References

- ACRN v3.2 Release: https://github.com/projectacrn/acrn-hypervisor/releases/tag/v3.2
- Board configs: `~/acrn-hypervisor/misc/config_tools/data/`
- Python dependencies: `~/acrn-hypervisor/misc/config_tools/requirements.txt`
- GRUB multiboot2: https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html

