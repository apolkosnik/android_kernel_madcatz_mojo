# Step 2: Kernel 3.10 → 3.18 Upgrade Guide

## Overview

This is the second incremental step, upgrading from kernel 3.10 to 3.18 for Android 8.1 Oreo support.

**Difficulty**: Medium
**Timeline**: 2-3 weeks
**Target**: Android 8.1 Oreo
**Kernel Version**: 3.18.140 LTS

---

## Prerequisites

- [ ] Kernel 3.10 successfully built and tested
- [ ] All hardware validated on 3.10
- [ ] Android boots completely on 3.10
- [ ] No critical bugs in 3.10

**IMPORTANT**: Do not proceed to 3.18 until 3.10 is stable!

---

## Why Kernel 3.18?

- **Android 8.x minimum requirement**: Kernel 3.18 or higher
- **Device Tree mandatory**: Multi-platform support requires DT
- **Pinctrl subsystem**: Modern pin configuration framework
- **Better hardware support**: Improved Tegra drivers in mainline
- **LTS until January 2017**: Well-maintained and stable

---

## Major Changes from 3.10 to 3.18

### 1. Device Tree Becomes Mandatory

In 3.10, device tree was optional. In 3.18, it's **required** for ARM multi-platform kernels.

**Impact**: Board files must be converted to device tree
**Good news**: We already have `tegra114-mojo.dts` prepared!

### 2. Pinctrl Subsystem

Old tegra_pinmux API is deprecated. Must use pinctrl.

**Impact**: Pinmux configuration moves from board files to device tree
**Good news**: Already done in our device tree!

### 3. Common Clock Framework

Clock API modernized with better DT integration.

**Impact**: Clock consumers updated, but mostly transparent
**Action**: Minimal changes needed

### 4. GPIO Updates

GPIO framework improvements, but not as drastic as 4.x.

**Impact**: Mostly compatible, some new helper functions
**Action**: Optional updates for cleaner code

### 5. Driver Framework Updates

Many driver subsystems updated:
- Regulator framework enhancements
- I2C bus recovery support
- SPI framework improvements
- MMC/SD improvements

---

## Download Kernel 3.18 Sources

### Option A: Android Tegra Kernel (Recommended)

```bash
git clone --depth=1 --branch android-tegra-3.18 \
    https://android.googlesource.com/kernel/tegra kernel-3.18

cd kernel-3.18
```

**Branches available**:
- `android-tegra-3.18` - Base 3.18 with Tegra support
- `android-tegra-dragon-3.18` - Pixel C (similar hardware)

### Option B: Mainline Kernel 3.18 LTS

```bash
wget https://cdn.kernel.org/pub/linux/kernel/v3.x/linux-3.18.140.tar.xz
tar -xf linux-3.18.140.tar.xz
cd linux-3.18.140
```

**Note**: Option A is recommended as it has Android and Tegra patches.

---

## Migration Steps

### Step 2.1: Set Up Directory Structure

```bash
# Navigate to downloaded 3.18 kernel
cd /path/to/kernel-3.18

# Or use helper script
cd /path/to/mojo-kernel-repo
./UPGRADE_HELPER.sh setup-3.18 /path/to/kernel-3.18

# Create working branch
cd /path/to/kernel-3.18
git checkout -b mojo-3.18-android8.1
```

### Step 2.2: Copy Device Tree

The device tree replaces most board file functionality:

```bash
# Copy our prepared device tree
cp /path/to/mojo-repo/arch/arm/boot/dts/tegra114-mojo.dts \
   arch/arm/boot/dts/

# Check if nvidia directory exists (some 3.18 kernels reorganized DTs)
if [ -d arch/arm/boot/dts/nvidia ]; then
    cp /path/to/mojo-repo/arch/arm/boot/dts/tegra114-mojo.dts \
       arch/arm/boot/dts/nvidia/
fi
```

### Step 2.3: Update Device Tree for 3.18

Edit `arch/arm/boot/dts/tegra114-mojo.dts`:

```dts
/dts-v1/;

#include "tegra114.dtsi"

/ {
	model = "MadCatz MOJO";
	compatible = "madcatz,mojo", "nvidia,tegra114";

	aliases {
		serial0 = &uarta;
		serial1 = &uartb;
		serial2 = &uartc;
		serial3 = &uartd;
	};

	chosen {
		stdout-path = "serial3:115200n8";
	};

	memory@80000000 {
		device_type = "memory";
		reg = <0x80000000 0x80000000>; /* 2GB */
	};

	/* Pinctrl is now in device tree */
	pinmux@70000868 {
		pinctrl-names = "default";
		pinctrl-0 = <&state_default>;

		state_default: pinmux {
			/* Copy complete pinmux from existing tegra114-mojo.dts */
		};
	};

	/* All other hardware definitions... */
};
```

### Step 2.4: Add to Device Tree Makefile

Edit `arch/arm/boot/dts/Makefile`:

```makefile
dtb-$(CONFIG_ARCH_TEGRA_114_SOC) += \
	tegra114-dalmore.dtb \
	tegra114-mojo.dtb \
	tegra114-roth.dtb \
	tegra114-tn7.dtb
```

Or if using nvidia subdirectory:

Edit `arch/arm/boot/dts/nvidia/Makefile`:

```makefile
dtb-$(CONFIG_ARCH_TEGRA_114_SOC) += \
	tegra114-mojo.dtb
```

### Step 2.5: Create Kernel Configuration

Copy the 3.18 configuration:

```bash
cp /path/to/mojo-repo/arch/arm/configs/lineageos_mojo_3.18_defconfig \
   arch/arm/configs/
```

Or create from 3.10 config:

```bash
# Start with 3.10 config
cp /path/to/kernel-3.10/.config .config

# Update for 3.18
make ARCH=arm oldconfig
make ARCH=arm menuconfig
```

### Step 2.6: Key Configuration Changes

#### Update Version
```kconfig
CONFIG_LOCALVERSION="-android8.1-step2"
```

#### Multi-Platform Support
```kconfig
CONFIG_ARCH_MULTIPLATFORM=y
CONFIG_ARCH_MULTI_V7=y

# Disable old single-platform
# CONFIG_ARCH_TEGRA_2x_SOC is not set
# CONFIG_ARCH_TEGRA_3x_SOC is not set
CONFIG_ARCH_TEGRA_114_SOC=y
```

#### Pinctrl (Mandatory)
```kconfig
CONFIG_PINCTRL=y
CONFIG_PINCTRL_TEGRA=y
CONFIG_PINCTRL_TEGRA114=y
```

#### Device Tree (Mandatory)
```kconfig
CONFIG_USE_OF=y
CONFIG_OF=y
CONFIG_OF_EARLY_FLATTREE=y
CONFIG_OF_ADDRESS=y
CONFIG_OF_IRQ=y
CONFIG_OF_RESERVED_MEM=y
```

#### Common Clock Framework
```kconfig
CONFIG_COMMON_CLK=y
CONFIG_CLKDEV_LOOKUP=y
CONFIG_HAVE_CLK_PREPARE=y
CONFIG_COMMON_CLK_TEGRA=y
```

#### DMA Engine
```kconfig
CONFIG_DMADEVICES=y
CONFIG_TEGRA20_APB_DMA=y
CONFIG_DMA_ENGINE=y
CONFIG_DMA_OF=y
```

#### Improved Android Support
```kconfig
# Android features same as 3.10
CONFIG_ANDROID=y
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ASHMEM=y
CONFIG_ANDROID_LOW_MEMORY_KILLER=y

# New in 3.18: Better sync framework
CONFIG_SYNC=y
CONFIG_SW_SYNC=y
CONFIG_SW_SYNC_USER=y
```

#### Remove Board File Dependencies
```kconfig
# These are no longer needed with DT
# CONFIG_NEED_MACH_IO_H is not set
# CONFIG_NEED_MACH_MEMORY_H is not set
```

### Step 2.7: Update Mach-Tegra Configuration

Edit `arch/arm/mach-tegra/Kconfig`:

```kconfig
config ARCH_TEGRA
	bool "NVIDIA Tegra" if ARCH_MULTI_V7
	select ARCH_HAS_CPUFREQ
	select ARCH_REQUIRE_GPIOLIB
	select ARM_GIC
	select CLKDEV_LOOKUP
	select CLKSRC_MMIO
	select CLKSRC_OF
	select COMMON_CLK
	select CPU_V7
	select GENERIC_CLOCKEVENTS
	select HAVE_ARM_SCU if SMP
	select HAVE_ARM_TWD if SMP
	select HAVE_CLK
	select HAVE_SMP
	select MIGHT_HAVE_CACHE_L2X0
	select MIGHT_HAVE_PCI
	select PINCTRL
	select PINCTRL_TEGRA
	select PM_OPP
	select RESET_CONTROLLER
	select SOC_BUS
	select USB_ARCH_HAS_EHCI if USB_SUPPORT
	select USB_ULPI if USB_PHY
	select USB_ULPI_VIEWPORT if USB_PHY
	select USE_OF
	help
	  This enables support for NVIDIA Tegra based systems.

config ARCH_TEGRA_114_SOC
	bool "Enable support for Tegra114 family"
	select ARM_ERRATA_720789
	select ARM_ERRATA_754322
	select ARM_ERRATA_764369 if SMP
	select PINCTRL_TEGRA114
	select TEGRA_IOMMU_SMMU
	help
	  Support for NVIDIA Tegra T114 processor family, based on the
	  ARM CortexA15MP CPU and the ARM PL310 L2 cache controller
```

### Step 2.8: Disable Board Files (DT takes over)

The board files from 3.10 are **no longer used**. Everything moves to device tree.

If you copied board files, you can remove them:

```bash
# Board files are not needed in 3.18 with DT
# All configuration is in tegra114-mojo.dts now
rm arch/arm/mach-tegra/board-mojo*.c 2>/dev/null || true
```

---

## Build Process

### Step 2.9: Configure Kernel

```bash
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

# Use our defconfig
make lineageos_mojo_3.18_defconfig

# Optional: Review configuration
make menuconfig
```

### Step 2.10: Build

```bash
# Build kernel, modules, and device tree
make -j$(nproc) zImage modules dtbs

# Check outputs
ls -lh arch/arm/boot/zImage
ls -lh arch/arm/boot/dts/tegra114-mojo.dtb
# or
ls -lh arch/arm/boot/dts/nvidia/tegra114-mojo.dtb
```

### Step 2.11: Install Modules

```bash
make INSTALL_MOD_PATH=/tmp/mojo-3.18-modules modules_install

# Modules location:
ls /tmp/mojo-3.18-modules/lib/modules/3.18.*/
```

### Step 2.12: Create Boot Image

```bash
# Kernel with appended DTB
cat arch/arm/boot/zImage arch/arm/boot/dts/tegra114-mojo.dtb > /tmp/zImage-dtb

# Create boot image
mkbootimg \
    --kernel /tmp/zImage-dtb \
    --ramdisk /path/to/ramdisk.img \
    --cmdline "console=ttyS0,115200n8 androidboot.selinux=permissive" \
    --base 0x10000000 \
    --pagesize 2048 \
    --output boot-mojo-3.18.img
```

---

## Testing Procedure

### Phase 1: Boot Validation

```bash
# Flash and boot
adb reboot bootloader
fastboot flash boot boot-mojo-3.18.img
fastboot reboot

# Check kernel version
adb shell uname -a
# Should show: 3.18.XXX-android8.1-step2

# Check device tree
adb shell cat /proc/device-tree/model
# Should show: MadCatz MOJO

# Check for device tree nodes
adb shell ls /proc/device-tree/
```

### Phase 2: Hardware Validation

Since we're using device tree now, verify all hardware:

```bash
# I2C buses (should show all devices from DT)
adb shell i2cdetect -y 0  # Sensors and codec
adb shell i2cdetect -y 1  # Power monitor
adb shell i2cdetect -y 4  # PMIC

# Regulators (check all PMIC regulators)
adb shell cat /sys/kernel/debug/regulator/regulator_summary

# Clocks
adb shell cat /sys/kernel/debug/clk/clk_summary

# Pinctrl
adb shell cat /sys/kernel/debug/pinctrl/70000868.pinmux/pinmux-pins

# GPIO
adb shell cat /sys/kernel/debug/gpio

# Thermal zones
adb shell cat /sys/class/thermal/thermal_zone*/temp
```

### Phase 3: Comprehensive Testing

Use the same checklist from Step 1, plus:

- [ ] Device tree loaded correctly
- [ ] All I2C devices detected
- [ ] PMIC regulators functional
- [ ] Clocks configured properly
- [ ] Pinmux working (no conflicts)
- [ ] GPIOs accessible
- [ ] Thermal monitoring active

---

## Common Issues and Solutions

### Issue 1: Device Tree Not Found

**Symptom**:
```
Error: appended device tree blob not found
```

**Solution**:
```bash
# Ensure DTB is appended to kernel
cat arch/arm/boot/zImage arch/arm/boot/dts/tegra114-mojo.dtb > zImage-dtb

# Or build with CONFIG_ARM_APPENDED_DTB=y
```

### Issue 2: Pinctrl Errors

**Symptom**:
```
pinctrl-tegra: pin config failed for PIN
```

**Solution**:
1. Check device tree pinmux section
2. Verify pin names match tegra114 pinctrl driver
3. Use `pinctrl-tegra114.h` definitions

### Issue 3: I2C Devices Not Detected

**Symptom**: i2cdetect shows empty buses

**Solution**:
```bash
# Check device tree I2C nodes have status = "okay"
# Verify I2C addresses match hardware
# Check I2C pinmux in device tree
```

### Issue 4: Regulator Failures

**Symptom**:
```
palmas-pmic: failed to get regulator
```

**Solution**:
1. Verify PMIC device tree node
2. Check regulator-compatible properties
3. Ensure regulator consumers reference correct names

### Issue 5: Clock Not Found

**Symptom**:
```
tegra-i2c: cannot get clock
```

**Solution**:
```dts
// In device tree, ensure clocks referenced:
i2c@7000c000 {
	clocks = <&tegra_car TEGRA114_CLK_I2C1>;
	clock-names = "div-clk";
};
```

### Issue 6: Multi-Platform Boot Fails

**Symptom**: Kernel doesn't boot at all

**Solution**:
```kconfig
# Ensure only Tegra114 enabled
CONFIG_ARCH_TEGRA_114_SOC=y
# CONFIG_ARCH_TEGRA_2x_SOC is not set
# CONFIG_ARCH_TEGRA_3x_SOC is not set
# CONFIG_ARCH_TEGRA_124_SOC is not set
```

---

## API Changes from 3.10 to 3.18

### Pinctrl Migration

**Old (3.10 board file)**:
```c
tegra_pinmux_config_table(pinmux_config, ARRAY_SIZE(pinmux_config));
```

**New (3.18 device tree)**:
```dts
pinmux@70000868 {
	pinctrl-names = "default";
	pinctrl-0 = <&state_default>;

	state_default: pinmux {
		uart1_tx {
			nvidia,pins = "kb_row9_ps1";
			nvidia,function = "uarta";
			nvidia,pull = <TEGRA_PIN_PULL_NONE>;
			nvidia,tristate = <TEGRA_PIN_DISABLE>;
		};
	};
};
```

### Clock Framework

**Old (3.10)**:
```c
clk = clk_get_sys(NULL, "pll_a");
clk_enable(clk);
```

**New (3.18 - still works, but better way)**:
```c
clk = devm_clk_get(&pdev->dev, "pll_a");
clk_prepare_enable(clk);
```

**Best (3.18 with DT)**:
```dts
device@address {
	clocks = <&tegra_car TEGRA114_CLK_PLL_A>;
	clock-names = "pll_a";
};
```

### GPIO (Minor Changes)

**Old (3.10)**:
```c
gpio_request(TEGRA_GPIO_PK6, "enable");
gpio_direction_output(TEGRA_GPIO_PK6, 1);
```

**New (3.18 - still compatible)**:
```c
// Same code works, but can use devm_ variants:
devm_gpio_request_one(&pdev->dev, TEGRA_GPIO_PK6,
                      GPIOF_OUT_INIT_HIGH, "enable");
```

### Regulators (No Changes)

Regulator API is compatible between 3.10 and 3.18.

---

## Device Tree Checklist

Ensure your `tegra114-mojo.dts` has:

- [ ] Compatible string: "madcatz,mojo", "nvidia,tegra114"
- [ ] Memory node with correct size (2GB = 0x80000000)
- [ ] All UARTs with status = "okay"
- [ ] All I2C buses with status = "okay"
- [ ] All I2C devices (PMIC, codec, sensors)
- [ ] PMIC with all regulators defined
- [ ] Complete pinmux configuration
- [ ] GPIO keys (power button)
- [ ] Fixed regulators (vdd_hdmi_5v0, etc.)
- [ ] MMC/SD controllers with correct properties
- [ ] USB controllers
- [ ] Sound node (if supported)
- [ ] Display/HDMI configuration

---

## Performance Tuning for 3.18

### CPU Governor

```bash
# Interactive governor (better for 3.18)
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "interactive" > $cpu
done

# Tune interactive parameters
echo 20000 > /sys/devices/system/cpu/cpufreq/interactive/timer_rate
echo 80 > /sys/devices/system/cpu/cpufreq/interactive/go_hispeed_load
echo 1400000 > /sys/devices/system/cpu/cpufreq/interactive/hispeed_freq
```

### I/O Scheduler

```bash
# Deadline scheduler for better responsiveness
echo "deadline" > /sys/block/mmcblk0/queue/scheduler
echo "deadline" > /sys/block/mmcblk1/queue/scheduler
```

### Memory Management

```bash
# Optimize for 2GB RAM
echo 100 > /proc/sys/vm/swappiness
echo 60 > /proc/sys/vm/vfs_cache_pressure
```

---

## Verification Checklist

Before proceeding to Step 3 (3.18 → 4.4):

- [ ] Kernel 3.18 boots successfully
- [ ] Device tree loaded and parsed correctly
- [ ] All I2C devices detected from DT
- [ ] PMIC regulators working
- [ ] Clocks configured via DT
- [ ] Pinmux applied from DT
- [ ] Storage devices work (eMMC, SD, WiFi SDIO)
- [ ] WiFi connects and transfers data
- [ ] Bluetooth pairs and works
- [ ] HDMI display functional
- [ ] Audio works
- [ ] All sensors provide data
- [ ] USB OTG switching works
- [ ] Android boots to home screen
- [ ] Apps run without crashes
- [ ] No critical errors in dmesg
- [ ] Performance acceptable
- [ ] Battery/thermal monitoring works

---

## Commit and Tag

Once everything works:

```bash
git add -A
git commit -m "Upgrade MadCatz MOJO kernel to 3.18 for Android 8.1

- Kernel version: 3.10 → 3.18.140
- Android target: 8.1 Oreo
- Migrated to device tree (board files removed)
- Pinctrl subsystem enabled
- Multi-platform support enabled
- All hardware functional via DT
- Ready for next step (3.18 → 4.4)"

git tag v3.18-android8.1-step2
```

---

## Next Steps

Once kernel 3.18 is stable:

1. Review Step 3 guide: `STEP3_3.18_TO_4.4.md`
2. Download kernel 4.4 sources
3. Plan for major driver updates (DRM, ASoC)
4. Begin Step 3 migration

---

## Key Differences Summary

| Aspect | 3.10 | 3.18 |
|--------|------|------|
| **Device Tree** | Optional | Mandatory |
| **Pinmux** | Board files | Device tree |
| **Clocks** | API calls | Device tree |
| **Multi-platform** | Optional | Required |
| **Board Files** | Used | Removed |
| **Difficulty** | Easy | Medium |

---

## Estimated Effort

| Task | Time Estimate |
|------|--------------|
| Download and setup | 2-4 hours |
| Device tree verification | 4-6 hours |
| Configuration update | 3-4 hours |
| Build and debug compile errors | 4-8 hours |
| Initial boot testing | 6-10 hours |
| Device tree debugging | 8-16 hours |
| Hardware validation | 8-12 hours |
| Bug fixes | 8-16 hours |
| **Total** | **43-76 hours (2-3 weeks)** |

---

## Resources

- [Device Tree Specification](https://www.devicetree.org/)
- [Tegra Device Tree Bindings](https://www.kernel.org/doc/Documentation/devicetree/bindings/arm/tegra/)
- [Pinctrl Subsystem](https://www.kernel.org/doc/Documentation/pinctrl.txt)
- [Common Clock Framework](https://www.kernel.org/doc/Documentation/clk.txt)
- [Multi-Platform](https://www.kernel.org/doc/Documentation/arm/porting.txt)

---

**Status**: Ready to begin
**Prerequisites**: Kernel 3.10 stable and tested
**Next Step**: STEP3_3.18_TO_4.4.md
