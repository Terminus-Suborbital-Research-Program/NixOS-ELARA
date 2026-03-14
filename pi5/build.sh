#!/usr/bin/env bash
set -euo pipefail

# Usage: ./build.sh [output-dir]
OUT_DIR=${1:-out}
mkdir -p "$OUT_DIR"

# Run the build inside a Nix shell providing required tools and aarch64 cross-compiler.
nix-shell -p git make bc bison flex openssl ncurses 'pkgsCross.aarch64-multiplatform.gcc' --run "\
  rm -rf linux tn-rpi-camera-driver; \
  git clone --depth=1 -b rpi-6.12.y https://github.com/raspberrypi/linux linux; \
  git clone --depth=1 -b tn_rpi_kernel-6.12 https://github.com/TechNexion-Vision/tn-rpi-camera-driver.git tn-rpi-camera-driver; \
  cp -rv tn-rpi-camera-driver/drivers/media/i2c/* linux/drivers/media/i2c/; \
  cp -rv tn-rpi-camera-driver/arch/arm64/boot/dts/overlays/* linux/arch/arm64/boot/dts/overlays/; \
  cd linux; export KERNEL=kernel_2712; make distclean; make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2712_defconfig; \
  # Optional: allow interactive menuconfig; continue if exited
  make menuconfig || true; \
  mkdir -p modules; export MODULE_PATH=./modules; make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION='-tn-raspi' -j\$(nproc) Image.gz modules dtbs; \
  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=\$MODULE_PATH modules_install; \
  mkdir -p \$PWD/../$OUT_DIR/boot \$PWD/../$OUT_DIR/modules; \
  cp arch/arm64/boot/Image.gz ../$OUT_DIR/boot/\$KERNEL.img; \
  cp arch/arm64/boot/dts/broadcom/*.dtb ../$OUT_DIR/boot/; \
  mkdir -p ../$OUT_DIR/boot/overlays; cp arch/arm64/boot/dts/overlays/*.dtb* ../$OUT_DIR/boot/overlays/ 2>/dev/null || true; \
  cp arch/arm64/boot/dts/overlays/README ../$OUT_DIR/boot/overlays/ 2>/dev/null || true; \
  cp -ra modules/lib/modules/\$(make kernelversion)-v8-16k-tn-raspi/ ../$OUT_DIR/modules/; \
"

echo "Artifacts placed in: $OUT_DIR"
