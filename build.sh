#!/bin/bash
SECONDS=0

# Set kernel name
BUILD_TYPE="KSu"
DATE="$(TZ=Asia/Jakarta date +%Y%m%d%H%M%S)"
KERNEL_NAME="Rk${BUILD_TYPE}-${DATE}.zip"

# Clone SukiSU repo
if [ ! -d "KernelSU" ]; then curl -LSs "https://raw.githubusercontent.com/rsuntk/KernelSU/main/kernel/setup.sh" | bash -s susfs-rksu-master; fi

function KERNEL_COMPILE() {
	# Set environment variables
	export USE_CCACHE=1
	export KBUILD_BUILD_HOST=#github
	export KBUILD_BUILD_USER=f1sdcard

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

function KERNEL_RESULT() {
	# Create anykernel
	rm -rf anykernel
	git clone https://github.com/muhammmadnantaa-hub/AnyKernel.git anykernel

	# Copying image
	cp out/arch/arm64/boot/Image.gz-dtb anykernel

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
