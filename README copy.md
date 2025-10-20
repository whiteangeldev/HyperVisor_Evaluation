# Real-Time Hypervisor POC - Milestone 1

## Project Overview
This POC demonstrates real-time performance stability using hypervisors (Xen RT, ACRN) with CPU isolation and VFIO passthrough.

## System Information
- **Hardware**: Intel Atom C2750 @ 2.40GHz (8 cores)
- **OS**: Ubuntu 24.04.2 LTS (Noble Numbat)
- **Kernel**: 6.8.0-85-generic (PREEMPT_DYNAMIC)
- **NICs**: 2x Intel I354 2.5GbE Backplane
- **IOMMU**: Intel C2000 RCEC (hardware present)
- **User**: ubuntu (non-root, requires sudo for privileged operations)

## CPU Allocation Strategy
- **Housekeeping CPUs (0-3)**: System/Dom0/Service OS
- **Isolated CPUs (4-7)**: Real-time guests and workloads

## Milestone 1 Goals
1. Install and configure hypervisor(s)
   - **Xen** with RT scheduler (RTDS)
   - **Intel ACRN** (real-time embedded hypervisor)
2. Enable IOMMU/VT-d for device passthrough
3. Configure CPU isolation (isolcpus, nohz_full, rcu_nocbs)
4. Set up IRQ affinity for deterministic latency
5. Verify isolation and stability

## Directory Structure
```
rt-hypervisor-poc/
├── scripts/          # Automation scripts
├── logs/            # Test outputs and system logs
├── docs/            # Documentation and reports
└── configs/         # Configuration files (GRUB, Xen, etc.)
```

## Quick Start

⚠️ **Important**: Run as **ubuntu** user (not root). Scripts will prompt for sudo password when needed.

### Choose Your Hypervisor

**Option 1: Xen RT Hypervisor** (Recommended for general use)
```bash
# Run as ubuntu user
cd ~/rt-hypervisor-poc/scripts
./25_master_setup_xen.sh
# Script will request sudo password when needed
```

**Option 2: Intel ACRN** (Optimized for embedded/IoT)
```bash
# Run as ubuntu user
cd ~/rt-hypervisor-poc/scripts
./26_master_setup_acrn.sh
# Script will request sudo password when needed
```

### Documentation
- **Quick Start**: `docs/QUICK_START.md` - Fastest path to completion
- **Xen Detailed Guide**: `docs/STEP_BY_STEP_GUIDE.md` - Step-by-step Xen setup
- **ACRN Setup Guide**: `docs/ACRN_SETUP_GUIDE.md` - Comprehensive ACRN setup

## Status

### Xen Path
- [x] Phase 1.1: Project setup and system inventory
- [ ] Phase 1.2: GRUB configuration for IOMMU and isolation
- [ ] Phase 1.3: Xen hypervisor installation
- [ ] Phase 1.4: IRQ affinity configuration
- [ ] Phase 1.5: Validation and testing

### ACRN Path
- [x] Phase 1.1: Prerequisites and system checks
- [ ] Phase 1.2: GRUB configuration (if needed)
- [ ] Phase 1.3: ACRN dependencies installation
- [ ] Phase 1.4: ACRN download and build
- [ ] Phase 1.5: ACRN installation and configuration
- [ ] Phase 1.6: Validation and testing

## Scripts Available

### Core Setup (01-05)
- `01_collect_system_info.sh` - System inventory
- `02_check_virt_support.sh` - VT-x/VT-d verification
- `03_backup_current_config.sh` - Backup configs
- `04_generate_grub_config.sh` - Generate GRUB parameters
- `05_update_grub.sh` - Apply GRUB config (requires sudo)

### Xen Setup (06-13)
- `06_pre_xen_check.sh` - Pre-installation verification
- `07_install_xen.sh` - Install Xen packages (requires sudo)
- `08_configure_xen_rt.sh` - Configure RT scheduler
- `09_apply_xen_config.sh` - Apply Xen config (requires sudo)
- `10_map_irq_affinity.sh` - Map current IRQ affinity
- `11_generate_irq_script.sh` - Generate IRQ pinning script
- `12_create_irq_service.sh` - Create systemd service
- `13_install_irq_service.sh` - Install IRQ service (requires sudo)

### Verification (14-17)
- `14_verify_isolation.sh` - Verify CPU isolation
- `15_verify_iommu.sh` - Verify IOMMU groups
- `16_verify_xen.sh` - Verify Xen status
- `17_generate_report.sh` - Generate Milestone 1 report

### ACRN Setup (18-24)
- `18_pre_acrn_check.sh` - ACRN prerequisites check
- `19_install_acrn_deps.sh` - Install build dependencies (requires sudo)
- `20_download_acrn.sh` - Download ACRN source
- `21_build_acrn.sh` - Build ACRN hypervisor
- `22_install_acrn.sh` - Install ACRN to system (requires sudo)
- `23_configure_acrn.sh` - Configure ACRN for RT
- `24_verify_acrn.sh` - Verify ACRN status

### Master Scripts (25-27)
- `25_master_setup_xen.sh` - **Automated Xen setup (interactive)**
- `26_master_setup_acrn.sh` - **Automated ACRN setup (interactive)**
- `27_final_report.sh` - **Comprehensive final report**

