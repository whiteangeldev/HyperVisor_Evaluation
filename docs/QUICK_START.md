# Quick Start Guide
## RT Hypervisor POC - Milestone 1

This guide provides the fastest path to completing Milestone 1 for both Xen and Intel ACRN.

---

## Prerequisites

- Bare metal server with Intel CPU (VT-x, VT-d)
- Ubuntu 22.04 or 24.04 LTS
- 8+ CPU cores, 8+ GB RAM
- SSH access as **ubuntu** user (non-root)
- **sudo privileges required** (you'll be prompted for password)

⚠️ **IMPORTANT**: Do NOT run scripts as root. Run as ubuntu user and let scripts use sudo when needed.

---

## Option 1: Xen RT Hypervisor (Recommended for beginners)

### Automated Setup

```bash
# SSH as ubuntu user (not root)
ssh ubuntu@your-server

cd ~/rt-hypervisor-poc/scripts

# Run master setup script (interactive)
# It will prompt for sudo password when needed
./25_master_setup_xen.sh
```

The script will guide you through:
1. System inventory
2. GRUB configuration (requires reboot)
3. Xen installation (requires sudo)
4. IRQ affinity configuration
5. Validation and reporting

### Manual Step-by-Step

```bash
# Run as ubuntu user (you'll enter sudo password when prompted)

# Phase 1: System Info
./01_collect_system_info.sh
./02_check_virt_support.sh
./03_backup_current_config.sh

# Phase 2: GRUB Config
./04_generate_grub_config.sh
sudo ./05_update_grub.sh           # Requires sudo password
sudo reboot  # REBOOT REQUIRED

# Phase 3: Xen Installation (after reboot)
./06_pre_xen_check.sh
sudo ./07_install_xen.sh
./08_configure_xen_rt.sh
sudo ./09_apply_xen_config.sh
sudo reboot  # REBOOT REQUIRED (select Xen from GRUB)

# Phase 4: IRQ Configuration (after Xen boot)
./10_map_irq_affinity.sh
./11_generate_irq_script.sh
./12_create_irq_service.sh
sudo systemctl stop irqbalance
sudo systemctl disable irqbalance
sudo ./scripts/set_irq_affinity.sh
sudo ./13_install_irq_service.sh

# Phase 5: Validation
./14_verify_isolation.sh
./15_verify_iommu.sh
./16_verify_xen.sh
./17_generate_report.sh
```

### Verification

```bash
# Check Xen is running
xl info

# Check CPU isolation
cat /sys/devices/system/cpu/isolated

# Check IOMMU groups
ls /sys/kernel/iommu_groups/

# View report
cat ~/rt-hypervisor-poc/docs/milestone1_report.md
```

**Expected Results**:
- ✓ Xen hypervisor running with RT scheduler
- ✓ CPUs 2-7 isolated
- ✓ IOMMU enabled with multiple groups
- ✓ IRQs pinned to CPUs 0-1

---

## Option 2: Intel ACRN (Advanced)

### Automated Setup

```bash
cd ~/rt-hypervisor-poc/scripts

# Run master setup script (interactive)
./26_master_setup_acrn.sh
```

The script will guide you through:
1. Pre-installation checks
2. GRUB configuration (if needed)
3. Dependency installation (requires sudo)
4. ACRN download and build (15-30 minutes)
5. ACRN installation and configuration
6. Validation and reporting

### Manual Step-by-Step

```bash
# Phase 1: Prerequisites
./01_collect_system_info.sh
./02_check_virt_support.sh
./21_pre_acrn_check.sh

# Phase 2: GRUB Config (if not done)
./03_backup_current_config.sh
./04_generate_grub_config.sh
sudo ./05_update_grub.sh
sudo reboot  # REBOOT REQUIRED

# Phase 3: ACRN Dependencies (after reboot if needed)
sudo ./25_install_acrn_deps.sh  # ~5-10 minutes

# Phase 4: Download and Build
./23_download_acrn.sh           # ~2-5 minutes
./24_build_acrn.sh              # ~15-30 minutes

# Phase 5: Install and Configure
sudo ./25_install_acrn.sh
./26_configure_acrn.sh

# Review GRUB entry before rebooting!
sudo cat /etc/grub.d/40_custom_acrn
# Edit if needed: sudo nano /etc/grub.d/40_custom_acrn

sudo update-grub
sudo reboot  # REBOOT REQUIRED (select ACRN from GRUB)

# Phase 6: Validation (after ACRN boot)
./27_verify_acrn.sh
./14_verify_isolation.sh
./15_verify_iommu.sh
./27_final_report.sh
```

### Verification

```bash
# Check ACRN is running
ls -la /dev/acrn*

# Check loaded modules
lsmod | grep acrn

# View hypervisor log
acrnlog -t

# List VMs (none yet)
acrnctl list

# Check CPU isolation
cat /sys/devices/system/cpu/isolated

# View report
cat ~/rt-hypervisor-poc/docs/milestone1_final_report.md
```

**Expected Results**:
- ✓ ACRN device nodes present (/dev/acrn_hsm)
- ✓ Service OS running on CPUs 0-1
- ✓ CPUs 2-7 isolated for User OS VMs
- ✓ IOMMU enabled with multiple groups

---

## Troubleshooting Quick Reference

### System Won't Boot After GRUB Changes

1. At GRUB menu, press 'e' to edit entry
2. Remove problematic kernel parameters
3. Press Ctrl+X to boot
4. Restore backup: `sudo cp configs/backup/grub /etc/default/grub`
5. Run: `sudo update-grub`

### Xen Not Starting

```bash
# Boot into non-Xen kernel from GRUB
# Check logs
journalctl -xe | grep -i xen
dmesg | grep -i xen

# Uninstall if needed
sudo apt remove xen-*
```

### ACRN Not Starting

```bash
# Boot into non-ACRN kernel from GRUB
# Check GRUB entry
sudo cat /etc/grub.d/40_custom_acrn

# Check hypervisor binary
ls -lh /boot/acrn.*

# Review build log
cat ~/rt-hypervisor-poc/logs/acrn_install.log
```

### IOMMU Not Working

```bash
# Check BIOS settings - VT-d must be enabled
# Check kernel parameters
cat /proc/cmdline | grep iommu

# Should show: intel_iommu=on

# Check dmesg
dmesg | grep -i iommu
```

### CPU Isolation Not Working

```bash
# Check kernel parameters
cat /proc/cmdline | grep -E "(isolcpus|nohz_full|rcu_nocbs)"

# Check isolation status
cat /sys/devices/system/cpu/isolated

# If empty, kernel parameters not applied correctly
# Re-run: ./04_generate_grub_config.sh
#         sudo ./05_update_grub.sh
#         sudo reboot
```

---

## Script Overview

| Script | Purpose | Requires Root | Requires Reboot |
|--------|---------|---------------|-----------------|
| 01-03 | System inventory and backup | No | No |
| 04-05 | GRUB configuration | 05 only | After 05 |
| 06-09 | Xen installation | 07, 09 | After 09 |
| 10-13 | IRQ affinity | 13 only | No |
| 14-17 | Verification and reporting | No | No |
| 18 | ACRN pre-check | No | No |
| 19 | ACRN dependencies | Yes | No |
| 20-21 | ACRN download and build | No | No |
| 22-23 | ACRN install and config | 22 only | After 22 |
| 24 | ACRN verification | No | No |
| 25 | Xen master script | Interactive | Yes |
| 26 | ACRN master script | Interactive | Yes |
| 27 | Final comprehensive report | No | No |

---

## Expected Timeline

### Xen Setup
- **Preparation**: 10 minutes
- **GRUB config + reboot**: 15 minutes
- **Xen install + reboot**: 20 minutes
- **IRQ configuration**: 10 minutes
- **Validation**: 10 minutes
- **Total**: ~65 minutes (including reboots)

### ACRN Setup
- **Preparation**: 15 minutes
- **GRUB config + reboot** (if needed): 15 minutes
- **Dependencies install**: 10 minutes
- **ACRN download**: 5 minutes
- **ACRN build**: 15-30 minutes
- **ACRN install + reboot**: 15 minutes
- **Validation**: 10 minutes
- **Total**: ~85-100 minutes (including reboots and build)

---

## Success Criteria

### Milestone 1 Complete When:

- ✓ Hypervisor (Xen or ACRN) is running
- ✓ `xl info` (Xen) or `ls /dev/acrn*` (ACRN) succeeds
- ✓ CPU isolation active: `cat /sys/devices/system/cpu/isolated` shows CPUs
- ✓ IOMMU enabled: `ls /sys/kernel/iommu_groups/` shows groups
- ✓ Kernel parameters include: isolcpus, nohz_full, rcu_nocbs, intel_iommu=on
- ✓ irqbalance disabled: `systemctl status irqbalance` shows inactive
- ✓ All verification scripts pass
- ✓ Report generated in `docs/` directory

---

## Next Steps: Milestone 2

Once Milestone 1 is complete:

1. **Create RT Guest VM**
   - Install Ubuntu with PREEMPT_RT kernel
   - Pin to isolated CPUs (2-3)
   - Configure for real-time workloads

2. **Create GPOS Guest VM**
   - Install Ubuntu or Windows
   - Pin to CPUs 4-7
   - Use for stress testing

3. **Configure VFIO Passthrough**
   - Identify devices in IOMMU groups
   - Pass through NIC to RT VM
   - Pass through USB/PCIe devices

4. **Performance Testing**
   - Run cyclictest on RT VM (baseline)
   - Apply stress-ng on GPOS VM
   - Measure latency under stress
   - Collect traces with ftrace/perf
   - Generate performance report

---

## Support and Resources

### Documentation
- `docs/STEP_BY_STEP_GUIDE.md` - Detailed Xen guide
- `docs/ACRN_SETUP_GUIDE.md` - Detailed ACRN guide
- `README.md` - Project overview

### Logs
- All logs stored in `logs/` directory
- Each script generates its own log file
- Review logs if script fails

### Configuration Files
- Stored in `configs/` directory
- Includes GRUB parameters, Xen config, ACRN config
- Backup files in `configs/backup/`

### Getting Help
- Review script output carefully
- Check logs in `logs/` directory
- Consult troubleshooting section above
- Review official documentation (Xen Project, ACRN Project)

---

*Quick Start Guide - Last Updated: 2025-10-17*

