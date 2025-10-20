# Milestone 1: Step-by-Step Implementation Guide

## Overview
This guide breaks down Milestone 1 into very granular, retryable steps.

⚠️ **IMPORTANT**: 
- Run all commands as **ubuntu** user (NOT root)
- Scripts will prompt for sudo password when needed
- Never use `sudo -i` or `su -` to become root

---

## PHASE 1.1: System Inventory and Baseline

### Step 1.1.1: Collect CPU Information
```bash
# SSH as ubuntu user
ssh ubuntu@your-server

cd ~/rt-hypervisor-poc
./scripts/01_collect_system_info.sh
```
**Purpose**: Document baseline system configuration.  
**Output**: `logs/system_info.log`  
**User**: Run as ubuntu (no sudo needed)  
**Validation**: File exists and contains CPU, memory, PCI device info.

### Step 1.1.2: Check Virtualization Support
```bash
./scripts/02_check_virt_support.sh
```
**Purpose**: Verify VT-x/VT-d hardware capabilities.  
**Output**: `logs/virt_support.log`  
**Validation**: VT-x (vmx) flag present, IOMMU hardware detected.

### Step 1.1.3: Document Current Kernel Parameters
```bash
./scripts/03_backup_current_config.sh
```
**Purpose**: Backup existing GRUB and system configs.  
**Output**: `configs/backup/`  
**Validation**: Backup files created with timestamps.

---

## PHASE 1.2: GRUB Configuration (IOMMU + CPU Isolation)

### Step 1.2.1: Generate GRUB Configuration
```bash
./scripts/04_generate_grub_config.sh
```
**Purpose**: Create GRUB parameters for IOMMU, isolation, and RT tuning.  
**Output**: `configs/grub_cmdline.txt`  
**Parameters**:
- `intel_iommu=on`
- `iommu=pt`
- `isolcpus=2-7`
- `nohz_full=2-7`
- `rcu_nocbs=2-7`
- `nosoftlockup`
- `idle=poll` (or `mwait=0` for power vs latency trade-off)

**Validation**: Config file generated, parameters listed.

### Step 1.2.2: Update GRUB Configuration (Manual)
**⚠️ REQUIRES SUDO - Run as ubuntu user:**
```bash
# You'll be prompted for ubuntu user's sudo password
sudo ./scripts/05_update_grub.sh
```
**Purpose**: Apply new kernel parameters to GRUB.  
**User**: Run as ubuntu, script uses sudo  
**Actions**:
- Edits `/etc/default/grub`
- Runs `update-grub`
- Creates backup of original file

**Validation**: GRUB updated, no errors.

### Step 1.2.3: Reboot System (Manual)
**⚠️ REQUIRES REBOOT - Run manually:**
```bash
sudo reboot
```
**Purpose**: Boot with new kernel parameters.  
**Validation**: After reboot, run `cat /proc/cmdline` to verify parameters applied.

---

## PHASE 1.3: Hypervisor Installation (Xen)

### Step 1.3.1: Pre-installation Check
```bash
./scripts/06_pre_xen_check.sh
```
**Purpose**: Verify IOMMU is enabled after reboot.  
**Output**: `logs/iommu_status.log`  
**Validation**: IOMMU groups visible in `/sys/kernel/iommu_groups/`

### Step 1.3.2: Install Xen Packages (Manual)
**⚠️ REQUIRES SUDO - Run manually:**
```bash
sudo ./scripts/07_install_xen.sh
```
**Purpose**: Install Xen hypervisor and tools.  
**Actions**:
- `apt update`
- Install `xen-hypervisor-amd64`, `xen-tools`, `xen-utils-common`
- Configure Xen to use RT scheduler

**Validation**: Xen packages installed, `/etc/xen/` directory exists.

### Step 1.3.3: Configure Xen RT Scheduler
```bash
./scripts/08_configure_xen_rt.sh
```
**Purpose**: Generate Xen configuration for RT scheduler.  
**Output**: `configs/xen_rt.cfg`  
**Parameters**:
- `sched=rtds` (Real-Time Deferrable Server)
- CPU pinning for dom0
- Reserve CPUs 2-7 for RT guests

**Validation**: Config file created.

### Step 1.3.4: Apply Xen Configuration (Manual)
**⚠️ REQUIRES SUDO - Run manually:**
```bash
sudo ./scripts/09_apply_xen_config.sh
```
**Purpose**: Copy Xen config to system directories.  
**Validation**: Files copied, no errors.

### Step 1.3.5: Reboot into Xen (Manual)
**⚠️ REQUIRES REBOOT - Run manually:**
```bash
sudo reboot
```
**Purpose**: Boot into Xen hypervisor.  
**Validation**: After reboot, run `xl info` to verify Xen is running.

---

## PHASE 1.4: IRQ Affinity Configuration

### Step 1.4.1: Map Current IRQ Affinity
```bash
./scripts/10_map_irq_affinity.sh
```
**Purpose**: Document baseline IRQ distribution.  
**Output**: `logs/irq_affinity_before.log`  
**Validation**: Log shows IRQ numbers and CPU affinities.

### Step 1.4.2: Generate IRQ Affinity Script
```bash
./scripts/11_generate_irq_script.sh
```
**Purpose**: Create script to pin IRQs to CPUs 0-1 (non-isolated).  
**Output**: `scripts/set_irq_affinity.sh`  
**Validation**: Script generated with IRQ pinning commands.

### Step 1.4.3: Disable irqbalance (Manual)
**⚠️ REQUIRES SUDO - Run manually:**
```bash
sudo systemctl stop irqbalance
sudo systemctl disable irqbalance
```
**Purpose**: Prevent automatic IRQ rebalancing.  
**Validation**: `systemctl status irqbalance` shows disabled.

### Step 1.4.4: Apply IRQ Affinity (Manual)
**⚠️ REQUIRES SUDO - Run manually:**
```bash
sudo ./scripts/set_irq_affinity.sh
```
**Purpose**: Pin all IRQs to CPUs 0-1.  
**Validation**: Check `/proc/irq/*/smp_affinity_list` for each IRQ.

### Step 1.4.5: Make IRQ Affinity Persistent
```bash
./scripts/12_create_irq_service.sh
```
**Purpose**: Generate systemd service to apply IRQ affinity on boot.  
**Output**: `configs/irq-affinity.service`  
**Validation**: Service file created.

### Step 1.4.6: Install Systemd Service (Manual)
**⚠️ REQUIRES SUDO - Run manually:**
```bash
sudo ./scripts/13_install_irq_service.sh
```
**Purpose**: Enable IRQ affinity service.  
**Validation**: Service enabled, will run on boot.

---

## PHASE 1.5: Validation and Testing

### Step 1.5.1: Verify CPU Isolation
```bash
./scripts/14_verify_isolation.sh
```
**Purpose**: Confirm CPUs 2-7 are isolated.  
**Output**: `logs/cpu_isolation.log`  
**Validation**: 
- `/proc/cmdline` shows isolation parameters
- CPUs 2-7 have minimal task activity
- `cat /sys/devices/system/cpu/isolated` shows 2-7

### Step 1.5.2: Verify IOMMU Groups
```bash
./scripts/15_verify_iommu.sh
```
**Purpose**: List IOMMU groups for device passthrough.  
**Output**: `logs/iommu_groups.log`  
**Validation**: Intel I354 NICs in separate IOMMU groups.

### Step 1.5.3: Verify Xen Status
```bash
./scripts/16_verify_xen.sh
```
**Purpose**: Confirm Xen hypervisor is operational.  
**Output**: `logs/xen_status.log`  
**Validation**: 
- `xl info` shows hypervisor version and resources
- RT scheduler (rtds) is active

### Step 1.5.4: Generate System Report
```bash
./scripts/17_generate_report.sh
```
**Purpose**: Create comprehensive report of Milestone 1.  
**Output**: `docs/milestone1_report.md`  
**Contents**:
- System configuration
- GRUB parameters
- IOMMU status
- CPU isolation verification
- IRQ affinity maps
- Xen configuration

---

## Rollback Procedures

### If System Fails to Boot
1. Access GRUB menu at boot
2. Press 'e' to edit boot entry
3. Remove problematic kernel parameters
4. Press Ctrl+X to boot
5. Restore backup: `sudo cp configs/backup/grub /etc/default/grub`
6. Run: `sudo update-grub`

### If Xen Fails to Start
1. Reboot and select non-Xen kernel from GRUB menu
2. Check logs: `journalctl -xe | grep -i xen`
3. Uninstall Xen: `sudo apt remove xen-*`

### If Network is Lost
1. IRQ affinity might have affected network
2. Restore IRQs: `sudo systemctl start irqbalance`
3. Or manually: `echo ff > /proc/irq/IRQ_NUM/smp_affinity` for network IRQ

---

## Success Criteria

✅ **Milestone 1 Complete When**:
1. System boots with IOMMU enabled
2. CPUs 2-7 are isolated (verified in logs)
3. Xen hypervisor operational with RT scheduler
4. IRQs pinned to CPUs 0-1
5. IOMMU groups enumerated
6. All scripts and configs documented
7. Report generated with evidence

---

## Next Steps (Milestone 2)
- Configure RT guest VM
- Configure GPOS guest VM
- Set up VFIO device passthrough

