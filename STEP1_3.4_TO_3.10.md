# Step 1: Kernel 3.4.57 → 3.10 Upgrade Guide

## Overview

This is the first incremental step to modernize the MadCatz MOJO kernel for Android 8.0 Oreo support.

**Difficulty**: Low-Medium
**Timeline**: 1-2 weeks
**Target**: Android 8.0 Oreo
**Kernel Version**: 3.10.101 or 3.10.103

---

## Why Kernel 3.10?

- **Android 8.0 minimum requirement**: Kernel 3.18 (but 3.10 works for preparation)
- **Small API changes** from 3.4: Easiest first step
- **Android Tegra support**: Official android-tegra-3.10 branch exists
- **Learning opportunity**: Gentle introduction to newer kernel APIs
- **Fallback point**: Can stay here if needed while planning next step

---

## Download Kernel 3.10 Sources

### Option A: Android Tegra Kernel (Recommended)

```bash
# Clone the official Android Tegra 3.10 kernel
git clone --depth=1 --branch android-tegra-3.10 \
    https://android.googlesource.com/kernel/tegra kernel-3.10

cd kernel-3.10
```

**Branches available**:
- `android-tegra-3.10` - Base 3.10 kernel with Tegra support
- `android-3.10.101` - Android common kernel 3.10.101
- `android-3.10.103` - Android common kernel 3.10.103 (recommended)

### Option B: Mainline Kernel 3.10 LTS

```bash
# Download from kernel.org
wget https://cdn.kernel.org/pub/linux/kernel/v3.x/linux-3.10.108.tar.xz
tar -xf linux-3.10.108.tar.xz
cd linux-3.10.108
```

**Note**: Option A is recommended as it already has Android patches.

---

## Pre-Migration Checklist

- [ ] Current 3.4.57 kernel boots successfully
- [ ] All hardware tested and working on 3.4.57
- [ ] Git backup created: `git tag backup-before-3.10`
- [ ] Kernel 3.10 sources downloaded
- [ ] Cross-compiler available: `arm-linux-gnueabihf-gcc`

---

## Migration Steps

### Step 1.1: Set Up Directory Structure

```bash
# Navigate to downloaded 3.10 kernel
cd /path/to/kernel-3.10

# Create working branch
git checkout -b mojo-3.10-android8
```

### Step 1.2: Copy Board Files

The 3.4 board files should work with minimal changes:

```bash
# Copy all MadCatz MOJO board files
cp -r /path/to/3.4-kernel/arch/arm/mach-tegra/board-mojo* \
      arch/arm/mach-tegra/

# Copy board header
cp /path/to/3.4-kernel/arch/arm/mach-tegra/board-mojo.h \
   arch/arm/mach-tegra/
```

### Step 1.3: Copy and Update Device Tree

```bash
# Copy existing DTS (can still use board files, but DT is optional)
cp /path/to/3.4-kernel/arch/arm/boot/dts/tegra114-mojo.dts \
   arch/arm/boot/dts/

# Add to Makefile
echo "dtb-\$(CONFIG_ARCH_TEGRA_114_SOC) += tegra114-mojo.dtb" >> \
    arch/arm/boot/dts/Makefile
```

### Step 1.4: Create Updated Configuration

Copy the configuration from this repo:
```bash
cp lineageos_mojo_3.10_defconfig arch/arm/configs/
```

Or manually update your existing config:

```bash
# Start with 3.4 config as base
cp /path/to/3.4-kernel/arch/arm/configs/lineageos_mojo_defconfig \
   arch/arm/configs/

# Update for 3.10
make ARCH=arm lineageos_mojo_defconfig
make ARCH=arm menuconfig
```

### Step 1.5: Configuration Changes for 3.10

Key changes needed:

#### Version Update
```kconfig
CONFIG_LOCALVERSION="-android8-step1"
```

#### New Features in 3.10
```kconfig
# File handle support (for systemd compatibility)
CONFIG_FHANDLE=y

# Cross memory attach (for Android)
CONFIG_CROSS_MEMORY_ATTACH=y

# Scheduler improvements
CONFIG_SCHED_AUTOGROUP=y

# Device tree support (optional but recommended)
CONFIG_USE_OF=y
CONFIG_PROC_DEVICETREE=y
```

#### Updated Android Features
```kconfig
# Android already enabled, verify these:
CONFIG_ANDROID=y
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_LOGGER=y
CONFIG_ASHMEM=y
CONFIG_ANDROID_LOW_MEMORY_KILLER=y
CONFIG_ANDROID_INTF_ALARM_DEV=y

# ION improvements in 3.10
CONFIG_ION=y
CONFIG_ION_TEGRA=y
```

### Step 1.6: Update Tegra Mach Configuration

Edit `arch/arm/mach-tegra/Kconfig`:

```kconfig
config MACH_MOJO
	bool "MadCatz MOJO board"
	depends on ARCH_TEGRA_114_SOC
	select MACH_HAS_SND_SOC_TEGRA_RT5640 if SND_SOC
	help
	  Support for the MadCatz MOJO gaming console
```

Add to `arch/arm/mach-tegra/Makefile.boot`:

```makefile
zreladdr-$(CONFIG_ARCH_TEGRA_114_SOC) := 0x80008000
params_phys-$(CONFIG_ARCH_TEGRA_114_SOC) := 0x80000100
initrd_phys-$(CONFIG_ARCH_TEGRA_114_SOC) := 0x81000000

dtb-$(CONFIG_MACH_MOJO) += tegra114-mojo.dtb
```

### Step 1.7: Board File Updates

Most board files will work as-is, but check for these API changes:

#### GPIO Changes (Minor)
```c
// 3.4 code still works in 3.10, but new style available:

// Old style (still works):
gpio_request(TEGRA_GPIO_PK6, "hdmi-enable");
gpio_direction_output(TEGRA_GPIO_PK6, 1);

// New optional style:
gpio_request_one(TEGRA_GPIO_PK6, GPIOF_OUT_INIT_HIGH, "hdmi-enable");
```

#### Regulator Changes (Minimal)
```c
// 3.4 code works in 3.10, no changes required
regulator = regulator_get(dev, "vdd-core");
regulator_enable(regulator);
```

#### Clock Changes (Minimal)
```c
// 3.4 code works in 3.10
clk = clk_get_sys(NULL, "pll_a");
clk_prepare_enable(clk);
```

### Step 1.8: Build the Kernel

```bash
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
export TEGRA_BUILD_DT=y

# Configure
make lineageos_mojo_defconfig

# Optional: Review configuration
make menuconfig

# Build
make -j$(nproc) zImage modules dtbs

# Build results:
# - Kernel: arch/arm/boot/zImage
# - DTB: arch/arm/boot/dts/tegra114-mojo.dtb
# - Modules: (various .ko files)
```

### Step 1.9: Install Modules

```bash
make INSTALL_MOD_PATH=/tmp/mojo-modules modules_install

# Modules will be in:
# /tmp/mojo-modules/lib/modules/3.10.XXX-android8-step1/
```

### Step 1.10: Create Boot Image

```bash
# Combine kernel and DTB (if needed)
cat arch/arm/boot/zImage arch/arm/boot/dts/tegra114-mojo.dtb > \
    /tmp/zImage-dtb

# Create Android boot image
mkbootimg \
    --kernel /tmp/zImage-dtb \
    --ramdisk /path/to/ramdisk.img \
    --cmdline "console=ttyS0,115200n8 androidboot.selinux=permissive" \
    --base 0x10000000 \
    --pagesize 2048 \
    --output boot-mojo-3.10.img
```

---

## Testing Procedure

### Phase 1: Basic Boot Test

1. **Flash kernel**:
   ```bash
   adb reboot bootloader
   fastboot flash boot boot-mojo-3.10.img
   fastboot reboot
   ```

2. **Monitor serial console**:
   - Connect serial cable to UART pins
   - Monitor boot messages
   - Look for kernel panic or errors

3. **Check kernel version**:
   ```bash
   adb shell uname -a
   # Should show: Linux version 3.10.XXX-android8-step1
   ```

### Phase 2: Hardware Validation

```bash
# Check MMC/eMMC
adb shell ls -la /dev/block/mmcblk*

# Check GPIO
adb shell cat /sys/kernel/debug/gpio

# Check clocks
adb shell cat /sys/kernel/debug/clock/clock_tree

# Check regulators
adb shell cat /sys/kernel/debug/regulator/regulator_summary

# Check thermal
adb shell cat /sys/class/thermal/thermal_zone*/temp
```

### Phase 3: Connectivity Test

- [ ] WiFi connects to network
- [ ] Bluetooth pairs with device
- [ ] USB OTG mode works
- [ ] HDMI display output
- [ ] Audio output (HDMI and headphone)

### Phase 4: Sensor Test

```bash
# Check I2C buses
adb shell i2cdetect -y 0  # Sensors bus

# MPU6050 gyro/accel
adb shell cat /sys/bus/iio/devices/iio:device*/name | grep mpu

# AK8975 compass
adb shell cat /sys/bus/iio/devices/iio:device*/name | grep ak89
```

### Phase 5: Android System Test

- [ ] Android boots to home screen
- [ ] Can install and run apps
- [ ] Google Play Services works
- [ ] Camera app opens (if supported)
- [ ] Settings app accessible
- [ ] No frequent crashes or ANRs

---

## Common Issues and Solutions

### Issue 1: Kernel Panic - Unable to Mount Root

**Symptom**:
```
Kernel panic - not syncing: VFS: Unable to mount root fs
```

**Solution**:
- Check `CONFIG_BLK_DEV_INITRD=y`
- Verify ramdisk is correctly built into boot image
- Check cmdline has correct root= parameter

### Issue 2: WiFi Not Working

**Symptom**: WiFi hardware not detected

**Solution**:
```bash
# Verify BCM4329 driver compiled
grep CONFIG_BCM4329 .config

# Check kernel module
adb shell lsmod | grep bcm

# Manually load if needed
adb shell insmod /system/lib/modules/bcmdhd.ko
```

### Issue 3: Display Not Working

**Symptom**: Black screen, no HDMI output

**Solution**:
1. Check regulator init order in board file
2. Verify HDMI regulators enabled:
   ```bash
   adb shell cat /sys/kernel/debug/regulator/regulator_summary | grep hdmi
   ```
3. Check display controller initialization in dmesg

### Issue 4: SELinux Denials

**Symptom**: Apps crash or don't work properly

**Solution**:
```bash
# Temporary: Set SELinux to permissive
fastboot oem selinux permissive

# Or add to kernel cmdline:
androidboot.selinux=permissive

# Later: Fix SELinux policy for Android 8
```

### Issue 5: Build Errors

**Problem**: Compilation fails with undefined references

**Solution**:
```bash
# Clean and rebuild
make mrproper
make lineageos_mojo_defconfig
make -j$(nproc)

# If specific driver fails, try disabling temporarily:
# Edit .config and set CONFIG_PROBLEMATIC_DRIVER=n
```

---

## API Changes from 3.4 to 3.10

### GPIO (Minimal Changes)
- `gpio_request_one()` added (optional convenience function)
- `gpio_request_array()` added (optional for multiple GPIOs)
- Basic GPIO API unchanged

### Regulators (No Changes)
- Regulator framework API compatible
- No code changes needed

### Clocks (No Changes)
- Clock framework API compatible
- `clk_prepare()` / `clk_enable()` pattern same

### I2C (No Changes)
- I2C driver API unchanged
- Device registration same

### Device Tree (Added, Optional)
- Can use DT instead of board files
- Recommended to start transitioning
- Board files still fully supported

---

## Performance Tuning for 3.10

### CPU Governor
```bash
# Interactive governor for better responsiveness
echo "interactive" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

### I/O Scheduler
```bash
# CFQ for better overall performance
echo "cfq" > /sys/block/mmcblk0/queue/scheduler
```

### Memory
```bash
# Lower swappiness
echo 60 > /proc/sys/vm/swappiness

# Enable KSM (if available)
echo 1 > /sys/kernel/mm/ksm/run
```

---

## Verification Checklist

Before proceeding to Step 2 (3.10 → 3.18):

- [ ] Kernel 3.10 boots successfully
- [ ] All storage devices detected (eMMC, SD, WiFi SDIO)
- [ ] WiFi connects and transfers data
- [ ] Bluetooth pairs and works
- [ ] HDMI display outputs correctly
- [ ] Audio works (HDMI and headphone)
- [ ] All sensors provide data
- [ ] USB OTG mode switching works
- [ ] Android boots to home screen
- [ ] Apps install and run
- [ ] No kernel panics or major errors in dmesg
- [ ] Battery/power management works
- [ ] Thermal monitoring functional
- [ ] Performance acceptable

If all items checked, ready for Step 2!

---

## Commit and Tag

Once everything works:

```bash
git add -A
git commit -m "Upgrade MadCatz MOJO kernel to 3.10 for Android 8.0

- Kernel version: 3.4.57 → 3.10.103
- Android target: 8.0 Oreo
- All hardware functional
- Board files updated for 3.10 APIs
- Configuration updated with new features
- Ready for next step (3.10 → 3.18)"

git tag v3.10-android8-step1
```

---

## Next Steps

Once kernel 3.10 is stable and tested:

1. Review Step 2 guide: `STEP2_3.10_TO_3.18.md`
2. Download kernel 3.18 sources
3. Plan device tree conversion (mandatory for 3.18+)
4. Begin Step 2 migration

---

## Estimated Effort

| Task | Time Estimate |
|------|--------------|
| Download and setup | 2-4 hours |
| Configuration update | 2-3 hours |
| Build and debug compile errors | 4-8 hours |
| Initial boot testing | 4-8 hours |
| Hardware validation | 8-12 hours |
| Bug fixes and optimization | 8-16 hours |
| **Total** | **28-51 hours (1-2 weeks)** |

---

## Resources

- [Android Common Kernels](https://source.android.com/docs/core/architecture/kernel/android-common)
- [Tegra Linux Driver Package](https://developer.nvidia.com/embedded/linux-tegra)
- [Kernel 3.10 Documentation](https://kernel.org/doc/html/v3.10/)
- [Android 8.0 Compatibility](https://source.android.com/docs/compatibility/8.0/android-8.0-cdd)

---

**Status**: Ready to begin
**Last Updated**: 2025-11-16
**Next Step**: STEP2_3.10_TO_3.18.md
