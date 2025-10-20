# Scripts Directory
## RT Hypervisor POC - Milestone 1

This directory contains all automation scripts for Milestone 1 setup.

---

## Quick Start

### For Xen (Recommended for First-Time Users)
```bash
./25_master_setup_xen.sh
```

### For Intel ACRN (Advanced Users / Embedded)
```bash
./26_master_setup_acrn.sh
```

---

## Script Categories

### Core Setup Scripts (01-05)
These scripts are common to both hypervisors.

| Script | Purpose | Sudo | Reboot |
|--------|---------|------|--------|
| `01_collect_system_info.sh` | Collect CPU, memory, PCI device info | No | No |
| `02_check_virt_support.sh` | Verify VT-x/VT-d support | No | No |
| `03_backup_current_config.sh` | Backup GRUB and system configs | No | No |
| `04_generate_grub_config.sh` | Generate kernel parameters for isolation | No | No |
| `05_update_grub.sh` | Apply GRUB configuration | **Yes** | **Yes** |

### Xen Hypervisor Scripts (06-13)

| Script | Purpose | Sudo | Reboot |
|--------|---------|------|--------|
| `06_pre_xen_check.sh` | Verify IOMMU after GRUB update | No | No |
| `07_install_xen.sh` | Install Xen packages | **Yes** | No |
| `08_configure_xen_rt.sh` | Configure RT scheduler (RTDS) | No | No |
| `09_apply_xen_config.sh` | Apply Xen configuration | **Yes** | **Yes** |
| `10_map_irq_affinity.sh` | Map current IRQ distribution | No | No |
| `11_generate_irq_script.sh` | Generate IRQ pinning script | No | No |
| `12_create_irq_service.sh` | Create systemd service for IRQ | No | No |
| `13_install_irq_service.sh` | Install IRQ service | **Yes** | No |

### Verification Scripts (14-17)

| Script | Purpose | Sudo | Reboot |
|--------|---------|------|--------|
| `14_verify_isolation.sh` | Verify CPU isolation is working | No | No |
| `15_verify_iommu.sh` | Enumerate IOMMU groups | No | No |
| `16_verify_xen.sh` | Verify Xen hypervisor status | No | No |
| `17_generate_report.sh` | Generate Milestone 1 report (Xen) | No | No |

### Intel ACRN Scripts (18-24)

| Script | Purpose | Sudo | Reboot |
|--------|---------|------|--------|
| `18_pre_acrn_check.sh` | Check ACRN prerequisites | No | No |
| `19_install_acrn_deps.sh` | Install build dependencies | **Yes** | No |
| `20_download_acrn.sh` | Download ACRN source (v3.2) | No | No |
| `21_build_acrn.sh` | Build ACRN hypervisor (~15-30 min) | No | No |
| `22_install_acrn.sh` | Install ACRN to system | **Yes** | **Yes** |
| `23_configure_acrn.sh` | Configure ACRN for RT workloads | No | No |
| `24_verify_acrn.sh` | Verify ACRN hypervisor status | No | No |

### Master Orchestration Scripts (25-27)

| Script | Purpose | Sudo | Reboot |
|--------|---------|------|--------|
| `25_master_setup_xen.sh` | **Automated Xen setup** (interactive) | Mixed | **Yes** |
| `26_master_setup_acrn.sh` | **Automated ACRN setup** (interactive) | Mixed | **Yes** |
| `27_final_report.sh` | **Final comprehensive report** | No | No |

---

## Usage Patterns

### Pattern 1: Automated Setup (Recommended)

**For Xen:**
```bash
./25_master_setup_xen.sh
```

**For ACRN:**
```bash
./26_master_setup_acrn.sh
```

These scripts guide you through the entire process interactively.

### Pattern 2: Manual Step-by-Step

**Xen Manual Setup:**
```bash
# Phase 1: Info gathering
./01_collect_system_info.sh
./02_check_virt_support.sh
./03_backup_current_config.sh

# Phase 2: GRUB
./04_generate_grub_config.sh
sudo ./05_update_grub.sh
sudo reboot

# Phase 3: Xen (after reboot)
./06_pre_xen_check.sh
sudo ./07_install_xen.sh
./08_configure_xen_rt.sh
sudo ./09_apply_xen_config.sh
sudo reboot

# Phase 4: IRQ (after Xen boot)
./10_map_irq_affinity.sh
./11_generate_irq_script.sh
./12_create_irq_service.sh
sudo systemctl stop irqbalance
sudo systemctl disable irqbalance
sudo ./set_irq_affinity.sh
sudo ./13_install_irq_service.sh

# Phase 5: Verify
./14_verify_isolation.sh
./15_verify_iommu.sh
./16_verify_xen.sh
./17_generate_report.sh
./27_final_report.sh
```

**ACRN Manual Setup:**
```bash
# Phase 1: Prerequisites
./01_collect_system_info.sh
./02_check_virt_support.sh
./18_pre_acrn_check.sh

# Phase 2: GRUB (if needed)
./04_generate_grub_config.sh
sudo ./05_update_grub.sh
sudo reboot

# Phase 3: Dependencies
sudo ./19_install_acrn_deps.sh

# Phase 4: Build
./20_download_acrn.sh
./21_build_acrn.sh

# Phase 5: Install
sudo ./22_install_acrn.sh
./23_configure_acrn.sh
sudo update-grub
sudo reboot

# Phase 6: Verify
./24_verify_acrn.sh
./14_verify_isolation.sh
./15_verify_iommu.sh
./27_final_report.sh
```

### Pattern 3: Verification Only

If setup is complete, just run verification:
```bash
# For Xen
./16_verify_xen.sh
./14_verify_isolation.sh
./15_verify_iommu.sh
./17_generate_report.sh

# For ACRN
./24_verify_acrn.sh
./14_verify_isolation.sh
./15_verify_iommu.sh
./27_final_report.sh
```

---

## Script Dependencies

```
01-03 (Info) ─┐
              ├─→ 04-05 (GRUB) ─→ REBOOT ─┐
              │                             │
              │                             ├─→ 06-09 (Xen) ─→ REBOOT ─→ 10-13 (IRQ) ─→ 14-17 (Verify)
              │                             │
              └─────────────────────────────┴─→ 18-24 (ACRN) ─→ REBOOT ─→ 14-15,24,27 (Verify)
```

---

## Output Locations

### Logs
All logs are written to `../logs/`

- `system_info.log` - System inventory
- `virt_support.log` - Virtualization support
- `grub_cmdline.txt` - Generated GRUB parameters
- `xen_install.log` - Xen installation log
- `acrn_build.log` - ACRN build log
- `cpu_isolation.log` - CPU isolation verification
- `iommu_groups.log` - IOMMU groups enumeration
- `xen_status.log` / `acrn_status.log` - Hypervisor status

### Configuration Files
All configs are written to `../configs/`

- `grub_cmdline.txt` - GRUB kernel parameters
- `xen_rt.cfg` - Xen RT scheduler config
- `acrn_rt.conf` - ACRN RT configuration
- `irq-affinity.service` - systemd service for IRQ pinning
- `backup/` - Backups of original files

### Reports
Final reports are written to `../docs/`

- `milestone1_report.md` - Xen-focused report
- `milestone1_final_report.md` - Comprehensive report (both hypervisors)

---

## Troubleshooting

### Script Fails with Permission Denied
```bash
# Make scripts executable
chmod +x *.sh
```

### Script Requires Root
Look for `⚠️ REQUIRES ROOT PRIVILEGES` in script header.
Run with `sudo`:
```bash
sudo ./script_name.sh
```

### System Won't Boot After Changes
1. At GRUB, press 'e' to edit entry
2. Remove new kernel parameters
3. Press Ctrl+X to boot
4. Restore backup: `sudo cp ../configs/backup/grub /etc/default/grub`
5. Run: `sudo update-grub`

### View Script Help
```bash
# Most scripts have headers with usage info
head -20 script_name.sh
```

---

## Script Standards

All scripts follow these conventions:

1. **Header**: Purpose, usage, requirements
2. **Safety**: Check for root when needed
3. **Logging**: Output to both console and log file
4. **Idempotent**: Safe to re-run
5. **Verification**: Check prerequisites before proceeding
6. **Cleanup**: Create backups before modifications

---

## Development Notes

### Adding New Scripts

Follow the naming convention:
- `NN_descriptive_name.sh` where NN is sequence number
- Keep numbering sequential
- Update this README

### Testing Scripts

Test on clean system:
```bash
# Snapshot VM before testing
# Run script
# Verify output
# Check for errors in logs
# Test rollback procedures
```

---

## Support

### Documentation
- Detailed guides in `../docs/`
- Step-by-step: `../docs/STEP_BY_STEP_GUIDE.md`
- ACRN guide: `../docs/ACRN_SETUP_GUIDE.md`
- Quick start: `../docs/QUICK_START.md`

### Logs
Check `../logs/` directory for detailed output.

### Common Issues
See `../docs/QUICK_START.md` troubleshooting section.

---

*Scripts README - Last Updated: 2025-10-17*

