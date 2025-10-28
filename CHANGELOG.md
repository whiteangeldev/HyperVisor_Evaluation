# Changelog - HyperVisor_Evaluation

## [Updated] - October 28, 2025

### Added - RT Scheduler Build Scripts

Three new scripts have been added to enable building Xen with RTDS (Real-Time Deferrable Server) scheduler from source:

#### New Scripts (10-12)

**Script 10: `install_xen_build_deps.sh`**
- Purpose: Install all dependencies required to build Xen from source
- Includes: gcc, make, python3-dev, build tools, libraries
- Runtime: ~5 minutes
- Requires: sudo

**Script 11: `cleanup_failed_build.sh`**
- Purpose: Clean up failed Xen build attempts
- Removes: `/usr/local/src/xen-rtds-build` directory
- Use when: Build fails and you need to start fresh
- Requires: sudo

**Script 12: `build_xen_minimal.sh`**
- Purpose: Build Xen 4.17.4 with RTDS scheduler support
- Actions:
  - Downloads Xen 4.17.4 source
  - Configures with RTDS enabled
  - Compiles hypervisor and essential tools
  - Backs up current Xen installation
  - Installs new Xen
  - Updates GRUB
- Runtime: 20-40 minutes
- Disk space: ~3GB
- Requires: sudo

### Changed - Script Renumbering

To accommodate the new RT scheduler build scripts, existing scripts have been renumbered:

#### IRQ Affinity Scripts (10-13 → 13-16)
- `10_map_irq_affinity.sh` → `13_map_irq_affinity.sh`
- `11_generate_irq_script.sh` → `14_generate_irq_script.sh`
- `12_create_irq_service.sh` → `15_create_irq_service.sh`
- `13_install_irq_service.sh` → `16_install_irq_service.sh`

#### Verification Scripts (14-17 → 17-20)
- `14_verify_isolation.sh` → `17_verify_isolation.sh`
- `15_verify_iommu.sh` → `18_verify_iommu.sh`
- `16_verify_xen.sh` → `19_verify_xen_rt.sh`
- `17_generate_report.sh` → Deprecated (functionality integrated into other scripts)
- New: `20_verify_irq_affinity.sh` - Comprehensive IRQ affinity verification

### Updated Documentation

All documentation has been updated to reflect the new script numbers and RT scheduler build process:

1. **README.md**
   - Updated Quick Start with RT build instructions
   - Updated script list with new numbers
   - Added Key Features section
   - Updated Status to show completed phases

2. **scripts/README.md**
   - Added "What's New" section highlighting new scripts
   - Updated all script tables with new numbers
   - Updated usage patterns for RT build workflow
   - Updated script dependencies diagram
   - Updated output locations

3. **BUILD_XEN_RTDS_GUIDE.md**
   - Updated all script references to use new numbers (10, 11, 12)
   - Updated step-by-step instructions
   - Updated timeline estimates
   - Updated troubleshooting section

4. **RTDS_CONFIGURATION_GUIDE.md**
   - Added Quick Reference section for new scripts
   - Cross-references to BUILD_XEN_RTDS_GUIDE.md

5. **docs/STEP_BY_STEP_GUIDE.md**
   - Added new PHASE 1.4: Build Xen with RTDS Scheduler
   - Renumbered subsequent phases (IRQ → 1.5, Validation → 1.6)
   - Updated all script references throughout
   - Updated success criteria

### Why This Change?

**Problem**: Ubuntu's packaged Xen hypervisor does not include the RTDS (Real-Time Deferrable Server) scheduler, which is essential for hard real-time performance.

**Solution**: Build Xen from source with RTDS enabled.

**Benefits**:
- Enables true hard real-time performance (<10μs latency)
- Provides RTDS scheduler for RT CPU pools
- Allows fine-grained control over RT VM scheduling
- Essential for Milestone 1 real-time objectives

### Migration Guide

If you previously used scripts with the old numbering:

**Old Command → New Command**
```bash
# IRQ Affinity
./scripts/10_map_irq_affinity.sh      → ./scripts/13_map_irq_affinity.sh
./scripts/11_generate_irq_script.sh   → ./scripts/14_generate_irq_script.sh
./scripts/12_create_irq_service.sh    → ./scripts/15_create_irq_service.sh
./scripts/13_install_irq_service.sh   → ./scripts/16_install_irq_service.sh

# Verification
./scripts/14_verify_isolation.sh      → ./scripts/17_verify_isolation.sh
./scripts/15_verify_iommu.sh          → ./scripts/18_verify_iommu.sh
./scripts/16_verify_xen.sh            → ./scripts/19_verify_xen_rt.sh
```

### Quick Start (New Workflow)

For new setups, the recommended workflow is:

```bash
cd ~/HyperVisor_Evaluation

# 1-9: Basic setup (unchanged)
./scripts/01_collect_system_info.sh
./scripts/02_check_virt_support.sh
# ... through script 09

# NEW: 10-12 Build Xen with RTDS
sudo ./scripts/10_install_xen_build_deps.sh
sudo ./scripts/12_build_xen_minimal.sh  # 20-40 minutes
sudo reboot

# 13-16: IRQ Affinity (renumbered)
./scripts/13_map_irq_affinity.sh
./scripts/14_generate_irq_script.sh
./scripts/15_create_irq_service.sh
sudo ./scripts/16_install_irq_service.sh

# 17-20: Verification (renumbered)
./scripts/17_verify_isolation.sh
./scripts/18_verify_iommu.sh
./scripts/19_verify_xen_rt.sh
./scripts/20_verify_irq_affinity.sh
```

### References

For detailed information, see:
- `BUILD_XEN_RTDS_GUIDE.md` - Complete RT scheduler build guide
- `RTDS_CONFIGURATION_GUIDE.md` - RT scheduler configuration
- `scripts/README.md` - Updated script reference
- `docs/STEP_BY_STEP_GUIDE.md` - Updated step-by-step guide

### Technical Details

**Xen Version**: 4.17.4  
**Build Type**: Minimal (hypervisor + essential tools)  
**Schedulers Enabled**: RTDS, Credit, Credit2, Null  
**Build Location**: `/usr/local/src/xen-rtds-build`  
**Backup Location**: `/root/xen-backup-<timestamp>`  

---

*Last Updated: October 28, 2025*

