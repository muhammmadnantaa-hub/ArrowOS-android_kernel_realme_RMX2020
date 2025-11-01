#!/bin/bash

# Set kernel name
BUILD_FOR="A13"
DATE="$(TZ=Asia/India date +%Y%m%d%H%M%S)"
KERNEL_NAME="SukiSu${BUILD_FOR}-${DATE}.zip"

function compile() 
{
rm -rf AnyKernel
source ~/.bashrc && source ~/.profile
export LC_ALL=C && export USE_CCACHE=1
ccache -M 100G
export ARCH=arm64
export KBUILD_BUILD_HOST=neolit
export KBUILD_BUILD_USER="szyryjn"
git clone --depth=1 https://gitlab.com/sarthakroy2002/android_prebuilts_clang_host_linux-x86_clang-r437112b clang
git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 los-4.9-64
git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 los-4.9-32

make O=out ARCH=arm64 RMX2020_defconfig

PATH="${PWD}/clang/bin:${PATH}:${PWD}/los-4.9-32/bin:${PATH}:${PWD}/los-4.9-64/bin:${PATH}" \
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC="clang" \
                      CLANG_TRIPLE=aarch64-linux-gnu- \
                      CROSS_COMPILE="${PWD}/los-4.9-64/bin/aarch64-linux-android-" \
                      CROSS_COMPILE_ARM32="${PWD}/los-4.9-32/bin/arm-linux-androideabi-" \
                      CONFIG_NO_ERROR_ON_MISMATCH=y
}

function extract_image_gz_dtb()
{
    echo "[Image.gz-dtb extractor] Getting DTB offset from Image.gz-dtb..."
    OFFSET=$(binwalk "Image.gz-dtb" | grep "Flattened device tree" | awk '{print $1}')
    if [ -z "$OFFSET" ]; then
      echo "[Image.gz-dtb extractor] Could not find DTB in Image.gz-dtb"
      exit 1
    fi
    echo "[Image.gz-dtb extractor] Found DTB offset at $OFFSET"

    echo "[Image.gz-dtb extractor] Extracting kernel (gzip part)..."
    dd if="Image.gz-dtb" of="Image.gz" bs=1 count="$OFFSET" status=none

    echo "[Image.gz-dtb extractor] Extracting DTB..."
    dd if="Image.gz-dtb" of="dtb" bs=1 skip="$OFFSET" status=none

    echo "[Image.gz-dtb extractor] Decompressing kernel gzip to raw Image..."
    gzip -cd "Image.gz" > "Image"

    echo "[Image.gz-dtb extractor] Done"
    rm -rf Image.gz Image.gz-dtb
}

function install_kernel_patch()
{
    mkdir KernelPatchTools
    cd KernelPatchTools
    curl -L -O https://github.com/bmax121/KernelPatch/releases/download/0.11.3/kptools-linux
    curl -L -O https://github.com/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/download/0.12.0/kpimg
    chmod +x ./kptools-linux
    if [ -e "./kpimg-android" ]; then
        mv ./kpimg-android ./kpimg
    fi
    cd ..
}

function kernel_patching()
{
    ../KernelPatchTools/kptools-linux -p -s "RainyPatch@111" -i ./Image -k ../KernelPatchTools/kpimg -o ./oImage
    rm -rf ./Image
    mv ./oImage ./Image
}

function zipping()
{
    rm -rf AnyKernel
    git clone --depth=1 -b RMX2020-SUKI https://github.com/szyryjn/AnyKernel3.git AnyKernel
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
    if [ ! -d "KernelPatchTools" ]; then
        echo "KernelPatch tools does not exist. Installing"
        install_kernel_patch
        echo "KernelPatch tools installed!"
    fi
    cd AnyKernel
    extract_image_gz_dtb
    kernel_patching
    gzip -c Image > Image.gz
    cat Image.gz dtb > Image.gz-dtb
    rm -rf Image Image.gz dtb
    zip -r9 "$KERNEL_NAME" *
}

compile
zipping
