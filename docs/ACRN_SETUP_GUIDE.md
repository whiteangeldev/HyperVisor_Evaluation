# Intel ACRN Setup Guide
## Real-Time Hypervisor POC - Milestone 1

---

## Overview

Intel ACRN (A Configurable Real-time hypervisor for IoT) is a flexible, lightweight reference hypervisor built specifically for embedded IoT and real-time applications. This guide walks through the complete setup process for Milestone 1.

### Key Features

- **Real-Time Performance**: Designed for deterministic latency
- **LAPIC Passthrough**: Direct local APIC access for lowest interrupt latency
- **Memory Pre-allocation**: Locked memory for RT VMs
- **CPU Partitioning**: Strict 1:1 vCPU to pCPU mapping
- **Virtio Polling**: Reduced I/O latency via polling instead of interrupts

---

## Prerequisites

### Hardware Requirements

- **CPU**: Intel processor with VT-x and VT-d support
- **Cores**: 4+ CPU cores (8+ recommended)
  - Service OS: 2 cores
  - RT VM: 2-4 cores
  - GPOS VM: 2-4 cores
- **Memory**: 8GB+ (16GB recommended)
- **Storage**: 20GB+ free space

### Software Requirements

- **OS**: Ubuntu 22.04 LTS or Ubuntu 24.04 LTS
- **Kernel**: 5.4+ (5.15+ recommended)
- **Build Tools**: gcc, make, git, python3

---

## Architecture

### ACRN VM Types

1. **Service OS (SOS)**
   - Management VM that runs on ACRN
   - Has access to all hardware
   - Manages User OS VMs
   - Runs on housekeeping CPUs (0-1)

2. **Real-Time User OS (RT UOS)**
   - Hard real-time VM
   - Dedicated isolated CPUs
   - LAPIC passthrough
   - Pre-allocated locked memory
   - Device passthrough via VFIO

3. **General Purpose User OS (GPOS UOS)**
   - Standard VM for non-RT workloads
   - Can run Windows or Linux
   - Used for stress testing

### CPU Allocation Strategy (8-core system)

```
CPU 0-1:  Service OS (SOS) - Housekeeping
CPU 2-3:  RT User OS - Real-time workload
CPU 4-7:  GPOS User OS - General purpose / stress
```

---

## Setup Process

### Phase 1: Pre-Installation Checks

```bash
cd ~/rt-hypervisor-poc

# Run pre-installation check
./scripts/18_pre_acrn_check.sh
```

This script verifies:
- Intel CPU with VT-x
- IOMMU/VT-d support
- Sufficient CPUs and memory
- Required build dependencies
- Disk space

**Review the output carefully** - address any failures before proceeding.

---

### Phase 2: System Configuration (If Not Done)

If you haven't configured GRUB for IOMMU and CPU isolation:

```bash
# Backup current configuration
./scripts/03_backup_current_config.sh

# Generate GRUB configuration
./scripts/04_generate_grub_config.sh

# Apply GRUB configuration (requires root)
sudo ./scripts/05_update_grub.sh

# Reboot to apply kernel parameters
sudo reboot
```

After reboot, verify parameters:
```bash
cat /proc/cmdline
```

You should see:
- `intel_iommu=on`
- `isolcpus=2-7` (or similar)
- `nohz_full=2-7`
- `rcu_nocbs=2-7`

---

### Phase 3: Install Build Dependencies

```bash
# Install all required packages (requires root)
sudo ./scripts/19_install_acrn_deps.sh
```

This installs:
- Build tools: gcc, make, binutils
- Libraries: libssl-dev, libpciaccess-dev, uuid-dev
- Python dependencies: lxml, xmlschema
- QEMU and virtualization tools

**Time estimate**: 5-10 minutes (depending on internet speed)

---

### Phase 4: Download ACRN Source

```bash
# Download ACRN v3.2 (stable release)
./scripts/20_download_acrn.sh
```

This clones the ACRN repository to `~/rt-hypervisor-poc/acrn-hypervisor/`

**Time estimate**: 2-5 minutes

---

### Phase 5: Build ACRN

```bash
# Build hypervisor, device model, and tools
./scripts/21_build_acrn.sh
```

This compiles:
- ACRN hypervisor (acrn.bin)
- Device model (acrn-dm)
- Management tools (acrnctl, acrnlog)

**Time estimate**: 15-30 minutes (depending on CPU)

**Build Configuration**:
- Board: generic
- Scenario: industry (optimized for real-time)
- Parallel jobs: automatically detected

---

### Phase 6: Install ACRN

```bash
# Install ACRN to system (requires root)
sudo ./scripts/22_install_acrn.sh
```

This script:
1. Installs hypervisor binary to `/boot/acrn.bin`
2. Installs tools to `/usr/bin/` (acrn-dm, acrnctl, etc.)
3. Creates ACRN directories
4. Generates GRUB entry for ACRN boot

**⚠️ IMPORTANT**: Review GRUB entry before rebooting!

```bash
# Review ACRN GRUB entry
sudo cat /etc/grub.d/40_custom_acrn

# Edit if needed
sudo nano /etc/grub.d/40_custom_acrn
```

Ensure the entry has correct:
- Root UUID
- Kernel path (`/boot/vmlinuz`)
- Initrd path (`/boot/initrd.img`)

---

### Phase 7: Configure ACRN for RT

```bash
# Generate ACRN RT configuration
./scripts/23_configure_acrn.sh
```

This creates `configs/acrn_rt.conf` with:
- CPU allocation for SOS, RT UOS, GPOS UOS
- RT optimization parameters
- Device passthrough examples
- Launch script templates

**Review the configuration file**:
```bash
cat configs/acrn_rt.conf
```

---

### Phase 8: Reboot into ACRN

```bash
# Update GRUB and reboot
sudo update-grub
sudo reboot
```

**At GRUB menu**:
1. Select "ACRN Hypervisor" entry
2. System will boot into ACRN with Service OS

**Expected boot messages**:
- "ACRN Hypervisor" banner
- Service OS kernel loading
- ACRN device initialization

---

### Phase 9: Verify ACRN

After booting into ACRN:

```bash
# Verify ACRN is running
./scripts/24_verify_acrn.sh
```

Check for:
- ✓ ACRN device nodes: `/dev/acrn_hsm` or `/dev/acrn_vhm`
- ✓ ACRN kernel modules loaded
- ✓ Tools available: `acrn-dm`, `acrnctl`

**Manual verification**:
```bash
# Check ACRN devices
ls -la /dev/acrn*

# Check loaded modules
lsmod | grep acrn

# View hypervisor log
acrnlog -t

# List VMs (none yet)
acrnctl list
```

---

## Launching RT User OS VM

### VM Image Preparation

You'll need a VM image with RT kernel (covered in Milestone 2). For now, here's the launch syntax:

```bash
# Example RT VM launch script
acrn-dm \
  -m 2048M \
  --lapic_pt \
  --rtvm \
  --virtio_poll 1000000 \
  --cpu_affinity 2,3 \
  -s 3,virtio-blk,/path/to/rt-disk.img \
  -s 4,virtio-net,tap0 \
  -s 5,passthru,02/00/0 \
  --ovmf /usr/share/acrn/bios/OVMF.fd \
  rt_vm
```

### Key Parameters

| Parameter | Purpose |
|-----------|---------|
| `-m 2048M` | Memory allocation |
| `--lapic_pt` | LAPIC passthrough (lowest latency) |
| `--rtvm` | Enable RT optimizations |
| `--virtio_poll` | Polling interval (nanoseconds) |
| `--cpu_affinity` | Pin to specific CPUs |
| `-s passthru` | PCI device passthrough |

---

## Troubleshooting

### ACRN Not Booting

**Symptom**: System hangs at boot or falls back to non-ACRN kernel

**Solutions**:
1. Check GRUB entry syntax:
   ```bash
   sudo cat /etc/grub.d/40_custom_acrn
   ```

2. Verify hypervisor binary exists:
   ```bash
   ls -lh /boot/acrn.bin
   ```

3. Check kernel messages:
   ```bash
   dmesg | grep -i acrn
   ```

4. Boot into non-ACRN kernel from GRUB and review logs:
   ```bash
   journalctl -b -1 | grep -i acrn
   ```

### Device Nodes Not Created

**Symptom**: `/dev/acrn_hsm` doesn't exist

**Solutions**:
1. Check if ACRN module is loaded:
   ```bash
   lsmod | grep acrn
   ```

2. Try loading manually:
   ```bash
   sudo modprobe acrn
   ```

3. Check dmesg for errors:
   ```bash
   dmesg | tail -50
   ```

### Build Failures

**Symptom**: ACRN build fails with errors

**Solutions**:
1. Ensure all dependencies installed:
   ```bash
   sudo ./scripts/19_install_acrn_deps.sh
   ```

2. Clean and rebuild:
   ```bash
   cd ~/rt-hypervisor-poc/acrn-hypervisor
   make clean
   cd ~/rt-hypervisor-poc
   ./scripts/21_build_acrn.sh
   ```

3. Check specific error messages in `logs/acrn_build.log`

### VM Launch Fails

**Symptom**: `acrn-dm` command fails to start VM

**Solutions**:
1. Check ACRN is running:
   ```bash
   ls /dev/acrn*
   ```

2. Verify CPU affinity values match isolated CPUs:
   ```bash
   cat /sys/devices/system/cpu/isolated
   ```

3. Check VM image path is correct

4. Review acrn-dm error output

---

## Performance Optimization

### BIOS Settings

Enable:
- VT-x (Intel Virtualization Technology)
- VT-d (Intel VT for Directed I/O)
- SR-IOV (if available)

Disable:
- Hyperthreading (or manage carefully)
- C-states (or limit to C1)
- P-states (fix frequency)
- Turbo Boost (for determinism)

### Service OS Tuning

Add to Service OS kernel parameters:
```
isolcpus=2-7 nohz_full=2-7 rcu_nocbs=2-7 idle=poll
```

### Cache Allocation Technology (CAT)

If your CPU supports Intel RDT (Resource Director Technology):

```bash
# Check CAT support
cat /proc/cpuinfo | grep -i "cat\|rdt"

# Enable CAT for RT VM (requires kernel support)
# Configure via sysfs or libvirt
```

---

## Comparison: ACRN vs Xen

| Feature | ACRN | Xen |
|---------|------|-----|
| **Type** | Type-1 (bare metal) | Type-1 (bare metal) |
| **Design Focus** | IoT, embedded, RT | General purpose, cloud |
| **Footprint** | Small (~50MB) | Larger (~200MB+) |
| **RT Scheduler** | Native RT design | RTDS scheduler |
| **LAPIC Passthrough** | Yes, optimized | Limited |
| **Memory Overhead** | Low | Medium |
| **Complexity** | Moderate | Higher |
| **Windows Support** | Limited | Full |
| **Linux Support** | Full | Full |
| **Community** | Growing (Intel-backed) | Mature (Linux Foundation) |

### When to Use ACRN

- IoT and embedded systems
- Hard real-time requirements (< 10μs jitter)
- Resource-constrained environments
- Safety-critical applications (automotive, industrial)

### When to Use Xen

- Cloud and datacenter deployments
- Mixed Windows/Linux workloads
- Mature tooling required
- Soft real-time requirements

---

## Next Steps

After completing ACRN setup:

1. **Verify Installation**
   ```bash
   ./scripts/24_verify_acrn.sh
   ./scripts/14_verify_isolation.sh
   ./scripts/15_verify_iommu.sh
   ```

2. **Generate Final Report**
   ```bash
   ./scripts/27_final_report.sh
   ```

3. **Proceed to Milestone 2**
   - Create RT VM with PREEMPT_RT kernel
   - Create GPOS VM for stress testing
   - Configure VFIO device passthrough
   - Run performance benchmarks (cyclictest)

---

## References

### Official Documentation

- [ACRN Project](https://projectacrn.org/)
- [ACRN Documentation](https://projectacrn.github.io/latest/)
- [ACRN GitHub](https://github.com/projectacrn/acrn-hypervisor)

### Intel Resources

- [Intel VT-x and VT-d](https://www.intel.com/content/www/us/en/virtualization/virtualization-technology/intel-virtualization-technology.html)
- [Intel RDT](https://www.intel.com/content/www/us/en/architecture-and-technology/resource-director-technology.html)

### Real-Time Linux

- [PREEMPT_RT Patch](https://wiki.linuxfoundation.org/realtime/start)
- [Real-Time Testing (cyclictest)](https://wiki.linuxfoundation.org/realtime/documentation/howto/tools/cyclictest)

---

*Last Updated: 2025-10-17*

