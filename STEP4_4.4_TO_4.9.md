# Step 4: Kernel 4.4 → 4.9 Upgrade Guide

## Overview

This is the final step! Upgrading from kernel 4.4 to 4.9 for Android 10/11 (LineageOS 17/18) support.

**Difficulty**: Medium
**Timeline**: 1-2 weeks
**Target**: Android 10/11 (LineageOS 17/18)
**Kernel Version**: 4.9.337 LTS

---

## Prerequisites

- [ ] Kernel 4.4 successfully built and tested
- [ ] DRM/KMS display working perfectly
- [ ] ASoC audio functional
- [ ] All GPIO using descriptors
- [ ] Android 9 boots and runs well on 4.4

**YOU'RE ALMOST THERE!** This final step is much easier than Step 3.

---

## Why Kernel 4.9?

- **Android 10/11 support**: Official requirement
- **BinderFS**: Modern binder interface
- **Energy Aware Scheduling (EAS)**: Better battery life
- **Enhanced Security**: Improved namespacing and isolation
- **LTS until January 2023**: Long-term support
- **LineageOS 17/18**: Widely used and tested

---

## What's New in 4.9 (vs 4.4)

### 1. BinderFS (New!)

Replaces static /dev/binder nodes with dynamic filesystem.

**Old (4.4)**: `/dev/binder`, `/dev/hwbinder`, `/dev/vndbinder`
**New (4.9)**: Mounted at `/dev/binderfs/`

**Impact**: Configuration change only
**Complexity**: LOW

### 2. Energy Aware Scheduling (EAS)

CPU scheduler improvements for better power efficiency.

**Impact**: Configuration and device tree updates
**Complexity**: LOW-MEDIUM

### 3. schedutil Governor

New CPU frequency governor based on scheduler utilization.

**Impact**: Better than interactive governor
**Complexity**: LOW

### 4. Memory Management Improvements

- Per-process reclaim improvements
- Better ZRAM support
- Enhanced memory cgroups

**Impact**: Configuration changes
**Complexity**: LOW

### 5. Security Enhancements

- SELinux improvements
- Better namespace isolation
- Enhanced seccomp filtering

**Impact**: Mostly automatic
**Complexity**: LOW

---

## Good News!

Most of the hard work was done in Step 3 (4.4):
- ✅ DRM/KMS already working
- ✅ ASoC component framework in place
- ✅ GPIO descriptors migrated
- ✅ Device tree complete

Step 4 is mostly **refinements and new features**!

---

## Download Kernel 4.9 Sources

### Option A: Android Common Kernel (Recommended)

```bash
git clone --depth=1 --branch android-4.9-q \
    https://android.googlesource.com/kernel/common kernel-4.9

cd kernel-4.9
```

### Option B: Mainline 4.9 LTS

```bash
wget https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.9.337.tar.xz
tar -xf linux-4.9.337.tar.xz
cd linux-4.9.337
```

### Option C: Helper Script

```bash
./UPGRADE_HELPER.sh download-sources
# Follow 4.9 instructions
./UPGRADE_HELPER.sh setup-4.9 /path/to/kernel-4.9
```

---

## Migration Steps

### Step 4.1: Set Up Directory

```bash
cd /path/to/kernel-4.9
git checkout -b mojo-4.9-android10
```

### Step 4.2: Copy Device Tree

Use the comprehensive device tree we prepared:

```bash
# Use the Android 10 device tree
cp /path/to/mojo-repo/arch/arm/boot/dts/tegra114-mojo-android10.dts \
   arch/arm/boot/dts/tegra114-mojo.dts

# Or copy from 4.4 and enhance
cp /path/to/kernel-4.4/arch/arm/boot/dts/tegra114-mojo.dts \
   arch/arm/boot/dts/
```

### Step 4.3: Device Tree Enhancements for 4.9

Add EAS support to device tree:

```dts
/ {
	/* ... existing nodes ... */

	/* Add CPU capacity for EAS */
	cpus {
		#address-cells = <1>;
		#size-cells = <0>;

		cpu@0 {
			device_type = "cpu";
			compatible = "arm,cortex-a15";
			reg = <0>;
			capacity-dmips-mhz = <1024>;
		};

		cpu@1 {
			device_type = "cpu";
			compatible = "arm,cortex-a15";
			reg = <1>;
			capacity-dmips-mhz = <1024>;
		};

		cpu@2 {
			device_type = "cpu";
			compatible = "arm,cortex-a15";
			reg = <2>;
			capacity-dmips-mhz = <1024>;
		};

		cpu@3 {
			device_type = "cpu";
			compatible = "arm,cortex-a15";
			reg = <3>;
			capacity-dmips-mhz = <1024>;
		};
	};

	/* Optional: Define energy model */
	energy-costs {
		CPU_COST_0: core-cost0 {
			busy-cost-data = <
				251  41
				442  72
				634  103
				825  134
				1016 178
				1207 221
				1398 265
				1590 343
			>;
			idle-cost-data = <
				15
				15
				0
			>;
		};
	};
};
```

### Step 4.4: Configuration for Android 10/11

```bash
# Use our comprehensive config
make ARCH=arm lineageos_mojo_android10_defconfig

# Or start from 4.4
cp /path/to/kernel-4.4/.config .config
make ARCH=arm oldconfig
make ARCH=arm menuconfig
```

### Step 4.5: Key Configuration Changes

#### Version
```kconfig
CONFIG_LOCALVERSION="-android10-step4"
```

#### BinderFS (New!)
```kconfig
CONFIG_ANDROID_BINDERFS=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"
```

#### Energy Aware Scheduling
```kconfig
# EAS support
CONFIG_ENERGY_MODEL=y
CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y

# Disable old governors (optional)
# CONFIG_CPU_FREQ_GOV_ONDEMAND is not set
# CONFIG_CPU_FREQ_GOV_CONSERVATIVE is not set
# CONFIG_CPU_FREQ_GOV_INTERACTIVE is not set
```

#### Enhanced Scheduler
```kconfig
CONFIG_SCHED_TUNE=y
CONFIG_SCHED_DEBUG=y
CONFIG_SCHEDSTATS=y
```

#### Memory Management
```kconfig
# PSI (Pressure Stall Information)
CONFIG_PSI=y
CONFIG_PSI_DEFAULT_DISABLED=n

# Enhanced memory cgroups
CONFIG_MEMCG=y
CONFIG_MEMCG_SWAP=y
CONFIG_MEMCG_SWAP_ENABLED=y

# ZRAM improvements
CONFIG_ZRAM=y
CONFIG_ZSMALLOC=y
CONFIG_ZRAM_WRITEBACK=y
```

#### Block Layer
```kconfig
# BFQ I/O scheduler (better for Android)
CONFIG_IOSCHED_BFQ=y
CONFIG_BFQ_GROUP_IOSCHED=y
```

#### Networking
```kconfig
# Improved networking
CONFIG_NETFILTER_XT_MATCH_QTAGUID=y
CONFIG_NETFILTER_XT_MATCH_QUOTA2=y
CONFIG_NETFILTER_XT_MATCH_OWNER=y
```

#### Security
```kconfig
# Hardened usercopy
CONFIG_HARDENED_USERCOPY=y
CONFIG_HARDENED_USERCOPY_FALLBACK=y

# Enhanced seccomp
CONFIG_SECCOMP=y
CONFIG_SECCOMP_FILTER=y

# SELinux
CONFIG_SECURITY_SELINUX=y
CONFIG_SECURITY_SELINUX_BOOTPARAM=y
CONFIG_SECURITY_SELINUX_DISABLE=n
```

#### File Systems
```kconfig
# Encryption
CONFIG_FS_ENCRYPTION=y
CONFIG_EXT4_ENCRYPTION=y
CONFIG_F2FS_FS_ENCRYPTION=y

# F2FS improvements
CONFIG_F2FS_FS=y
CONFIG_F2FS_STAT_FS=y
CONFIG_F2FS_FS_XATTR=y
CONFIG_F2FS_FS_POSIX_ACL=y
CONFIG_F2FS_FS_SECURITY=y

# SDCardFS (if available in your kernel)
CONFIG_SDCARD_FS=y
```

#### ION Updates
```kconfig
# ION still present in 4.9 but being deprecated
CONFIG_ION=y
CONFIG_ION_TEGRA=y

# For Android 11, consider migrating to DMA-BUF heaps
```

---

## Build and Test

### Step 4.6: Build Kernel 4.9

```bash
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

make -j$(nproc) zImage modules dtbs
```

### Step 4.7: Install Modules

```bash
make INSTALL_MOD_PATH=/tmp/mojo-4.9-modules modules_install
```

### Step 4.8: Create Boot Image

```bash
# Combine kernel + DTB
cat arch/arm/boot/zImage arch/arm/boot/dts/tegra114-mojo.dtb > /tmp/zImage-dtb

# Create Android 10 boot image
mkbootimg \
    --kernel /tmp/zImage-dtb \
    --ramdisk /path/to/android10-ramdisk.img \
    --cmdline "console=ttyS0,115200n8 androidboot.selinux=enforcing" \
    --base 0x10000000 \
    --pagesize 2048 \
    --os_version 10.0.0 \
    --os_patch_level 2024-11 \
    --output boot-mojo-4.9-android10.img

# Or for Android 11
mkbootimg \
    --kernel /tmp/zImage-dtb \
    --ramdisk /path/to/android11-ramdisk.img \
    --cmdline "console=ttyS0,115200n8 androidboot.selinux=enforcing" \
    --base 0x10000000 \
    --pagesize 2048 \
    --os_version 11.0.0 \
    --os_patch_level 2024-11 \
    --output boot-mojo-4.9-android11.img
```

### Step 4.9: Flash and Boot

```bash
adb reboot bootloader
fastboot flash boot boot-mojo-4.9-android10.img
fastboot reboot
```

---

## Testing Android 10/11 Features

### Test BinderFS

```bash
# Check binderfs mounted
adb shell mount | grep binderfs
# Should show: /dev/binderfs type binder (rw,...)

# Check binder devices
adb shell ls /dev/binderfs/
# Should show: binder hwbinder vndbinder

# Test binder communication
adb shell service list | head
# Should work without errors
```

### Test EAS

```bash
# Check schedutil governor
adb shell cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
# Should show: schedutil

# Check CPU capacity
adb shell cat /sys/devices/system/cpu/cpu*/cpu_capacity
# Should show values for all CPUs

# Monitor CPU frequency with load
adb shell "while true; do cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; sleep 1; done"
```

### Test Memory Features

```bash
# Check PSI
adb shell cat /proc/pressure/cpu
adb shell cat /proc/pressure/memory
adb shell cat /proc/pressure/io

# Check ZRAM
adb shell cat /proc/swaps
# Should show zram if enabled

# Memory cgroups
adb shell cat /sys/fs/cgroup/memory/memory.stat
```

### Test Security

```bash
# SELinux should be enforcing
adb shell getenforce
# Should show: Enforcing

# Check seccomp
adb shell dmesg | grep seccomp

# Test namespaces
adb shell ls /proc/self/ns/
# Should show all namespace types
```

---

## Performance Tuning for 4.9

### CPU Governor Tuning

```bash
# schedutil is default, but can tune parameters
adb shell "echo 1000 > /sys/devices/system/cpu/cpufreq/schedutil/rate_limit_us"
```

### I/O Scheduler

```bash
# Use BFQ for better responsiveness
adb shell "echo bfq > /sys/block/mmcblk0/queue/scheduler"
adb shell "echo bfq > /sys/block/mmcblk1/queue/scheduler"
```

### ZRAM Configuration

```bash
# Enable ZRAM for better memory management
adb shell "echo lz4 > /sys/block/zram0/comp_algorithm"
adb shell "echo 1G > /sys/block/zram0/disksize"
adb shell "mkswap /dev/block/zram0"
adb shell "swapon /dev/block/zram0"
```

### Low Memory Killer

Android 10+ uses lmkd (userspace) instead of kernel LMK:

```bash
# Check lmkd running
adb shell "ps -A | grep lmkd"

# Monitor memory pressure
adb shell "cat /proc/pressure/memory"
```

---

## Android 10 vs Android 11

### For Android 10 (LineageOS 17.x)

Configuration is mostly covered above. Key points:
- ION still used
- BinderFS required
- EAS recommended but optional
- SELinux can be permissive during testing

### For Android 11 (LineageOS 18.x)

Additional requirements:

```kconfig
# Android 11 specific
CONFIG_ANDROID_BINDER_IPC_SELFTEST=n

# DMA-BUF heaps (ION replacement)
CONFIG_DMABUF_HEAPS=y
CONFIG_DMABUF_SYSFS_STATS=y

# eBPF (required for Android 11+)
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_HAVE_EBPF_JIT=y

# Required for APEX
CONFIG_BLK_DEV_LOOP=y
CONFIG_BLK_DEV_LOOP_MIN_COUNT=16
```

---

## Verification Checklist

Final validation before declaring success:

- [ ] Kernel 4.9 boots successfully
- [ ] Display works (DRM/KMS)
- [ ] Audio playback and recording
- [ ] WiFi connects and transfers data
- [ ] Bluetooth pairs and works
- [ ] All sensors functional
- [ ] USB OTG mode switching
- [ ] SD card mount/unmount
- [ ] BinderFS working
- [ ] EAS/schedutil functional
- [ ] ZRAM working
- [ ] Android 10/11 boots to home
- [ ] Google Play Services works (if installed)
- [ ] Apps install and run
- [ ] Camera works (if supported)
- [ ] No critical errors in logcat
- [ ] Performance is good
- [ ] Battery life acceptable
- [ ] Thermal management working
- [ ] SELinux enforcing (or permissive if testing)

---

## Common Issues

### Issue 1: BinderFS Mount Failure

**Symptom**: Android doesn't boot, binder errors

**Solution**:
```bash
# Check kernel config
zcat /proc/config.gz | grep BINDERFS
# Should show CONFIG_ANDROID_BINDERFS=y

# Verify ramdisk has binderfs mount
# init.rc should have:
# mkdir /dev/binderfs
# mount binder binder /dev/binderfs stats=global
```

### Issue 2: EAS Not Working

**Symptom**: schedutil not available

**Solution**:
```kconfig
CONFIG_ENERGY_MODEL=y
CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y
```

### Issue 3: Apps Crashing

**Symptom**: Apps crash with SELinux denials

**Solution**:
```bash
# Temporarily use permissive mode
adb shell setenforce 0

# Check denials
adb shell dmesg | grep avc

# Fix SELinux policy for Android 10/11
```

### Issue 4: Poor Performance

**Symptom**: System feels slow

**Solution**:
```bash
# Check CPU frequency scaling
adb shell cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq

# Ensure thermal throttling not active
adb shell cat /sys/class/thermal/thermal_zone*/temp

# Check for CPU hotplug issues
adb shell cat /sys/devices/system/cpu/online
```

---

## Final Optimizations

### For Best Performance

```bash
# Use performance governor temporarily for benchmarks
adb shell "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"

# Disable CPU hotplug if unstable
adb shell "echo 0 > /sys/devices/system/cpu/cpuquiet/tegra_cpuquiet/enable"

# Bring all cores online
for i in 0 1 2 3; do
    adb shell "echo 1 > /sys/devices/system/cpu/cpu$i/online"
done
```

### For Best Battery Life

```bash
# Use schedutil with conservative settings
adb shell "echo schedutil > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
adb shell "echo 10000 > /sys/devices/system/cpu/cpufreq/schedutil/rate_limit_us"

# Enable all power saving features
adb shell "echo 1 > /sys/module/cpuidle_t11x/parameters/lp2_in_idle"
```

---

## Success Criteria

You've successfully completed the incremental upgrade if:

✅ Kernel 4.9 boots reliably
✅ All hardware functional (display, audio, WiFi, BT, sensors, storage, USB)
✅ Android 10 or 11 boots to home screen
✅ Can install and run apps from Play Store
✅ System is stable (no crashes, no reboots)
✅ Performance is acceptable
✅ Battery life is reasonable
✅ No critical bugs

**CONGRATULATIONS!** You've upgraded from Linux 3.4.57 (Android 6) to Linux 4.9 (Android 10/11)!

---

## Commit and Celebrate!

```bash
git add -A
git commit -m "Complete upgrade to kernel 4.9 for Android 10/11!

- Kernel version: 4.4 → 4.9.337
- Android support: 10/11 (LineageOS 17/18)
- BinderFS enabled
- Energy Aware Scheduling (EAS)
- schedutil governor
- Enhanced security and memory management
- All hardware functional
- Incremental upgrade complete!
- Total journey: 3.4.57 → 3.10 → 3.18 → 4.4 → 4.9"

git tag v4.9-android10-complete
```

---

## What You've Accomplished

Over the past 6-10 weeks, you've:

1. **Step 1**: Upgraded 3.4.57 → 3.10 (Android 8.0)
2. **Step 2**: Upgraded 3.10 → 3.18 (Android 8.1, device tree migration)
3. **Step 3**: Upgraded 3.18 → 4.4 (Android 9.0, DRM/KMS, ASoC, GPIO descriptors)
4. **Step 4**: Upgraded 4.4 → 4.9 (Android 10/11, modern features)

**Total Kernel Version Jump**: 3.4.57 → 4.9.337 (5+ years of kernel development!)
**Total Android Jump**: Android 6 → Android 10/11
**Total New Features**: Hundreds of driver updates, framework modernizations, security enhancements

---

## Next Steps (Optional)

### Consider Upstreaming

If your work is successful, consider:
1. Cleaning up device tree for mainline submission
2. Documenting hardware quirks
3. Submitting patches to linux-tegra mailing list

### Help Others

- Share your experience on XDA forums
- Document issues you encountered
- Help other MadCatz MOJO users
- Contribute to LineageOS for Tegra devices

### Keep Updating

- Monitor kernel.org for 4.9 LTS updates
- Update to newer LineageOS versions
- Consider future migration to 4.14 or 4.19 (if you're feeling ambitious!)

---

## Estimated Effort (Step 4 Only)

| Task | Time |
|------|------|
| Setup and configuration | 3-4 hours |
| BinderFS integration | 2-3 hours |
| EAS setup | 3-4 hours |
| Build and debug | 4-6 hours |
| Testing | 8-12 hours |
| Optimization | 4-6 hours |
| **Total** | **24-35 hours (1-2 weeks)** |

---

## Resources

- [Android 10 Kernel Requirements](https://source.android.com/docs/core/architecture/kernel/android-common)
- [BinderFS Documentation](https://www.kernel.org/doc/html/latest/admin-guide/binderfs.html)
- [EAS Documentation](https://www.kernel.org/doc/Documentation/scheduler/sched-energy.txt)
- [LineageOS Build Guide](https://wiki.lineageos.org/devices/)

---

**Congratulations on completing the incremental kernel upgrade journey!** 🎉🚀

Your MadCatz MOJO now runs a modern kernel with Android 10/11 support!

---

**Status**: Complete!
**Achievement**: Full incremental upgrade path finished
**Final Kernel**: Linux 4.9 LTS
**Final Android**: 10/11 (LineageOS 17/18)
