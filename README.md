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

### Complete Xen RT Setup

For full Xen setup with RTDS (Real-Time Deferrable Server) scheduler:

```bash
# Navigate to project
cd ~/HyperVisor_Evaluation

# Install dependencies and build Xen with RTDS
sudo ./scripts/10_install_xen_build_deps.sh
sudo ./scripts/12_build_xen_minimal.sh  # 20-40 minutes

# Reboot into new Xen
sudo reboot

# Verify RTDS is available
sudo xl cpupool-create name="test" sched="rtds"
sudo xl cpupool-list
sudo xl cpupool-destroy test
```

**Why build from source?** Ubuntu's packaged Xen doesn't include the RTDS scheduler, which is required for hard real-time performance (<10μs latency).

### Documentation
- **BUILD_XEN_RTDS_GUIDE.md** - Complete guide for building Xen with RT scheduler ⭐
- **RTDS_CONFIGURATION_GUIDE.md** - RT scheduler configuration and troubleshooting
- **scripts/README.md** - Detailed script reference and usage patterns
- **docs/STEP_BY_STEP_GUIDE.md** - Step-by-step Xen setup guide

## Status

### Milestone 1: Xen RT Setup
- [x] Phase 1.1: Project setup and system inventory
- [x] Phase 1.2: GRUB configuration for IOMMU and isolation
- [x] Phase 1.3: Xen hypervisor installation
- [x] Phase 1.4: Build Xen with RTDS scheduler from source
- [x] Phase 1.5: IRQ affinity configuration
- [x] Phase 1.6: Validation and testing

### Key Features
- ✅ CPU Isolation (CPUs 4-7 for RT workloads)
- ✅ IOMMU/VT-d enabled for device passthrough
- ✅ RTDS scheduler built and available
- ✅ IRQ affinity pinning to housekeeping CPUs
- ✅ Comprehensive verification scripts

## Scripts Available

### Core Setup (01-05)
- `01_collect_system_info.sh` - System inventory
- `02_check_virt_support.sh` - VT-x/VT-d verification
- `03_backup_current_config.sh` - Backup configs
- `04_generate_grub_config.sh` - Generate GRUB parameters
- `05_update_grub.sh` - Apply GRUB config (requires sudo)

### Xen Setup (06-09)
- `06_pre_xen_check.sh` - Pre-installation verification
- `07_install_xen.sh` - Install Xen packages (requires sudo)
- `08_configure_xen_rt.sh` - Configure RT scheduler
- `09_apply_xen_config.sh` - Apply Xen config (requires sudo)

### Xen RT Scheduler Build (10-12) - For RTDS Support
- `10_install_xen_build_deps.sh` - Install Xen build dependencies (requires sudo)
- `11_cleanup_failed_build.sh` - Clean up failed Xen build (requires sudo)
- `12_build_xen_minimal.sh` - Build Xen from source with RTDS (requires sudo)

### IRQ Affinity Setup (13-16)
- `13_map_irq_affinity.sh` - Map current IRQ affinity
- `14_generate_irq_script.sh` - Generate IRQ pinning script
- `15_create_irq_service.sh` - Create systemd service
- `16_install_irq_service.sh` - Install IRQ service (requires sudo)

### Verification (17-20)
- `17_verify_isolation.sh` - Verify CPU isolation
- `18_verify_iommu.sh` - Verify IOMMU groups
- `19_verify_xen_rt.sh` - Verify Xen RT scheduler status
- `20_verify_irq_affinity.sh` - Verify IRQ affinity configuration

