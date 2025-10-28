# Milestone 1 Execution Checklist
## Real-Time Hypervisor POC

Use this checklist to track your progress through Milestone 1.

---

## Pre-Execution

- [ ] SSH access to bare metal server confirmed
- [ ] sudo privileges verified
- [ ] Server has Intel CPU with VT-x and VT-d
- [ ] 8+ CPU cores available
- [ ] 8+ GB RAM available
- [ ] 20+ GB free disk space
- [ ] Internet connectivity confirmed
- [ ] Backup important data (system will reboot multiple times)

---

## Choose Your Path

Select ONE hypervisor to start with:

- [ ] **Path A: Xen RT Hypervisor** (recommended for first-time)
- [ ] **Path B: Intel ACRN** (advanced, for embedded/IoT)

You can evaluate both later, but focus on one for initial setup.

---

## Path A: Xen RT Hypervisor

### Phase 1: System Inventory (No Reboot)

- [ ] Run: `./scripts/01_collect_system_info.sh`
  - [ ] Log created: `logs/system_info.log`
  - [ ] CPU count confirmed: _____ cores
  
- [ ] Run: `./scripts/02_check_virt_support.sh`
  - [ ] Log created: `logs/virt_support.log`
  - [ ] VMX flag present: ✓
  
- [ ] Run: `./scripts/03_backup_current_config.sh`
  - [ ] Backup created: `configs/backup/`

### Phase 2: GRUB Configuration (Requires Reboot)

- [ ] Run: `./scripts/04_generate_grub_config.sh`
  - [ ] Config created: `configs/grub_cmdline.txt`
  - [ ] Review parameters: Housekeeping CPUs = _____, Isolated CPUs = _____
  
- [ ] Run: `sudo ./scripts/05_update_grub.sh`
  - [ ] GRUB updated successfully: ✓
  - [ ] Backup created: `/etc/default/grub.bak`
  
- [ ] **REBOOT SYSTEM**: `sudo reboot`

- [ ] After reboot, verify: `cat /proc/cmdline`
  - [ ] `intel_iommu=on` present: ✓
  - [ ] `isolcpus=` present: ✓
  - [ ] `nohz_full=` present: ✓
  - [ ] `rcu_nocbs=` present: ✓

### Phase 3: Xen Installation (Requires Reboot)

- [ ] Run: `./scripts/06_pre_xen_check.sh`
  - [ ] IOMMU groups visible: ✓
  - [ ] Log created: `logs/iommu_status.log`
  
- [ ] Run: `sudo ./scripts/07_install_xen.sh`
  - [ ] Xen packages installed: ✓
  - [ ] Log created: `logs/xen_install.log`
  - [ ] `/etc/xen/` directory exists: ✓
  
- [ ] Run: `./scripts/08_configure_xen_rt.sh`
  - [ ] Config created: `configs/xen_rt.cfg`
  - [ ] RT scheduler configured: ✓
  
- [ ] Run: `sudo ./scripts/09_apply_xen_config.sh`
  - [ ] Xen config applied: ✓
  
- [ ] **REBOOT SYSTEM**: `sudo reboot`
  - [ ] Select Xen entry from GRUB menu
  
- [ ] After reboot, verify: `xl info`
  - [ ] Xen hypervisor running: ✓
  - [ ] Scheduler: rtds or credit2: _____

### Phase 4: IRQ Affinity (No Reboot)

- [ ] Run: `./scripts/10_map_irq_affinity.sh`
  - [ ] Log created: `logs/irq_affinity_before.log`
  
- [ ] Run: `./scripts/11_generate_irq_script.sh`
  - [ ] Script created: `scripts/set_irq_affinity.sh`
  
- [ ] Run: `./scripts/12_create_irq_service.sh`
  - [ ] Service file created: `configs/irq-affinity.service`
  
- [ ] Run: `sudo systemctl stop irqbalance`
  - [ ] irqbalance stopped: ✓
  
- [ ] Run: `sudo systemctl disable irqbalance`
  - [ ] irqbalance disabled: ✓
  
- [ ] Run: `sudo ./scripts/set_irq_affinity.sh`
  - [ ] IRQ affinity set: ✓
  
- [ ] Run: `sudo ./scripts/13_install_irq_service.sh`
  - [ ] Service installed: ✓
  - [ ] Service enabled: ✓

### Phase 5: Validation (No Reboot)

- [ ] Run: `./scripts/14_verify_isolation.sh`
  - [ ] Log created: `logs/cpu_isolation.log`
  - [ ] Isolated CPUs verified: _____
  - [ ] All checks passed: ✓
  
- [ ] Run: `./scripts/15_verify_iommu.sh`
  - [ ] Log created: `logs/iommu_groups.log`
  - [ ] IOMMU groups count: _____
  - [ ] All checks passed: ✓
  
- [ ] Run: `./scripts/16_verify_xen.sh`
  - [ ] Log created: `logs/xen_status.log`
  - [ ] Xen running with RT scheduler: ✓
  - [ ] Dom0 vCPUs listed: ✓
  
- [ ] Run: `./scripts/17_generate_report.sh`
  - [ ] Report created: `docs/milestone1_report.md`
  - [ ] Result: PASS / CONDITIONAL / FAIL: _____

### Phase 6: Final Report

- [ ] Run: `./scripts/27_final_report.sh`
  - [ ] Final report: `docs/milestone1_final_report.md`
  - [ ] Review and confirm all sections

---

## Path B: Intel ACRN

### Phase 1: Prerequisites (No Reboot)

- [ ] Run: `./scripts/01_collect_system_info.sh`
  - [ ] Log created: `logs/system_info.log`
  - [ ] Intel CPU confirmed: ✓
  
- [ ] Run: `./scripts/02_check_virt_support.sh`
  - [ ] VMX flag present: ✓
  
- [ ] Run: `./scripts/21_pre_acrn_check.sh`
  - [ ] Log created: `logs/acrn_pre_check.log`
  - [ ] Score: _____% (70%+ to proceed)

### Phase 2: GRUB (If Needed, Requires Reboot)

If GRUB not configured (check `/proc/cmdline`):

- [ ] Run: `./scripts/03_backup_current_config.sh`
- [ ] Run: `./scripts/04_generate_grub_config.sh`
- [ ] Run: `sudo ./scripts/05_update_grub.sh`
- [ ] **REBOOT**: `sudo reboot`
- [ ] Verify: `cat /proc/cmdline`

### Phase 3: Dependencies (~10 minutes)

- [ ] Run: `sudo ./scripts/25_install_acrn_deps.sh`
  - [ ] Log created: `logs/acrn_deps_install.log`
  - [ ] Build tools installed: ✓
  - [ ] Python dependencies installed: ✓

### Phase 4: Download ACRN (~5 minutes)

- [ ] Run: `./scripts/23_download_acrn.sh`
  - [ ] Log created: `logs/acrn_download.log`
  - [ ] Repository cloned: `acrn-hypervisor/`
  - [ ] Version checked out: v3.2 or later

### Phase 5: Build ACRN (~15-30 minutes)

- [ ] Run: `./scripts/24_build_acrn.sh`
  - [ ] Log created: `logs/acrn_build.log`
  - [ ] Hypervisor built: `acrn-hypervisor/build/hypervisor/acrn.bin`
  - [ ] Device model built: `acrn-hypervisor/build/devicemodel/acrn-dm`
  - [ ] Tools built: ✓

### Phase 6: Install ACRN (Requires Reboot)

- [ ] Run: `sudo ./scripts/25_install_acrn.sh`
  - [ ] Log created: `logs/acrn_install.log`
  - [ ] Hypervisor copied to `/boot/acrn.bin`: ✓
  - [ ] Tools installed to `/usr/bin/`: ✓
  - [ ] GRUB entry created: `/etc/grub.d/40_custom_acrn`
  
- [ ] **IMPORTANT**: Review GRUB entry
  - [ ] Run: `sudo cat /etc/grub.d/40_custom_acrn`
  - [ ] Verify root UUID matches: `findmnt -n -o UUID /`
  - [ ] Verify kernel path: `/boot/vmlinuz`
  - [ ] Edit if needed: `sudo nano /etc/grub.d/40_custom_acrn`
  
- [ ] Run: `./scripts/26_configure_acrn.sh`
  - [ ] Config created: `configs/acrn_rt.conf`
  - [ ] CPU allocation reviewed: ✓
  
- [ ] Run: `sudo update-grub`
  - [ ] GRUB updated: ✓
  
- [ ] **REBOOT**: `sudo reboot`
  - [ ] Select "ACRN Hypervisor" from GRUB menu

### Phase 7: Validation (After ACRN Boot)

- [ ] Verify ACRN booted: `ls -la /dev/acrn*`
  - [ ] Device nodes present: ✓
  
- [ ] Run: `./scripts/27_verify_acrn.sh`
  - [ ] Log created: `logs/acrn_status.log`
  - [ ] ACRN running: ✓
  - [ ] Tools available: ✓
  
- [ ] Run: `./scripts/14_verify_isolation.sh`
  - [ ] CPU isolation verified: ✓
  
- [ ] Run: `./scripts/15_verify_iommu.sh`
  - [ ] IOMMU groups enumerated: ✓
  
- [ ] Run: `./scripts/27_final_report.sh`
  - [ ] Final report: `docs/milestone1_final_report.md`
  - [ ] Result: PASS / CONDITIONAL / FAIL: _____

---

## Automated Master Scripts

### Option: Use Master Script (Xen)

Instead of manual steps, run:
- [ ] `./scripts/25_master_setup_xen.sh`
  - Follows user through all phases interactively

### Option: Use Master Script (ACRN)

Instead of manual steps, run:
- [ ] `./scripts/26_master_setup_acrn.sh`
  - Follows user through all phases interactively

---

## Milestone 1 Completion Criteria

### Required

- [ ] Hypervisor running (Xen or ACRN)
- [ ] CPU isolation active (check: `cat /sys/devices/system/cpu/isolated`)
- [ ] IOMMU enabled (check: `ls /sys/kernel/iommu_groups/`)
- [ ] Kernel parameters applied (check: `cat /proc/cmdline`)
- [ ] All verification scripts pass
- [ ] Final report generated

### Deliverables

- [ ] All logs in `logs/` directory (10+ files)
- [ ] Configuration files in `configs/` directory
- [ ] Final report: `docs/milestone1_final_report.md`
- [ ] Scripts are reproducible (all in `scripts/`)

### Acceptance Score

- [ ] 80%+ on verification checks = **PASS**
- [ ] 60-79% on verification checks = **CONDITIONAL PASS**
- [ ] <60% on verification checks = **INCOMPLETE**

---

## Troubleshooting Quick Reference

### System Won't Boot
- Access GRUB menu, press 'e' to edit
- Remove `isolcpus` and other new parameters
- Boot and restore: `sudo cp configs/backup/grub /etc/default/grub`

### Xen Not Starting
- Select non-Xen kernel from GRUB
- Check: `journalctl -xe | grep -i xen`
- Review: `logs/xen_install.log`

### ACRN Not Starting
- Select non-ACRN kernel from GRUB
- Review GRUB entry: `sudo cat /etc/grub.d/40_custom_acrn`
- Check: `logs/acrn_install.log`

### IOMMU Not Working
- Check BIOS: VT-d must be enabled
- Verify parameter: `cat /proc/cmdline | grep iommu`
- Check dmesg: `dmesg | grep -i iommu`

### Build Failures (ACRN)
- Re-run: `sudo ./scripts/25_install_acrn_deps.sh`
- Clean build: `cd acrn-hypervisor && make clean`
- Rebuild: `./scripts/24_build_acrn.sh`

---

## Time Estimates

### Xen Path
- System inventory: 10 min
- GRUB config: 15 min (includes reboot)
- Xen install: 20 min (includes reboot)
- IRQ config: 10 min
- Validation: 10 min
- **Total: ~65 minutes**

### ACRN Path
- Prerequisites: 15 min
- GRUB config (if needed): 15 min (includes reboot)
- Dependencies: 10 min
- ACRN download: 5 min
- ACRN build: 15-30 min
- ACRN install: 15 min (includes reboot)
- Validation: 10 min
- **Total: ~85-100 minutes**

---

## Sign-Off

### Completed By
- Name: _____________________
- Date: _____________________
- Hypervisor: [ ] Xen  [ ] ACRN
- Result: [ ] PASS  [ ] CONDITIONAL  [ ] INCOMPLETE

### Notes
```
[Add any observations, issues, or deviations from standard procedure]
```

### Next Steps
- [ ] Milestone 2: VM Configuration
- [ ] Create RT Guest VM
- [ ] Create GPOS Guest VM
- [ ] Configure VFIO passthrough
- [ ] Performance testing (cyclictest)

---

*Execution Checklist - Last Updated: 2025-10-17*

