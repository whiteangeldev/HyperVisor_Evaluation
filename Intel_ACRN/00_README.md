# Intel ACRN Hypervisor Installation Scripts

## 📋 Execution Order

### Main Installation Workflow (Execute Sequentially)

#### Phase 1: Prerequisites Check

```bash
sudo ./01_check_bios_iommu.sh      # Check BIOS/IOMMU support
sudo ./02_check_cpu_info.sh        # Check CPU information
sudo ./03_check_kernel_rt.sh        # Check kernel RT support (optional)
```

#### Phase 2: Download and Build

```bash
sudo ./04_download_acrn_3.3.sh     # Download ACRN source code
sudo ./05_install_build_deps.sh     # Install build dependencies
sudo ./06_build_acrn.sh             # Build ACRN hypervisor
```

#### Phase 3: Installation

```bash
sudo ./07_install_acrn_binary.sh   # Install ACRN binary to /boot
```

#### Phase 4: Configuration

```bash
sudo ./08_configure_grub_iommu.sh  # Configure IOMMU in GRUB
sudo ./09_configure_cpu_isolation.sh # Configure CPU isolation
sudo ./10_configure_irq_affinity.sh # Configure IRQ affinity
sudo ./11_create_grub_entry.sh      # Create ACRN GRUB boot entry
```

#### Phase 5: Verification

```bash
sudo ./13_test_acrn_boot.sh        # Test boot configuration (before reboot)
sudo reboot                         # Reboot and select "ACRN Hypervisor"
./12_verify_acrn.sh                 # Verify ACRN is running (after boot)
```

---

## 🔧 Troubleshooting Scripts (Use as Needed)

These scripts are for troubleshooting and fixing issues:

```bash
# 14: Diagnose boot problems
sudo ./14_diagnose_boot_issue.sh

# 15: Fix GRUB entry (adds missing intel_iommu=on)
sudo ./15_fix_grub_entry.sh

# 16: Fix Python dependency issues (if build fails)
sudo ./16_fix_elementpath_compatibility.sh

# 17: Clean GRUB entry (removes duplicates)
sudo ./17_clean_grub_entry.sh

# 18: Verify GRUB entry before booting
sudo ./18_verify_grub_and_boot.sh

# 19: Fix duplicate GRUB entries
sudo ./19_fix_duplicate_grub_entries.sh

# 20: Quick fix for duplicate entries
sudo ./20_quick_fix_duplicates.sh
```

---

## 🚀 Quick Start

### First Time Installation

```bash
# Run all main workflow scripts in order
for i in {01..11}; do sudo ./${i}_*.sh; done
sudo ./13_test_acrn_boot.sh
sudo reboot
# After boot:
./12_verify_acrn.sh
```

### If Build Fails (Python Dependency Issue)

```bash
sudo ./16_fix_elementpath_compatibility.sh
sudo pip3 install --break-system-packages --upgrade 'elementpath>=4.0.0' 'xmlschema>=2.0.0'
sudo ./06_build_acrn.sh
```

### If Boot Fails

```bash
sudo ./14_diagnose_boot_issue.sh
sudo ./15_fix_grub_entry.sh
# or
sudo ./17_clean_grub_entry.sh
sudo ./18_verify_grub_and_boot.sh
sudo reboot
```

### If Multiple ACRN Entries in GRUB Menu

```bash
sudo ./19_fix_duplicate_grub_entries.sh
# or quick fix:
sudo ./20_quick_fix_duplicates.sh
sudo reboot
```

---

## 📝 Script Descriptions

### Main Workflow (01-13)

| #   | Script                       | Purpose                             |
| --- | ---------------------------- | ----------------------------------- |
| 01  | `check_bios_iommu.sh`        | Verify BIOS/IOMMU support           |
| 02  | `check_cpu_info.sh`          | Display CPU information             |
| 03  | `check_kernel_rt.sh`         | Check PREEMPT_RT kernel (optional)  |
| 04  | `download_acrn_3.3.sh`       | Download ACRN 3.3 source            |
| 05  | `install_build_deps.sh`      | Install build dependencies          |
| 06  | `build_acrn.sh`              | Build ACRN hypervisor               |
| 07  | `install_acrn_binary.sh`     | Install binary to /boot             |
| 08  | `configure_grub_iommu.sh`    | Configure IOMMU in GRUB             |
| 09  | `configure_cpu_isolation.sh` | Configure CPU isolation             |
| 10  | `configure_irq_affinity.sh`  | Configure IRQ affinity              |
| 11  | `create_grub_entry.sh`       | Create GRUB boot entry              |
| 12  | `verify_acrn.sh`             | Verify ACRN is running (after boot) |
| 13  | `test_acrn_boot.sh`          | Test boot config (before reboot)    |

### Utility Scripts (util_14-18)

| #   | Script                             | Purpose                    |
| --- | ---------------------------------- | -------------------------- |
| 14  | `diagnose_boot_issue.sh`           | Diagnose boot problems     |
| 15  | `fix_grub_entry.sh`                | Fix GRUB entry issues      |
| 16  | `fix_elementpath_compatibility.sh` | Fix Python dependencies    |
| 17  | `clean_grub_entry.sh`              | Clean duplicate parameters |
| 18  | `verify_grub_and_boot.sh`          | Verify GRUB before boot    |
| 19  | `fix_duplicate_grub_entries.sh`    | Fix duplicate GRUB entries |
| 20  | `quick_fix_duplicates.sh`          | Quick fix for duplicates   |

---

## ⚠️ Important Notes

1. **Execute scripts 01-13 in order** - They depend on previous steps
2. **Script 12** should only run AFTER successfully booting with ACRN
3. **Script 13** should run BEFORE rebooting to verify configuration
4. **Utility scripts** (util\_\*) are for troubleshooting, not part of main workflow
5. **Always verify** with script 13 or 18 before rebooting

---

## 📚 Additional Documentation

- `TROUBLESHOOTING_BOOT_ISSUE.md` - Boot issue troubleshooting guide
- `ELEMENTPATH_FIX_INSTRUCTIONS.md` - Python dependency fix guide
- `BUILD_FIX_INSTRUCTIONS.md` - Build issue troubleshooting
- `QUICK_FIX_STEPS.md` - Quick reference for common fixes
