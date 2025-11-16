# MadCatz MOJO Incremental Kernel Upgrade Plan

## Overview

This document outlines the incremental upgrade path from kernel 3.4.57 to 4.9, broken into manageable steps.

## Upgrade Path

### Step 1: Kernel 3.4.57 → 3.10 (Android 8.0)
- **Target**: android-tegra-3.10 branch
- **Android Support**: Android 8.0 Oreo
- **Difficulty**: Low-Medium (similar APIs)
- **Timeline**: 1-2 weeks

### Step 2: Kernel 3.10 → 3.18 (Android 8.1)
- **Target**: android-tegra-3.18 branch
- **Android Support**: Android 8.1 Oreo
- **Difficulty**: Medium (device tree becomes mandatory)
- **Timeline**: 2-3 weeks

### Step 3: Kernel 3.18 → 4.4 (Android 9.0)
- **Target**: Mainline 4.4 LTS or android-4.4
- **Android Support**: Android 9.0 Pie (LineageOS 16)
- **Difficulty**: Medium-Hard (major driver updates)
- **Timeline**: 2-3 weeks

### Step 4: Kernel 4.4 → 4.9 (Android 10/11)
- **Target**: android-4.9-q branch or mainline 4.9 LTS
- **Android Support**: Android 10/11 (LineageOS 17/18)
- **Difficulty**: Medium (mostly driver refinements)
- **Timeline**: 1-2 weeks

**Total Estimated Time**: 6-10 weeks

---

## Step 1 Details: 3.4.57 → 3.10

### Source Repository
```bash
git clone --depth=1 --branch android-tegra-3.10 \
    https://android.googlesource.com/kernel/tegra tegra-3.10
```

### Major Changes from 3.4 to 3.10

1. **Device Tree Support** (optional in 3.10)
   - Can still use board files (existing code)
   - OR start migrating to device tree
   - Recommendation: Keep board files for now

2. **Driver Updates**
   - Minimal changes to Tegra drivers
   - Some new APIs but backwards compatible
   - Most 3.4 drivers will work with minor tweaks

3. **Android Features**
   - Same Android stack (Binder, Ashmem, etc.)
   - ION memory allocator improvements
   - Better low memory killer

4. **Build System**
   - Minor Kconfig changes
   - Same defconfig structure

### Configuration Changes Needed

```diff
# Update version string
-CONFIG_LOCALVERSION="-android7"
+CONFIG_LOCALVERSION="-android8"

# New options in 3.10
+CONFIG_CROSS_MEMORY_ATTACH=y
+CONFIG_FHANDLE=y

# Scheduler improvements
+CONFIG_SCHED_AUTOGROUP=y

# Optional: Enable DT support for future
+CONFIG_USE_OF=y
+CONFIG_PROC_DEVICETREE=y
```

### Files to Update

1. **Makefile** - Update VERSION and PATCHLEVEL
2. **arch/arm/configs/lineageos_mojo_defconfig** - Minor config updates
3. **arch/arm/mach-tegra/** - Minimal board file changes
4. **drivers/** - Driver API updates (if any)

### Testing Checklist

- [ ] Kernel boots
- [ ] Basic hardware works (display, USB, storage)
- [ ] WiFi/Bluetooth functional
- [ ] Audio works
- [ ] All sensors detected
- [ ] Android boots to home screen
- [ ] Apps run normally

---

## Step 2 Details: 3.10 → 3.18

### Major Changes

1. **Device Tree Mandatory** for multi-platform
   - Must convert board files to DT
   - Can use tegra114-mojo.dts as starting point

2. **Pinctrl Subsystem**
   - Replace tegra_pinmux with pinctrl
   - Already in DT we created

3. **Common Clock Framework**
   - Update clock consumers
   - Mostly transparent for platform code

4. **Driver Updates**
   - More significant than 3.4→3.10
   - GPIO framework changes
   - Regulator framework updates

### Configuration Changes

```diff
# Device tree now mandatory
CONFIG_USE_OF=y
+CONFIG_ARCH_MULTIPLATFORM=y

# Pinctrl subsystem
+CONFIG_PINCTRL=y
+CONFIG_PINCTRL_TEGRA=y

# Updated drivers
+CONFIG_TEGRA_IOMMU_SMMU=y

# Android updates for 8.1
+CONFIG_ANDROID_BINDER_IPC_32BIT=y
```

---

## Step 3 Details: 3.18 → 4.4

### Major Changes

1. **DRM/KMS for Display**
   - Replace Tegra DC with DRM driver
   - Major display subsystem rewrite

2. **ASoC for Audio**
   - Update audio to ASoC component framework
   - Significant audio driver changes

3. **GPIO Descriptors**
   - Mandatory switch from GPIO numbers to descriptors
   - All GPIO users must be updated

4. **Regulator Framework v2**
   - Update regulator consumers
   - Device managed (devm_) functions

5. **Android Features**
   - Enhanced Binder IPC
   - eBPF support (optional but recommended)
   - Better cgroup support

### Configuration Changes

```diff
# Android 9 requirements
+CONFIG_ANDROID_BINDER_IPC_32BIT=n
+CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"

# eBPF support
+CONFIG_BPF=y
+CONFIG_BPF_SYSCALL=y
+CONFIG_CGROUP_BPF=y

# DRM display
+CONFIG_DRM=y
+CONFIG_DRM_TEGRA=y

# Enhanced security
+CONFIG_HARDENED_USERCOPY=y
```

---

## Step 4 Details: 4.4 → 4.9

### Major Changes

1. **BinderFS**
   - New binderfs filesystem
   - Replaces static /dev/binder nodes

2. **Scheduler Updates**
   - Energy Aware Scheduling (EAS)
   - schedutil governor

3. **Memory Management**
   - Per-process reclaim improvements
   - Better ZRAM support

4. **Security Enhancements**
   - SELinux improvements
   - Better namespacing

### Configuration Changes

```diff
# BinderFS
+CONFIG_ANDROID_BINDERFS=y

# Scheduler
+CONFIG_ENERGY_MODEL=y
+CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y

# Android 10/11 features
+CONFIG_PSI=y
+CONFIG_MEMCG_SWAP=y
```

---

## Migration Strategy

### Phase 1: Current State (Week 0)
- ✅ Kernel 3.4.57
- ✅ Android 7 support
- ✅ All hardware working

### Phase 2: Upgrade to 3.10 (Weeks 1-2)
- Download 3.10 kernel
- Port configuration
- Test all hardware
- Commit working 3.10 kernel

### Phase 3: Upgrade to 3.18 (Weeks 3-5)
- Download 3.18 kernel
- Integrate device tree (already created)
- Update drivers for DT
- Test and debug
- Commit working 3.18 kernel

### Phase 4: Upgrade to 4.4 (Weeks 6-8)
- Download 4.4 kernel
- Major driver updates (DRM, ASoC, GPIO)
- Extensive testing
- Commit working 4.4 kernel

### Phase 5: Upgrade to 4.9 (Weeks 9-10)
- Download 4.9 kernel
- Final driver refinements
- Android 10/11 testing
- Final commit and release

---

## Benefits of Incremental Approach

1. **Smaller Changes** - Easier to identify and fix issues
2. **Regular Testing** - Working kernel at each step
3. **Learning Curve** - Gradual learning of new APIs
4. **Fallback Points** - Can revert to previous stable version
5. **Documentation** - Better understanding of each change
6. **Confidence** - Build experience with each step

---

## Risks and Mitigation

### Risk: Each step could reveal blocking issues
**Mitigation**: Thorough testing at each step before proceeding

### Risk: Cumulative time may exceed direct upgrade
**Mitigation**: Learning curve is smoother, debugging is easier

### Risk: Some intermediate versions may not be well supported
**Mitigation**: Using Android Tegra kernels ensures good Tegra support

---

## Current Status: Starting Step 1

**Next Actions**:
1. Download kernel 3.10 sources
2. Copy configuration and board files
3. Build and test
4. Commit if successful

See STEP1_3.4_TO_3.10.md for detailed instructions.
