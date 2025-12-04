#!/bin/bash
SECONDS=0
set -e

# Set kernel path
KERNEL_PATH=out/arch/arm64/boot

# Set kernel name
BUILD_TYPE="SUKISU"
DATE="$(TZ=Asia/Jakarta date +%Y%m%d%H%M%S)"
KERNEL_NAME="SukiSuA16${BUILD_TYPE}-${DATE}.zip"

# Clone SukiSU repo
if [ ! -d "KernelSU" ]; then curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-main; fi

function KERNEL_COMPILE() {
	if [ "$1" == "install" ]; then
		# Download required package
		sudo apt update -y && sudo apt upgrade -y && sudo apt install nano bc ccache bison ca-certificates curl flex gcc git libc6-dev libssl-dev openssl python-is-python3 ssh wget zip zstd sudo make clang gcc-arm-linux-gnueabi software-properties-common build-essential libarchive-tools gcc-aarch64-linux-gnu -y && sudo apt install build-essential -y && sudo apt install libssl-dev libffi-dev libncurses5-dev zlib1g zlib1g-dev libreadline-dev libbz2-dev libsqlite3-dev make gcc -y && sudo apt install pigz -y && sudo apt install python2 -y && sudo apt install python3 -y && sudo apt install cpio -y && sudo apt install lld -y && sudo apt install llvm -y && sudo apt-get install g++-aarch64-linux-gnu -y && sudo apt install libelf-dev -y && sudo apt install neofetch -y && neofetch
	fi

	# Set environment variables
	export USE_CCACHE=1
	export KBUILD_BUILD_HOST=ghthub
	export KBUILD_BUILD_USER=Jawa

	# Create output directory and do a clean build
	rm -rf out && mkdir -p out

	# Download clang if not present
	git clone --depth=1 https://gitlab.com/sarthakroy2002/android_prebuilts_clang_host_linux-x86_clang-r437112b clang
    git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 los-4.9-64
    git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 los-4.9-32

	# Add clang bin directory to PATH
	export PATH="${PWD}/clang/bin:${PATH}:${PWD}/los-4.9-32/bin:${PATH}:${PWD}/los-4.9-64/bin:${PATH}"

	# Make the config
	make O=out ARCH=arm64 RMX2020_defconfig

	# Build the kernel with clang and log output
	make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC="clang" \
                      CLANG_TRIPLE=aarch64-linux-gnu- \
                      CROSS_COMPILE="${PWD}/los-4.9-64/bin/aarch64-linux-android-" \
                      CROSS_COMPILE_ARM32="${PWD}/los-4.9-32/bin/arm-linux-androideabi-" \
                      CONFIG_NO_ERROR_ON_MISMATCH=y
}

function KERNEL_PATCH() {
    # Simple Kernel Patcher Script
    set -e  # Exit immediately if any command fails
    echo "Starting kernel patching process..."

    # Change to kernel directory
    cd ${KERNEL_PATH} || {
        echo "Error: Failed to enter kernel directory!" >&2
        exit 1
    }

    # Download patcher
    echo "Downloading patcher..."
    
    wget -q https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/download/0.12.2/patch_linux || {
        echo "Error: Failed to download patcher!" >&2
        exit 1
    }

    # Make patcher executable
    chmod +x patch_linux

    # Execute patcher
    echo "Patching kernel image..."

    ./patch_linux || {
        echo "Error: Patching failed!" >&2
        exit 1
    }

    # Combine all dtb
    find dts -name '*.dtb' -exec cat {} + >dtb

    # Replace original image
    if [ -f "oImage" ]; then
		rm -rf Image*
        mv oImage Image
        gzip -c Image > Image.gz
		cat Image.gz dtb > Image.gz-dtb
    fi

    echo "Kernel patching completed successfully!"
    cd - >/dev/null
}

function KERNEL_RESULT() {
	# Check is build is successful
	if [ ! -f ${KERNEL_PATH}/Image ]; then
		exit 1
	fi

	# Apply kpm
	KERNEL_PATCH

	# Create anykernel
	rm -rf anykernel
	git clone https://github.com/muhammmadnantaa-hub/AnyKernel.git anykernel

	# Copying image
	cp ${KERNEL_PATH}/Image.gz-dtb anykernel/

	# Created zip kernel
	cd anykernel && zip -r9 "${KERNEL_NAME}" *

	# Upload kernel
	RESPONSE=$(curl -s -F "file=@${KERNEL_NAME}" "https://store1.gofile.io/contents/uploadfile" \
	|| curl -s -F "file=@${KERNEL_NAME}" "https://store2.gofile.io/contents/uploadfile")
	DOWNLOAD_LINK=$(echo "$RESPONSE" | grep -oP '"downloadPage":"\K[^"]+')
	echo -e "\nDownload link: $DOWNLOAD_LINK"
}

# Run functions
KERNEL_COMPILE "$1"
KERNEL_RESULT
echo -e "Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !\n"
