# Step 3: Kernel 3.18 → 4.4 Upgrade Guide

## Overview

This is the third and most challenging step, upgrading from kernel 3.18 to 4.4 for Android 9.0 Pie support.

**Difficulty**: Medium-Hard
**Timeline**: 2-3 weeks
**Target**: Android 9.0 Pie (LineageOS 16)
**Kernel Version**: 4.4.302 LTS

---

## Prerequisites

- [ ] Kernel 3.18 successfully built and tested
- [ ] Device tree working perfectly on 3.18
- [ ] All hardware validated on 3.18
- [ ] Android boots completely on 3.18
- [ ] Comfortable with kernel debugging

**CRITICAL**: This is the hardest step. Do not proceed until 3.18 is rock solid!

---

## Why Kernel 4.4?

- **Android 9.0 minimum**: Kernel 4.4 or 4.9 required
- **Modern driver framework**: DRM/KMS, ASoC, GPIO descriptors
- **eBPF support**: Better performance monitoring and filtering
- **LTS until February 2022**: Long-term maintenance
- **LineageOS 16 compatibility**: Widely used for Android 9

---

## MAJOR Changes from 3.18 to 4.4

### 1. Display: Tegra DC → DRM/KMS ⚠️

**Biggest change!** Display subsystem completely rewritten.

**Old (3.18)**: Tegra Display Controller (tegra_dc)
**New (4.4)**: Direct Rendering Manager with Kernel Mode Setting (DRM/KMS)

**Impact**: Complete display driver rewrite required
**Complexity**: HIGH

### 2. Audio: ALSA → ASoC Component Framework ⚠️

Audio subsystem modernized.

**Old (3.18)**: Basic ASoC with platform/codec split
**New (4.4)**: ASoC component model

**Impact**: Audio machine driver updates required
**Complexity**: MEDIUM-HIGH

### 3. GPIO: Numbers → Descriptors ⚠️

GPIO framework fundamentally changed.

**Old (3.18)**: `gpio_request(GPIO_NUM)`
**New (4.4)**: `gpiod_get(&dev, "name")`

**Impact**: All GPIO users must be updated
**Complexity**: MEDIUM

### 4. Regulators: devm_* Mandatory

Device-managed resources now standard.

**Old (3.18)**: Manual resource management
**New (4.4)**: `devm_regulator_get()`

**Impact**: Cleaner code, easier error handling
**Complexity**: LOW

### 5. Android Features

Major Android framework updates:

- Enhanced Binder IPC (hwbinder support)
- eBPF support for performance
- ION updates (still present in 4.4)
- Better cgroup support
- Enhanced SELinux

**Complexity**: LOW-MEDIUM

---

## Download Kernel 4.4 Sources

### Option A: Android Common Kernel (Recommended)

```bash
git clone --depth=1 --branch android-4.4-stable \
    https://android.googlesource.com/kernel/common kernel-4.4

cd kernel-4.4
```

### Option B: Mainline 4.4 LTS

```bash
wget https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.4.302.tar.xz
tar -xf linux-4.4.302.tar.xz
cd linux-4.4.302
```

### Option C: Use Helper Script

```bash
cd /path/to/mojo-repo
./UPGRADE_HELPER.sh download-sources
# Follow instructions for kernel 4.4
```

---

## Migration Strategy

Due to the complexity, we'll take a phased approach:

**Phase 1**: Get basic boot working (no display/audio)
**Phase 2**: Port display to DRM/KMS
**Phase 3**: Port audio to ASoC component framework
**Phase 4**: Update all GPIO users
**Phase 5**: Final integration and testing

---

## Phase 1: Basic Boot

### Step 3.1: Set Up Directory

```bash
cd /path/to/kernel-4.4

# Or use helper
cd /path/to/mojo-repo
./UPGRADE_HELPER.sh setup-4.4 /path/to/kernel-4.4

cd /path/to/kernel-4.4
git checkout -b mojo-4.4-android9
```

### Step 3.2: Update Device Tree

The 3.18 device tree needs updates for 4.4:

```dts
/dts-v1/;

#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>
#include <dt-bindings/interrupt-controller/irq.h>
#include "tegra114.dtsi"

/ {
	model = "MadCatz MOJO";
	compatible = "madcatz,mojo", "nvidia,tegra114";

	/* ... existing nodes ... */

	/* GPIO keys need input.h constants */
	gpio-keys {
		compatible = "gpio-keys";

		power {
			label = "Power";
			gpios = <&gpio TEGRA_GPIO(Q, 0) GPIO_ACTIVE_LOW>;
			linux,code = <KEY_POWER>;
			wakeup-source;
			debounce-interval = <10>;
		};
	};

	/* IMPORTANT: Display config changes for DRM */
	host1x@50000000 {
		/* In 4.4, use DRM subsystem */
		dc@54200000 {
			status = "disabled"; /* Disable old DC driver */
		};

		hdmi@54280000 {
			status = "okay";
			vdd-supply = <&vdd_hdmi_5v0>;
			pll-supply = <&ldo1_reg>;
			hdmi-supply = <&ldoln_reg>;
			nvidia,ddc-i2c-bus = <&hdmi_ddc>;
			nvidia,hpd-gpio = <&gpio TEGRA_GPIO(N, 7) GPIO_ACTIVE_HIGH>;
		};

		/* DRM requires this */
		drm {
			compatible = "nvidia,tegra114-drm";
			status = "okay";
		};
	};
};
```

### Step 3.3: Configuration for Basic Boot

```bash
# Start with 3.18 config
cp /path/to/kernel-3.18/.config .config
make ARCH=arm oldconfig

# Or use our prepared config
make ARCH=arm lineageos_mojo_4.4_defconfig
```

Key changes:

```kconfig
CONFIG_LOCALVERSION="-android9-step3"

# Android 9 requirements
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"

# eBPF support
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_EVENTS=y
CONFIG_CGROUP_BPF=y

# DRM (disable old display for now)
# CONFIG_TEGRA_DC is not set
CONFIG_DRM=y
CONFIG_DRM_TEGRA=y
CONFIG_DRM_PANEL=y

# Temporarily disable audio to simplify
# CONFIG_SND_SOC_TEGRA is not set

# ION (still needed for Android 9)
CONFIG_ION=y
CONFIG_ION_TEGRA=y
```

### Step 3.4: Build Basic Kernel

```bash
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

make -j$(nproc) zImage modules dtbs
```

**Expected**: Should build successfully, but display/audio won't work yet.

### Step 3.5: Test Basic Boot

```bash
# Create boot image
cat arch/arm/boot/zImage arch/arm/boot/dts/tegra114-mojo.dtb > /tmp/zImage-dtb
mkbootimg --kernel /tmp/zImage-dtb --ramdisk ramdisk.img \
    --cmdline "console=ttyS0,115200n8" --output boot-4.4-phase1.img

# Flash and test
fastboot flash boot boot-4.4-phase1.img
fastboot reboot
```

**Success Criteria**:
- [ ] Kernel boots
- [ ] Serial console works
- [ ] ADB accessible
- [ ] Storage detected
- [ ] No kernel panics

Display won't work - that's expected! We'll fix it in Phase 2.

---

## Phase 2: DRM/KMS Display

### Step 3.6: Understanding DRM/KMS

The old Tegra DC driver is replaced by DRM (Direct Rendering Manager):

**Components**:
- **CRTC** (Display Controller): Controls timing and scanout
- **Encoder** (HDMI): Converts pixels to HDMI signal
- **Connector** (HDMI port): Physical connection

**Device Tree Changes**:

```dts
host1x@50000000 {
	compatible = "nvidia,tegra114-host1x", "simple-bus";

	dc@54200000 {
		compatible = "nvidia,tegra114-dc";
		reg = <0x54200000 0x00040000>;
		interrupts = <GIC_SPI 73 IRQ_TYPE_LEVEL_HIGH>;
		clocks = <&tegra_car TEGRA114_CLK_DISP1>;
		clock-names = "dc";
		resets = <&tegra_car 27>;
		reset-names = "dc";

		nvidia,head = <0>;

		rgb {
			status = "okay";
		};
	};

	hdmi@54280000 {
		compatible = "nvidia,tegra114-hdmi";
		reg = <0x54280000 0x00040000>;
		interrupts = <GIC_SPI 75 IRQ_TYPE_LEVEL_HIGH>;
		clocks = <&tegra_car TEGRA114_CLK_HDMI>,
			 <&tegra_car TEGRA114_CLK_HDMI_AUDIO>;
		clock-names = "hdmi", "hdmi_audio";
		resets = <&tegra_car 51>;
		reset-names = "hdmi";

		status = "okay";

		vdd-supply = <&vdd_hdmi_5v0>;
		pll-supply = <&ldo1_reg>;
		hdmi-supply = <&ldoln_reg>;

		nvidia,ddc-i2c-bus = <&hdmi_ddc>;
		nvidia,hpd-gpio = <&gpio TEGRA_GPIO(N, 7) GPIO_ACTIVE_HIGH>;
	};
};
```

### Step 3.7: Enable DRM in Configuration

```kconfig
# DRM subsystem
CONFIG_DRM=y
CONFIG_DRM_KMS_HELPER=y
CONFIG_DRM_GEM_CMA_HELPER=y
CONFIG_DRM_KMS_CMA_HELPER=y

# Tegra DRM
CONFIG_DRM_TEGRA=y
CONFIG_DRM_TEGRA_STAGING=y
CONFIG_DRM_PANEL_SIMPLE=y

# Framebuffer emulation (for console)
CONFIG_DRM_FBDEV_EMULATION=y

# Disable old DC driver
# CONFIG_TEGRA_DC is not set
# CONFIG_FB_TEGRA is not set
```

### Step 3.8: Build and Test Display

```bash
make -j$(nproc) zImage modules dtbs
# Create boot image and flash
```

**Check DRM**:
```bash
adb shell ls /sys/class/drm/
# Should show: card0, card0-HDMI-A-1

adb shell cat /sys/class/drm/card0/card0-HDMI-A-1/status
# Should show: connected
```

---

## Phase 3: ASoC Audio

### Step 3.9: ASoC Component Framework

Audio subsystem needs updates:

**Old machine driver (3.18)**:
```c
static struct snd_soc_card tegra_rt5640_card = {
	.name = "tegra-rt5640",
	.owner = THIS_MODULE,
	.dai_link = &tegra_rt5640_dai,
	.num_links = 1,
	.dapm_widgets = tegra_rt5640_dapm_widgets,
	.num_dapm_widgets = ARRAY_SIZE(tegra_rt5640_dapm_widgets),
};
```

**New machine driver (4.4 with components)**:
```c
static struct snd_soc_card tegra_rt5640_card = {
	.name = "tegra-rt5640",
	.owner = THIS_MODULE,
	.dai_link = &tegra_rt5640_dai,
	.num_links = 1,
	.controls = tegra_rt5640_controls,
	.num_controls = ARRAY_SIZE(tegra_rt5640_controls),
	.dapm_widgets = tegra_rt5640_dapm_widgets,
	.num_dapm_widgets = ARRAY_SIZE(tegra_rt5640_dapm_widgets),
	.dapm_routes = tegra_rt5640_audio_map,
	.num_dapm_routes = ARRAY_SIZE(tegra_rt5640_audio_map),
	.fully_routed = true,
};
```

### Step 3.10: Audio Device Tree

```dts
sound {
	compatible = "nvidia,tegra-audio-rt5640-mojo",
		     "nvidia,tegra-audio-rt5640";
	nvidia,model = "NVIDIA Tegra Mojo RT5640";

	nvidia,audio-routing =
		"Headphones", "HPOL",
		"Headphones", "HPOR",
		"Speakers", "SPORP",
		"Speakers", "SPORN",
		"Speakers", "SPOLP",
		"Speakers", "SPOLN",
		"IN1P", "Mic Jack",
		"IN1N", "Mic Jack";

	nvidia,i2s-controller = <&tegra_i2s1>;
	nvidia,audio-codec = <&rt5639>;

	clocks = <&tegra_car TEGRA114_CLK_PLL_A>,
		 <&tegra_car TEGRA114_CLK_PLL_A_OUT0>,
		 <&tegra_car TEGRA114_CLK_EXTERN1>;
	clock-names = "pll_a", "pll_a_out0", "mclk";

	nvidia,hp-det-gpios = <&gpio TEGRA_GPIO(R, 7) GPIO_ACTIVE_HIGH>;
};
```

### Step 3.11: Audio Configuration

```kconfig
# ASoC
CONFIG_SND_SOC=y
CONFIG_SND_SOC_TEGRA=y
CONFIG_SND_SOC_TEGRA114_I2S=y

# RT5640 codec
CONFIG_SND_SOC_RT5640=y

# HDMI audio
CONFIG_SND_SOC_HDMI_CODEC=y
```

---

## Phase 4: GPIO Descriptor Migration

### Step 3.12: GPIO API Changes

Every GPIO user needs updating:

**Old style (3.18)**:
```c
#include <linux/gpio.h>

int gpio_num = TEGRA_GPIO_PK6;
gpio_request(gpio_num, "hdmi-enable");
gpio_direction_output(gpio_num, 1);
gpio_set_value(gpio_num, 1);
gpio_free(gpio_num);
```

**New style (4.4 - descriptor-based)**:
```c
#include <linux/gpio/consumer.h>

struct gpio_desc *enable_gpio;
enable_gpio = devm_gpiod_get(&pdev->dev, "hdmi-enable", GPIOD_OUT_HIGH);
if (IS_ERR(enable_gpio))
	return PTR_ERR(enable_gpio);

gpiod_set_value(enable_gpio, 1);
// No need to free with devm_
```

**Device tree**:
```dts
hdmi@54280000 {
	hdmi-enable-gpios = <&gpio TEGRA_GPIO(K, 6) GPIO_ACTIVE_HIGH>;
};
```

### Step 3.13: Update All GPIO Users

Common GPIO users in MOJO:
1. HDMI enable (PK6)
2. SD card detect (PV2)
3. Power button (PQ0)
4. Sensor interrupts (PR3, PO4)
5. WiFi/BT controls (PCC5, PX7, PR1, etc.)

Each driver accessing these needs updating to GPIO descriptors.

---

## Full Configuration for 4.4

### Step 3.14: Complete Kernel Config

```kconfig
# Version
CONFIG_LOCALVERSION="-android9-step3"

# Android 9 features
CONFIG_ANDROID=y
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"
CONFIG_ASHMEM=y

# eBPF
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_EVENTS=y
CONFIG_CGROUP_BPF=y
CONFIG_NETFILTER_XT_MATCH_BPF=y

# Namespaces (Android 9 requirement)
CONFIG_NAMESPACES=y
CONFIG_UTS_NS=y
CONFIG_IPC_NS=y
CONFIG_USER_NS=y
CONFIG_PID_NS=y
CONFIG_NET_NS=y

# Cgroups
CONFIG_CGROUPS=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_PIDS=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CPUSETS=y
CONFIG_CGROUP_CPUACCT=y
CONFIG_MEMCG=y
CONFIG_MEMCG_SWAP=y
CONFIG_CGROUP_SCHED=y
CONFIG_BLK_CGROUP=y

# Security
CONFIG_SECCOMP=y
CONFIG_SECCOMP_FILTER=y
CONFIG_SECURITY=y
CONFIG_SECURITY_NETWORK=y
CONFIG_SECURITY_PATH=y
CONFIG_SECURITY_SELINUX=y
CONFIG_DEFAULT_SECURITY_SELINUX=y

# Storage
CONFIG_DM_CRYPT=y
CONFIG_DM_VERITY=y
CONFIG_EXT4_ENCRYPTION=y
CONFIG_F2FS_FS=y
CONFIG_F2FS_FS_ENCRYPTION=y

# DRM Display
CONFIG_DRM=y
CONFIG_DRM_TEGRA=y
CONFIG_DRM_PANEL_SIMPLE=y

# Audio
CONFIG_SND_SOC_TEGRA=y
CONFIG_SND_SOC_RT5640=y

# ION (still needed for Android 9)
CONFIG_ION=y
CONFIG_ION_TEGRA=y
```

---

## Testing Procedure

### Comprehensive Testing

```bash
# 1. Basic boot
adb shell uname -a
# Should show 4.4.XXX-android9-step3

# 2. Display
adb shell cat /sys/class/drm/card0/card0-HDMI-A-1/status
adb shell cat /sys/class/drm/card0/card0-HDMI-A-1/modes
# Should list supported resolutions

# 3. Audio
adb shell tinymix
# Should show audio controls

# 4. Hardware
adb shell cat /proc/meminfo
adb shell cat /proc/cpuinfo
adb shell lsusb
adb shell lsmod

# 5. Android
# Boot to home screen
# Install and run apps
# Check for crashes
```

---

## Common Issues

### Issue 1: DRM Not Working

```bash
# Check DRM driver loaded
adb shell dmesg | grep drm

# Verify device tree
adb shell ls /proc/device-tree/host1x*/

# Check regulators for display
adb shell cat /sys/kernel/debug/regulator/regulator_summary | grep hdmi
```

### Issue 2: No Audio

```bash
# Check ASoC registration
adb shell dmesg | grep -i "asoc\|rt5640"

# Verify I2C codec detected
adb shell i2cdetect -y 0

# Check sound card
adb shell cat /proc/asound/cards
```

### Issue 3: GPIO Errors

```bash
# Old GPIO numbers don't work in 4.4
# Must use GPIO descriptors
# Check device tree has all GPIO properties
```

---

## Estimated Effort

| Task | Time |
|------|------|
| Setup and basic boot | 6-8 hours |
| DRM/KMS display port | 16-24 hours |
| ASoC audio port | 12-16 hours |
| GPIO descriptor migration | 8-12 hours |
| Testing and debugging | 16-24 hours |
| **Total** | **58-84 hours (2-3 weeks)** |

---

## Verification Checklist

- [ ] Kernel 4.4 boots
- [ ] DRM display working (HDMI output)
- [ ] Framebuffer console visible
- [ ] Audio playback works
- [ ] All GPIOs via descriptors
- [ ] Storage functional
- [ ] WiFi/BT working
- [ ] Sensors accessible
- [ ] Android boots completely
- [ ] Apps run without issues
- [ ] eBPF functional
- [ ] Performance good

---

## Next Steps

Once 4.4 is stable:

1. Review: `STEP4_4.4_TO_4.9.md`
2. Download kernel 4.9 sources
3. Final refinements for Android 10/11
4. Complete the journey!

---

**Status**: Detailed guide provided
**Difficulty**: HARD (most challenging step)
**Prerequisites**: Kernel 3.18 stable
**Next Step**: STEP4_4.4_TO_4.9.md
