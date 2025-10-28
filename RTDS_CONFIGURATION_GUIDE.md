# RTDS Scheduler Configuration Guide

## Problem Analysis

Your system shows:
```
xen_scheduler          : credit2
xen_commandline        : placeholder sched=rtds dom0_max_vcpus=1...
```

**Issue**: The "placeholder" text is preventing `sched=rtds` from being parsed, AND Ubuntu's Xen package may not include RTDS support.

---

## Solution Options (Choose One)

### ✅ Option 1: Use CPU Pools (RECOMMENDED)

**Best if**: RTDS is compiled but boot parameter doesn't work

**Advantages**:
- Works even if boot parameter fails
- More flexible (Dom0 stays on Credit2, RT VMs get RTDS)
- No reboot needed
- Production-ready approach

**Steps**:
```bash
cd /home/ubuntu/HyperVisor_Evaluation

# First, check if RTDS is available
sudo ./scripts/09i_check_rtds_support.sh

# If RTDS is available, set up cpupools
sudo ./scripts/10_setup_rtds_cpupool.sh
```

**What this does**:
1. Creates separate CPU pool with RTDS scheduler
2. Moves RT CPUs (4-7) to RTDS pool
3. Leaves Dom0 on Credit2 scheduler
4. Provides commands to launch VMs in RTDS pool

**Expected Result**:
```
Pool-0:
  Scheduler: credit2
  CPUs: 0,1,2,3 (Dom0)

rtds-pool:
  Scheduler: rtds
  CPUs: 4,5,6,7 (RT VMs)
```

---

### ⚡ Option 2: Credit2 with RT Tuning (EASIEST)

**Best if**: You don't need hard real-time (<10μs latency)

**Advantages**:
- Works with any Xen installation
- No recompilation needed
- Good enough for most RT workloads (50-100μs latency)
- Simpler configuration

**Steps**:
```bash
cd /home/ubuntu/HyperVisor_Evaluation
sudo ./scripts/31_credit2_rt_tuning.sh
```

**What this does**:
1. Tunes Credit2 scheduler for low latency
2. Creates RT VM configuration templates
3. Provides tuning scripts for VMs
4. Sets up monitoring tools

**Suitable for**:
- Industrial automation ✓
- Audio/video processing ✓
- Network packet processing ✓
- Gaming ✓
- Most embedded systems ✓

**NOT suitable for**:
- Safety-critical systems (DO-178C, IEC 61508)
- Hard RT with <10μs guarantees
- RT certification requirements

---

### 🔧 Option 3: Build Xen from Source with RTDS (ADVANCED)

**Best if**: You need RTDS and it's not available in Ubuntu's package

**Advantages**:
- Full RTDS support guaranteed
- Latest Xen features
- Complete control over configuration

**Disadvantages**:
- Takes 30-60 minutes
- Requires ~5GB disk space
- More complex
- Manual updates needed

**Steps**:
```bash
cd /home/ubuntu/HyperVisor_Evaluation

# Check disk space (need ~5GB)
df -h

# Run build script
sudo ./scripts/30_build_xen_with_rtds.sh

# After reboot, set up RTDS
sudo ./scripts/10_setup_rtds_cpupool.sh
```

**What this does**:
1. Downloads Xen 4.17.4 source code
2. Configures with RTDS enabled
3. Compiles Xen hypervisor
4. Installs and updates GRUB
5. Backs up old installation

---

### 🔨 Option 4: Fix GRUB "placeholder" Bug (QUICK FIX)

**Best if**: RTDS is available but boot parameter is broken

**Steps**:
```bash
cd /home/ubuntu/HyperVisor_Evaluation

# Remove "placeholder" from GRUB
sudo ./scripts/09h_fix_xen_scheduler.sh

# Reboot
sudo reboot

# After reboot, verify
sudo xl info | grep xen_scheduler
# Should show: xen_scheduler : rtds
```

---

## Decision Tree

```
START: Do you have RTDS support?
  │
  ├─ Don't know → Run: sudo ./scripts/09i_check_rtds_support.sh
  │
  ├─ YES, RTDS available
  │   │
  │   ├─ Boot param broken? → Option 4 (Fix GRUB) then Option 1 (cpupools)
  │   │
  │   └─ Boot param works? → Option 1 (cpupools) - still better!
  │
  └─ NO, RTDS not available
      │
      ├─ Need hard RT (<10μs)? → Option 3 (Build from source)
      │
      └─ Soft RT OK (50-100μs)? → Option 2 (Credit2 tuning) ✓ EASIEST
```

---

## Quick Reference: New RT Scheduler Scripts

The HyperVisor_Evaluation folder now includes scripts 10, 11, and 12 for building Xen with RTDS (RT scheduler) support:

- **Script 10**: `install_xen_build_deps.sh` - Install all Xen build dependencies
- **Script 11**: `cleanup_failed_build.sh` - Clean up failed build attempts
- **Script 12**: `build_xen_minimal.sh` - Build Xen from source with RTDS (20-40 min)

See `BUILD_XEN_RTDS_GUIDE.md` for detailed instructions.

---

## Quick Start Guide

### 1. Diagnose Your System

```bash
cd /home/ubuntu/HyperVisor_Evaluation
sudo ./scripts/09i_check_rtds_support.sh
```

This will tell you:
- ✓ If RTDS is available
- ✓ If boot parameter is working
- ✓ What your options are

### 2. Choose Based on Output

**If script says**: "✓ RTDS is compiled and available!"
→ **Run**: `sudo ./scripts/10_setup_rtds_cpupool.sh`

**If script says**: "❌ RTDS NOT AVAILABLE"
→ **Choose**:
  - Option 2 (Credit2) - Quick and easy
  - Option 3 (Build) - If you need true RTDS

### 3. Verify

For **RTDS cpupool**:
```bash
sudo xl cpupool-list
# Should show rtds-pool with RTDS scheduler
```

For **Credit2**:
```bash
sudo xl sched-credit2 -s
# Should show tuned parameters
```

---

## Performance Comparison

| Method | Latency | Jitter | Setup Time | Complexity | Certification |
|--------|---------|--------|------------|------------|---------------|
| RTDS (cpupool) | <10μs | <1μs | 5 min | Medium | Yes |
| Credit2 (tuned) | 50-100μs | 5-10μs | 5 min | Low | No |
| RTDS (boot) | <10μs | <1μs | 5 min + reboot | Medium | Yes |
| Custom build | <10μs | <1μs | 60 min | High | Yes |

---

## Using RTDS After Setup

### Create VM in RTDS Pool

Edit your VM config:
```bash
name = "my-rt-vm"
pool = "rtds-pool"  # ← Add this line
vcpus = 2
cpus = "4,5"  # Pin to specific RTDS CPUs
memory = 2048
# ... rest of config
```

### Configure RTDS Parameters

```bash
# Get domain ID
DOMID=$(xl domid my-rt-vm)

# Set RTDS scheduling: 10ms period, 8ms budget (80% CPU)
xl sched-rtds -d $DOMID -v 0 -p 10000 -b 8000
xl sched-rtds -d $DOMID -v 1 -p 10000 -b 8000

# Verify
xl sched-rtds -d $DOMID
```

### Monitor RT Performance

```bash
# Check scheduler
xl cpupool-list

# Monitor VM
xl top

# Check CPU pinning
xl vcpu-pin my-rt-vm

# View detailed info
xl list -l my-rt-vm
```

---

## Troubleshooting

### Problem: "xl cpupool-create" fails with "unknown scheduler rtds"

**Cause**: RTDS not compiled into Xen

**Solution**: Use Option 2 (Credit2) or Option 3 (Build from source)

### Problem: "placeholder" still in xen_commandline

**Cause**: GRUB/Xen integration bug

**Solution**: Run Option 4 (Fix GRUB script)

### Problem: High latency even with RTDS

**Check**:
1. CPU isolation in kernel: `cat /proc/cmdline | grep isolcpus`
2. IRQ affinity: `./scripts/14_verify_isolation.sh`
3. CPU pinning: `xl vcpu-pin <vm>`
4. RTDS parameters: `xl sched-rtds -d <vm>`

---

## Recommended Approach

For most users:

**Step 1**: Try Option 1 (cpupools) - it's the best approach
```bash
sudo ./scripts/10_setup_rtds_cpupool.sh
```

**Step 2**: If that fails (RTDS not available), use Option 2 (Credit2)
```bash
sudo ./scripts/31_credit2_rt_tuning.sh
```

**Step 3**: Only if you absolutely need hard RT and RTDS isn't available:
```bash
sudo ./scripts/30_build_xen_with_rtds.sh
```

---

## Summary

The **"placeholder"** bug is preventing your boot parameter from working, but **CPU pools are actually better**:

✅ **CPU Pools (Option 1)**:
- Dom0 runs on Credit2 (better for management)
- RT VMs run on RTDS (hard real-time)
- No reboot needed
- More flexible

✅ **Credit2 Tuning (Option 2)**:
- Works on any Xen installation
- Good enough for 95% of RT workloads
- Simplest setup
- No compilation needed

Choose based on your latency requirements:
- Need <10μs? → RTDS (Option 1 or 3)
- Need <100μs? → Credit2 (Option 2)
- Not sure? → Start with Credit2, upgrade if needed

---

## Next Steps

Run the diagnostic script to see what's available on your system:

```bash
cd /home/ubuntu/HyperVisor_Evaluation
sudo ./scripts/09i_check_rtds_support.sh
```

Then follow the recommendations it provides.

