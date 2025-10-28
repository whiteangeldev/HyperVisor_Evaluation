# Real-Time Hypervisor Installation Scripts

**Two Paths Available**: Xen RT | Intel ACRN

---

## 📁 Folder Structure

```
scripts/
├── Xen/                # Xen RT scripts (01-20)
├── Intel ACRN/         # ACRN scripts (21-27)
└── README.md           # This file
```

---

## ⚡ Quick Start

### Path 1: Xen RT (Recommended for Hard Real-Time)

```bash
cd ~/HyperVisor_Evaluation/scripts/Xen

# System setup & GRUB (01-05)
./01_collect_system_info.sh
./02_check_virt_support.sh
./03_backup_current_config.sh
./04_generate_grub_config.sh
sudo ./05_update_grub.sh
sudo reboot

# Install Xen (06-09)
./06_pre_xen_check.sh
sudo ./07_install_xen.sh
./08_configure_xen_rt.sh
sudo ./09_apply_xen_config.sh
sudo reboot

# Build with RTDS (10-12) ⭐ Critical for <10μs latency
sudo ./10_install_xen_build_deps.sh
sudo ./12_build_xen_minimal.sh    # 20-40 min
sudo reboot

# IRQ affinity (13-16)
./13_map_irq_affinity.sh
./14_generate_irq_script.sh
./15_create_irq_service.sh
sudo ./16_install_irq_service.sh

# Verify (17-20)
./17_verify_isolation.sh
./18_verify_iommu.sh
./19_verify_xen_rt.sh
./20_verify_irq_affinity.sh
```

**Time**: 60-90 minutes  
**Result**: Xen 4.17.4 with RTDS scheduler, <10μs RT latency

---

### Path 2: Intel ACRN (IoT/Embedded Optimized)

```bash
cd ~/HyperVisor_Evaluation/scripts
cd "Intel ACRN"

# Prerequisites (21)
./21_pre_acrn_check.sh

# Dependencies (22)
sudo ./22_install_acrn_deps.sh

# Download & Build (23-24)
./23_download_acrn.sh
./24_build_acrn.sh              # 15-30 min

# Install & Configure (25-26)
sudo ./25_install_acrn.sh
./26_configure_acrn.sh
sudo update-grub
sudo reboot

# Verify (27)
./27_verify_acrn.sh
```

**Time**: 45-75 minutes  
**Result**: ACRN hypervisor ready for Service OS and RT VMs

---

## 📊 Comparison

| Feature | Xen RT | Intel ACRN |
|---------|--------|------------|
| **Scripts** | 01-20 (Xen/) | 21-27 (Intel ACRN/) |
| **RT Latency** | <10μs | <50μs |
| **Build Time** | 20-40 min | 15-30 min |
| **Total Time** | 60-90 min | 45-75 min |
| **Complexity** | Moderate | Higher |
| **Use Case** | General RT | IoT/Edge/Automotive |
| **Maturity** | Production | Embedded-focused |

---

## 🎯 Xen RT Scripts (01-20)

### System Setup (01-05)
| # | Script | Purpose | Sudo | Reboot |
|---|--------|---------|------|--------|
| 01 | collect_system_info.sh | Inventory CPU, memory, devices | No | No |
| 02 | check_virt_support.sh | Verify VT-x/VT-d | No | No |
| 03 | backup_current_config.sh | Backup GRUB & configs | No | No |
| 04 | generate_grub_config.sh | Create IOMMU/isolation params | No | No |
| 05 | update_grub.sh | Apply GRUB config | **Yes** | **Yes** |

### Xen Installation (06-09)
| # | Script | Purpose | Sudo | Reboot |
|---|--------|---------|------|--------|
| 06 | pre_xen_check.sh | Verify IOMMU enabled | No | No |
| 07 | install_xen.sh | Install Xen packages | **Yes** | No |
| 08 | configure_xen_rt.sh | Generate RT config | No | No |
| 09 | apply_xen_config.sh | Apply Xen config | **Yes** | **Yes** |

### RT Scheduler Build (10-12) ⭐
| # | Script | Purpose | Sudo | Reboot |
|---|--------|---------|------|--------|
| 10 | install_xen_build_deps.sh | Install build dependencies | **Yes** | No |
| 11 | cleanup_failed_build.sh | Clean failed build | **Yes** | No |
| 12 | build_xen_minimal.sh | Build Xen with RTDS | **Yes** | **Yes** |

**Why?** Ubuntu's Xen lacks RTDS scheduler. Building from source enables <10μs latency.

### IRQ Affinity (13-16)
| # | Script | Purpose | Sudo | Reboot |
|---|--------|---------|------|--------|
| 13 | map_irq_affinity.sh | Document IRQ distribution | No | No |
| 14 | generate_irq_script.sh | Create IRQ pinning script | No | No |
| 15 | create_irq_service.sh | Create systemd service | No | No |
| 16 | install_irq_service.sh | Install IRQ service | **Yes** | No |

### Verification (17-20)
| # | Script | Purpose | Sudo | Reboot |
|---|--------|---------|------|--------|
| 17 | verify_isolation.sh | Check CPU isolation | No | No |
| 18 | verify_iommu.sh | List IOMMU groups | No | No |
| 19 | verify_xen_rt.sh | Check RTDS scheduler | No | No |
| 20 | verify_irq_affinity.sh | Verify IRQ pinning | No | No |

---

## 🎯 Intel ACRN Scripts (21-27)

| # | Script | Purpose | Sudo | Reboot |
|---|--------|---------|------|--------|
| 21 | pre_acrn_check.sh | Check prerequisites | No | No |
| 22 | install_acrn_deps.sh | Install build tools | **Yes** | No |
| 23 | download_acrn.sh | Download ACRN source | No | No |
| 24 | build_acrn.sh | Build ACRN (15-30 min) | No | No |
| 25 | install_acrn.sh | Install to system | **Yes** | **Yes** |
| 26 | configure_acrn.sh | Configure for RT | No | No |
| 27 | verify_acrn.sh | Verify installation | No | No |

---

## 🔧 Key Differences

### When to Use Xen RT
- Need hard real-time (<10μs)
- General-purpose RT workloads
- RTDS scheduler required
- Production environments
- Well-documented use cases

### When to Use ACRN
- Embedded/IoT applications
- Edge computing
- Automotive systems
- Simpler RT requirements (<50μs)
- Intel-optimized platforms

---

## 💡 Pro Tips

### Xen RT Path
1. **Must build from source** (scripts 10-12) for RTDS
2. Verify RTDS: `sudo xl cpupool-create name="test" sched="rtds"`
3. If build fails: `sudo ./11_cleanup_failed_build.sh` then retry
4. Expected version: `sudo xl info | grep xen_version` → 4.17.4

### ACRN Path
1. Ensure kernel headers match: `uname -r`
2. Service OS runs on housekeeping CPUs
3. RT VMs get dedicated CPUs
4. Check status: `sudo journalctl -u acrn`

---

## 📝 Output Locations

### Logs
`../logs/` directory contains:
- `system_info.log` - System inventory
- `virt_support.log` - VT-x/VT-d status
- `xen_install.log` - Xen installation
- `xen_build.log` - Build from source
- `cpu_isolation.log` - Isolation verification
- `iommu_groups.log` - IOMMU enumeration
- `xen_rt_verification.log` - RT scheduler
- `irq_affinity_verification.log` - IRQ config

### Configs
`../configs/` directory contains:
- `grub_cmdline.txt` - GRUB parameters
- `xen_rt.cfg` - Xen RT config
- `irq-affinity.service` - IRQ service
- `backup/` - Original configs

---

## 🚨 Troubleshooting

### Xen Build Fails
```bash
cd ~/HyperVisor_Evaluation/scripts/Xen
sudo ./11_cleanup_failed_build.sh
sudo ./10_install_xen_build_deps.sh
sudo ./12_build_xen_minimal.sh
```

### ACRN Build Fails
```bash
# Check kernel headers
uname -r
sudo apt-get install linux-headers-$(uname -r)

# Retry build
cd ~/HyperVisor_Evaluation/scripts
cd "Intel ACRN"
./24_build_acrn.sh
```

### System Won't Boot
1. At GRUB, press 'e'
2. Remove kernel parameters
3. Press Ctrl+X to boot
4. Restore: `sudo cp ../configs/backup/grub /etc/default/grub`
5. Run: `sudo update-grub`

---

## 📚 Documentation

- **Main Guide**: `../README.md`
- **Xen RT Build**: `../BUILD_XEN_RTDS_GUIDE.md`
- **RTDS Config**: `../RTDS_CONFIGURATION_GUIDE.md`
- **ACRN Setup**: `../docs/ACRN_SETUP_GUIDE.md`
- **Delivery Doc**: `/home/ubuntu/DELIVERY_INSTALL_GUIDE.md`

---

## ✅ Success Checklist

### Xen RT (Scripts 01-20)
- [ ] System boots into Xen 4.17.4
- [ ] RTDS available: `xl cpupool-create sched=rtds` works
- [ ] CPUs 4-7 isolated: `/sys/devices/system/cpu/isolated`
- [ ] IOMMU enabled: `/sys/kernel/iommu_groups/` exists
- [ ] IRQs pinned to CPUs 0-3
- [ ] All verification scripts pass

### ACRN (Scripts 21-27)
- [ ] System boots into ACRN
- [ ] Service OS running
- [ ] ACRN devices manager loaded
- [ ] CPU partitioning configured
- [ ] IOMMU enabled
- [ ] Verification script passes

---

## 🎓 Script Execution Patterns

### Pattern 1: First-Time Setup (Xen RT)
```bash
cd Xen
for i in $(seq -f "%02g" 1 5); do ./${i}_*.sh; done
sudo ./05_update_grub.sh && sudo reboot

# After reboot
for i in $(seq -f "%02g" 6 9); do ./${i}_*.sh; done
sudo ./09_apply_xen_config.sh && sudo reboot

# After reboot
sudo ./10_install_xen_build_deps.sh
sudo ./12_build_xen_minimal.sh && sudo reboot

# Final setup
for i in $(seq -f "%02g" 13 16); do ./${i}_*.sh; done
for i in $(seq -f "%02g" 17 20); do ./${i}_*.sh; done
```

### Pattern 2: First-Time Setup (ACRN)
```bash
cd "Intel ACRN"
./21_pre_acrn_check.sh
sudo ./22_install_acrn_deps.sh
./23_download_acrn.sh
./24_build_acrn.sh
sudo ./25_install_acrn.sh
./26_configure_acrn.sh
sudo update-grub && sudo reboot

# After reboot
./27_verify_acrn.sh
```

### Pattern 3: Verification Only
```bash
# Xen
cd Xen && ./17_verify_isolation.sh && ./18_verify_iommu.sh && ./19_verify_xen_rt.sh && ./20_verify_irq_affinity.sh

# ACRN
cd "Intel ACRN" && ./27_verify_acrn.sh
```

---

**Version**: 2.0  
**Last Updated**: October 28, 2025  
**Status**: Production Ready

**Choose Your Path**:
- **Xen RT**: `cd Xen/` → Hard real-time, <10μs latency
- **ACRN**: `cd "Intel ACRN"/` → Embedded/IoT optimized
