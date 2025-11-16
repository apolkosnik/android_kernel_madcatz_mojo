#!/bin/bash
#
# MadCatz MOJO Kernel Upgrade Helper Script
# This script helps automate parts of the incremental kernel upgrade process
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_DIR="$(pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

print_error() { print_msg "$RED" "[ERROR] $@"; }
print_success() { print_msg "$GREEN" "[SUCCESS] $@"; }
print_warning() { print_msg "$YELLOW" "[WARNING] $@"; }
print_info() { print_msg "$BLUE" "[INFO] $@"; }

# Show usage
usage() {
    cat <<EOF
Usage: $0 <command> [options]

Commands:
    setup-3.10 <kernel-3.10-dir>    Set up kernel 3.10 with MOJO files
    setup-3.18 <kernel-3.18-dir>    Set up kernel 3.18 with MOJO files
    setup-4.4  <kernel-4.4-dir>     Set up kernel 4.4 with MOJO files
    setup-4.9  <kernel-4.9-dir>     Set up kernel 4.9 with MOJO files

    build <kernel-dir>              Build kernel in specified directory
    create-boot-img <kernel-dir>    Create Android boot image

    check-deps                      Check build dependencies
    download-sources                Show download commands for kernel sources

Examples:
    $0 check-deps
    $0 download-sources
    $0 setup-3.10 /path/to/kernel-3.10
    $0 build /path/to/kernel-3.10

EOF
    exit 1
}

# Check build dependencies
check_dependencies() {
    print_info "Checking build dependencies..."

    local missing_deps=()

    # Check for ARM cross-compiler
    if ! command -v arm-linux-gnueabihf-gcc &> /dev/null; then
        missing_deps+=("arm-linux-gnueabihf-gcc (install: sudo apt-get install gcc-arm-linux-gnueabihf)")
    fi

    # Check for device tree compiler
    if ! command -v dtc &> /dev/null; then
        missing_deps+=("dtc (install: sudo apt-get install device-tree-compiler)")
    fi

    # Check for mkbootimg
    if ! command -v mkbootimg &> /dev/null; then
        missing_deps+=("mkbootimg (install from Android SDK or: pip install mkbootimg)")
    fi

    # Check for build tools
    for tool in make bc bison flex; do
        if ! command -v $tool &> /dev/null; then
            missing_deps+=("$tool (install: sudo apt-get install $tool)")
        fi
    done

    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_success "All dependencies installed!"
        return 0
    else
        print_error "Missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        return 1
    fi
}

# Show download commands
show_download_commands() {
    cat <<EOF
======================================================================
Kernel Source Download Commands
======================================================================

STEP 1: Kernel 3.10
-------------------
# Option A: Android Tegra kernel (Recommended)
git clone --depth=1 --branch android-tegra-3.10 \\
    https://android.googlesource.com/kernel/tegra kernel-3.10

# Option B: Mainline 3.10 LTS
wget https://cdn.kernel.org/pub/linux/kernel/v3.x/linux-3.10.108.tar.xz
tar -xf linux-3.10.108.tar.xz

STEP 2: Kernel 3.18
-------------------
# Option A: Android Tegra kernel
git clone --depth=1 --branch android-tegra-3.18 \\
    https://android.googlesource.com/kernel/tegra kernel-3.18

# Option B: Mainline 3.18 LTS
wget https://cdn.kernel.org/pub/linux/kernel/v3.x/linux-3.18.140.tar.xz
tar -xf linux-3.18.140.tar.xz

STEP 3: Kernel 4.4
------------------
# Option A: Android common kernel
git clone --depth=1 --branch android-4.4-stable \\
    https://android.googlesource.com/kernel/common kernel-4.4

# Option B: Mainline 4.4 LTS
wget https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.4.302.tar.xz
tar -xf linux-4.4.302.tar.xz

STEP 4: Kernel 4.9
------------------
# Option A: Android common kernel (Recommended)
git clone --depth=1 --branch android-4.9-q \\
    https://android.googlesource.com/kernel/common kernel-4.9

# Option B: LineageOS Tegra kernel
git clone --depth=1 \\
    https://github.com/LineageOS/android_kernel_nvidia_linux-4.9_kernel_kernel-4.9

# Option C: Mainline 4.9 LTS
wget https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.9.337.tar.xz
tar -xf linux-4.9.337.tar.xz

======================================================================
After downloading, run:
    $0 setup-<version> /path/to/kernel-<version>

Example:
    $0 setup-3.10 ./kernel-3.10
======================================================================
EOF
}

# Setup kernel directory with MOJO files
setup_kernel() {
    local version=$1
    local kernel_dir=$2

    if [ ! -d "$kernel_dir" ]; then
        print_error "Kernel directory not found: $kernel_dir"
        exit 1
    fi

    print_info "Setting up kernel $version in $kernel_dir..."

    cd "$kernel_dir"

    # Copy configuration
    local config_file="$SCRIPT_DIR/arch/arm/configs/lineageos_mojo_${version}_defconfig"
    if [ -f "$config_file" ]; then
        print_info "Copying defconfig..."
        cp "$config_file" arch/arm/configs/
        print_success "Configuration copied"
    else
        print_warning "Config file not found: $config_file"
    fi

    # For versions before 4.x, copy board files
    if [[ "$version" == "3.10" || "$version" == "3.18" ]]; then
        print_info "Copying board files..."
        if [ -d "$SCRIPT_DIR/arch/arm/mach-tegra" ]; then
            cp "$SCRIPT_DIR"/arch/arm/mach-tegra/board-mojo* arch/arm/mach-tegra/ 2>/dev/null || true
            print_success "Board files copied (if available)"
        fi
    fi

    # Copy device tree
    local dt_source=""
    case "$version" in
        "3.10"|"3.18")
            dt_source="$SCRIPT_DIR/arch/arm/boot/dts/tegra114-mojo.dts"
            ;;
        "4.4"|"4.9")
            dt_source="$SCRIPT_DIR/arch/arm/boot/dts/tegra114-mojo-android10.dts"
            ;;
    esac

    if [ -f "$dt_source" ]; then
        print_info "Copying device tree..."
        cp "$dt_source" arch/arm/boot/dts/
        print_success "Device tree copied"
    fi

    # Add DT to Makefile if not present
    print_info "Updating DT Makefile..."
    local dt_line="dtb-\$(CONFIG_ARCH_TEGRA_114_SOC) += tegra114-mojo"
    if ! grep -q "tegra114-mojo" arch/arm/boot/dts/Makefile 2>/dev/null; then
        echo "$dt_line*.dtb" >> arch/arm/boot/dts/Makefile
        print_success "DT Makefile updated"
    else
        print_info "DT already in Makefile"
    fi

    print_success "Kernel $version setup complete!"
    print_info "Next steps:"
    print_info "  1. cd $kernel_dir"
    print_info "  2. export ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-"
    print_info "  3. make lineageos_mojo_${version}_defconfig"
    print_info "  4. make -j\$(nproc) zImage modules dtbs"

    cd "$CURRENT_DIR"
}

# Build kernel
build_kernel() {
    local kernel_dir=$1

    if [ ! -d "$kernel_dir" ]; then
        print_error "Kernel directory not found: $kernel_dir"
        exit 1
    fi

    cd "$kernel_dir"

    print_info "Building kernel in $kernel_dir..."

    export ARCH=arm
    export CROSS_COMPILE=arm-linux-gnueabihf-

    # Check if .config exists
    if [ ! -f ".config" ]; then
        print_warning "No .config found, running defconfig..."
        local defconfig=$(ls arch/arm/configs/lineageos_mojo_*defconfig 2>/dev/null | head -1)
        if [ -f "$defconfig" ]; then
            make $(basename "$defconfig")
        else
            print_error "No MOJO defconfig found"
            exit 1
        fi
    fi

    # Build
    print_info "Starting build with $(nproc) cores..."
    make -j$(nproc) zImage modules dtbs

    if [ $? -eq 0 ]; then
        print_success "Build completed successfully!"
        print_info "Kernel: arch/arm/boot/zImage"
        print_info "DTB: arch/arm/boot/dts/tegra114-mojo*.dtb"
    else
        print_error "Build failed!"
        exit 1
    fi

    cd "$CURRENT_DIR"
}

# Create boot image
create_boot_image() {
    local kernel_dir=$1

    if [ ! -d "$kernel_dir" ]; then
        print_error "Kernel directory not found: $kernel_dir"
        exit 1
    fi

    cd "$kernel_dir"

    local zimage="arch/arm/boot/zImage"
    local dtb=$(ls arch/arm/boot/dts/tegra114-mojo*.dtb 2>/dev/null | head -1)

    if [ ! -f "$zimage" ]; then
        print_error "Kernel image not found: $zimage"
        print_info "Run: $0 build $kernel_dir"
        exit 1
    fi

    print_info "Creating boot image..."

    # Combine kernel and DTB
    local zimage_dtb="/tmp/zImage-dtb"
    if [ -f "$dtb" ]; then
        print_info "Appending DTB to kernel..."
        cat "$zimage" "$dtb" > "$zimage_dtb"
    else
        print_warning "DTB not found, using kernel without DTB"
        cp "$zimage" "$zimage_dtb"
    fi

    # Check for ramdisk
    local ramdisk="/tmp/ramdisk.img"
    if [ ! -f "$ramdisk" ]; then
        print_warning "Ramdisk not found at $ramdisk"
        print_info "You'll need to provide a ramdisk image"
        print_info "Typically extracted from existing boot.img or built from AOSP"
    fi

    # Create boot image
    local output="boot-mojo-$(basename $kernel_dir).img"
    local cmdline="console=ttyS0,115200n8 androidboot.selinux=permissive"

    if command -v mkbootimg &> /dev/null && [ -f "$ramdisk" ]; then
        mkbootimg \
            --kernel "$zimage_dtb" \
            --ramdisk "$ramdisk" \
            --cmdline "$cmdline" \
            --base 0x10000000 \
            --pagesize 2048 \
            --output "$output"

        print_success "Boot image created: $output"
        print_info "Flash with: fastboot flash boot $output"
    else
        print_warning "mkbootimg not available or ramdisk missing"
        print_info "Kernel+DTB saved to: $zimage_dtb"
        print_info "Manual mkbootimg command:"
        echo "mkbootimg --kernel $zimage_dtb --ramdisk <your-ramdisk.img> \\"
        echo "  --cmdline \"$cmdline\" --base 0x10000000 --pagesize 2048 \\"
        echo "  --output $output"
    fi

    cd "$CURRENT_DIR"
}

# Main script
if [ $# -lt 1 ]; then
    usage
fi

COMMAND=$1
shift

case "$COMMAND" in
    check-deps)
        check_dependencies
        ;;
    download-sources)
        show_download_commands
        ;;
    setup-3.10)
        [ $# -lt 1 ] && usage
        setup_kernel "3.10" "$1"
        ;;
    setup-3.18)
        [ $# -lt 1 ] && usage
        setup_kernel "3.18" "$1"
        ;;
    setup-4.4)
        [ $# -lt 1 ] && usage
        setup_kernel "4.4" "$1"
        ;;
    setup-4.9)
        [ $# -lt 1 ] && usage
        setup_kernel "4.9" "$1"
        ;;
    build)
        [ $# -lt 1 ] && usage
        build_kernel "$1"
        ;;
    create-boot-img)
        [ $# -lt 1 ] && usage
        create_boot_image "$1"
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        usage
        ;;
esac
