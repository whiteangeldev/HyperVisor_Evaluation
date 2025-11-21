# ACRN Installation Scripts - Execution Order

## Main Installation Workflow (Execute in Order)

### Phase 1: Prerequisites Check

1. **01_check_bios_iommu.sh** - Check BIOS/IOMMU support
2. **02_check_cpu_info.sh** - Check CPU information and capabilities
3. **03_check_kernel_rt.sh** - Check kernel PREEMPT_RT support (optional)

### Phase 2: Download and Build

4. **04_download_acrn_3.4.sh** - Download ACRN source code
5. **05_install_build_deps.sh** - Install build dependencies
6. **06_build_acrn.sh** - Build ACRN hypervisor

### Phase 3: Installation

7. **07_install_acrn_binary.sh** - Install ACRN binary to /boot

### Phase 4: Configuration

8. **08_configure_grub_iommu.sh** - Configure IOMMU in GRUB
9. **09_configure_cpu_isolation.sh** - Configure CPU isolation
10. **10_configure_irq_affinity.sh** - Configure IRQ affinity
11. **11_create_grub_entry.sh** - Create ACRN GRUB boot entry

### Phase 5: Verification

12. **12_verify_acrn.sh** - Verify ACRN is running (run after boot)
13. **13_test_acrn_boot.sh** - Test boot configuration (pre-boot check)

---

## Utility Scripts (Use as Needed)

### Troubleshooting Scripts

- **14_diagnose_boot_issue.sh** - Diagnose boot problems
- **15_fix_grub_entry.sh** - Fix GRUB entry (adds missing intel_iommu=on)
- **16_fix_elementpath_compatibility.sh** - Fix Python dependency issues (for build)
- **17_clean_grub_entry.sh** - Clean GRUB entry (removes duplicates)
- **18_verify_grub_and_boot.sh** - Verify GRUB entry before booting
- **19_fix_duplicate_grub_entries.sh** - Fix duplicate GRUB entries
- **20_quick_fix_duplicates.sh** - Quick fix for duplicate entries

---

## Quick Start

### Standard Installation (First Time)

```bash
sudo ./01_check_bios_iommu.sh
sudo ./02_check_cpu_info.sh
sudo ./03_check_kernel_rt.sh
sudo ./04_download_acrn_3.4.sh
sudo ./05_install_build_deps.sh
sudo ./06_build_acrn.sh
sudo ./07_install_acrn_binary.sh
sudo ./08_configure_grub_iommu.sh
sudo ./09_configure_cpu_isolation.sh
sudo ./10_configure_irq_affinity.sh
sudo ./11_create_grub_entry.sh
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

## Notes

- Scripts 01-13 are the main workflow and should be executed in order
- Scripts 14-18 are utility scripts for troubleshooting and fixing issues
- Always run verification scripts (12, 13, 18) before rebooting
- Script 12 should only be run AFTER successfully booting with ACRN
