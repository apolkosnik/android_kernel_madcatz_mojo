# MadCatz MOJO Incremental Kernel Upgrade

## Quick Start

This repository contains everything you need to upgrade the MadCatz MOJO kernel from **Linux 3.4.57** to **Linux 4.9** through incremental steps, supporting up to **Android 11 (LineageOS 18)**.

## Current Status

- ✅ **Kernel 3.4.57** - Android 6/7 support (WORKING)
- 📦 **Kernel 3.10** - Android 8 support (READY TO BUILD)
- 📋 **Kernel 3.18** - Android 8.1 support (GUIDE PROVIDED)
- 📋 **Kernel 4.4** - Android 9 support (GUIDE PROVIDED)
- 📋 **Kernel 4.9** - Android 10/11 support (GUIDE PROVIDED)

## Why Incremental Upgrade?

Rather than jumping directly from 3.4 → 4.9 (which is very difficult), this approach breaks it into manageable steps:

1. **3.4.57 → 3.10** (1-2 weeks) - Easy, minimal API changes
2. **3.10 → 3.18** (2-3 weeks) - Device tree migration
3. **3.18 → 4.4** (2-3 weeks) - Major driver updates
4. **4.9 → 4.9** (1-2 weeks) - Final refinements

**Total Time**: 6-10 weeks (vs. 4-7 weeks for direct upgrade, but MUCH easier)

## Files Included

### Documentation
- **INCREMENTAL_UPGRADE_PLAN.md** - Overview of all 4 steps
- **STEP1_3.4_TO_3.10.md** - Detailed guide for Step 1
- **STEP2_3.10_TO_3.18.md** - Detailed guide for Step 2 *(to be created)*
- **STEP3_3.18_TO_4.4.md** - Detailed guide for Step 3 *(to be created)*
- **STEP4_4.4_TO_4.9.md** - Detailed guide for Step 4 *(to be created)*
- **KERNEL_UPGRADE_GUIDE.md** - Direct upgrade guide (alternative approach)

### Configuration Files
- `arch/arm/configs/lineageos_mojo_defconfig` - Current (3.4.57, Android 7)
- `arch/arm/configs/lineageos_mojo_3.10_defconfig` - For kernel 3.10 (Android 8)
- `arch/arm/configs/lineageos_mojo_android10_defconfig` - For kernel 4.9 (Android 10/11)

### Device Trees
- `arch/arm/boot/dts/tegra114-mojo.dts` - Current (minimal)
- `arch/arm/boot/dts/tegra114-mojo-android10.dts` - Complete DT for 4.9+

### Tools
- **UPGRADE_HELPER.sh** - Automation script for builds and setup

## Quick Start Guide

### Step 0: Check Dependencies

```bash
./UPGRADE_HELPER.sh check-deps
```

This checks for:
- ARM cross-compiler (`arm-linux-gnueabihf-gcc`)
- Device tree compiler (`dtc`)
- Android boot image tools (`mkbootimg`)
- Build tools (`make`, `bc`, `bison`, `flex`)

Install missing dependencies:
```bash
# On Ubuntu/Debian
sudo apt-get install gcc-arm-linux-gnueabihf device-tree-compiler \
    bc bison flex libssl-dev
pip install mkbootimg
```

### Step 1: Download Kernel Sources

```bash
./UPGRADE_HELPER.sh download-sources
```

This shows commands to download all kernel versions. Start with 3.10:

```bash
# Recommended: Android Tegra kernel
git clone --depth=1 --branch android-tegra-3.10 \
    https://android.googlesource.com/kernel/tegra kernel-3.10
```

### Step 2: Set Up Kernel 3.10

```bash
./UPGRADE_HELPER.sh setup-3.10 ./kernel-3.10
```

This automatically:
- Copies MOJO configuration
- Copies board files (for 3.x kernels)
- Copies device tree
- Updates Makefiles

### Step 3: Build Kernel 3.10

```bash
./UPGRADE_HELPER.sh build ./kernel-3.10
```

Or manually:
```bash
cd kernel-3.10
export ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
make lineageos_mojo_3.10_defconfig
make -j$(nproc) zImage modules dtbs
```

### Step 4: Create Boot Image

```bash
./UPGRADE_HELPER.sh create-boot-img ./kernel-3.10
```

### Step 5: Flash and Test

```bash
adb reboot bootloader
fastboot flash boot boot-mojo-kernel-3.10.img
fastboot reboot
```

### Step 6: Validate

Follow the testing checklist in `STEP1_3.4_TO_3.10.md`:
- [ ] Kernel boots
- [ ] Storage works (eMMC, SD, WiFi SDIO)
- [ ] Display outputs (HDMI)
- [ ] WiFi/Bluetooth functional
- [ ] Audio works
- [ ] All sensors detected
- [ ] Android boots completely

### Step 7: Repeat for Next Version

Once 3.10 is stable:
1. Read `STEP2_3.10_TO_3.18.md`
2. Download kernel 3.18 sources
3. Run `./UPGRADE_HELPER.sh setup-3.18 ./kernel-3.18`
4. Build, flash, test
5. Continue to 4.4, then 4.9

## Android Version Support

| Kernel | Android | LineageOS | Status |
|--------|---------|-----------|--------|
| 3.4.57 | 6-7 | 13-14 | ✅ WORKING |
| 3.10 | 8.0 | 15.x | 📦 READY |
| 3.18 | 8.1 | 15.x | 📋 PLANNED |
| 4.4 | 9.0 | 16.x | 📋 PLANNED |
| 4.9 | 10-11 | 17-18 | 📋 PLANNED |

## Troubleshooting

### Build Fails
```bash
# Clean and retry
cd kernel-X.X
make mrproper
make lineageos_mojo_X.X_defconfig
make -j$(nproc)
```

### Kernel Doesn't Boot
1. Check serial console output
2. Verify boot image created correctly
3. Try permissive SELinux: add `androidboot.selinux=permissive` to cmdline

### WiFi/Bluetooth Not Working
1. Check kernel modules loaded: `adb shell lsmod`
2. Verify firmware in `/vendor/firmware/brcm/`
3. Check dmesg for errors

## Detailed Guides

Each step has a comprehensive guide with:
- Download instructions
- Configuration changes needed
- API migration information
- Build instructions
- Testing procedures
- Common issues and solutions
- Estimated time and effort

**Start with**: `STEP1_3.4_TO_3.10.md`

## Helper Script Usage

```bash
# Check what you need to install
./UPGRADE_HELPER.sh check-deps

# See download commands
./UPGRADE_HELPER.sh download-sources

# Set up a kernel version
./UPGRADE_HELPER.sh setup-3.10 /path/to/kernel-3.10
./UPGRADE_HELPER.sh setup-3.18 /path/to/kernel-3.18
./UPGRADE_HELPER.sh setup-4.4 /path/to/kernel-4.4
./UPGRADE_HELPER.sh setup-4.9 /path/to/kernel-4.9

# Build kernel
./UPGRADE_HELPER.sh build /path/to/kernel-X.X

# Create boot image
./UPGRADE_HELPER.sh create-boot-img /path/to/kernel-X.X
```

## Progress Tracking

Keep track of your progress:

- [ ] **Step 1 (3.4 → 3.10)**: _______
- [ ] **Step 2 (3.10 → 3.18)**: _______
- [ ] **Step 3 (3.18 → 4.4)**: _______
- [ ] **Step 4 (4.4 → 4.9)**: _______

## Need Help?

1. Check the detailed step guide (STEPX_X.X_TO_X.X.md)
2. Review common issues in each guide
3. Check kernel dmesg: `adb shell dmesg | grep -i error`
4. Post on XDA Developers MadCatz MOJO forum
5. Create issue on GitHub repository

## Alternative Approach

If you prefer a direct upgrade (harder but faster if successful):
- See **KERNEL_UPGRADE_GUIDE.md** for direct 3.4 → 4.9 upgrade
- Uses the comprehensive device tree in `arch/arm/boot/dts/tegra114-mojo-android10.dts`
- Requires more kernel development experience
- Estimated 4-7 weeks (but higher failure risk)

## Contributing

Successfully completed a step? Please:
1. Document any issues you encountered
2. Share your solutions
3. Update the guides with your findings
4. Help others on the forums

## License

GPL-2.0 (matching Linux kernel license)

---

**Start here**: `STEP1_3.4_TO_3.10.md`

**Good luck with your upgrade!** 🚀
