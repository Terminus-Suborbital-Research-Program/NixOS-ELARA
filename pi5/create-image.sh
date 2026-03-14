#!/usr/bin/env bash
set -euo pipefail

# Usage: sudo ./create-image.sh <out-dir> <image-file> [rootfs-tar]
# Example: sudo ./create-image.sh out pi5.img my-rootfs.tar

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root. Use sudo." >&2
  exit 1
fi

OUT_DIR=${1:-out}
IMG=${2:-pi5.img}
ROOTFS_TAR=${3:-}
IMG_SIZE_MB=${4:-2048}

if [ ! -d "$OUT_DIR" ]; then
  echo "Output dir $OUT_DIR not found" >&2
  exit 1
fi

echo "Creating ${IMG} (${IMG_SIZE_MB} MB) with boot + root partitions..."
dd if=/dev/zero of="$IMG" bs=1M count="$IMG_SIZE_MB"
parted --script "$IMG" mklabel msdos
parted --script "$IMG" mkpart primary fat32 1MiB 256MiB
parted --script "$IMG" mkpart primary ext4 256MiB 100%

# attach loop device with partition scanning
LOOP=$(losetup --show -fP "$IMG")
BOOT_PART="${LOOP}p1"
ROOT_PART="${LOOP}p2"

echo "Formatting partitions..."
mkfs.vfat "$BOOT_PART"
mkfs.ext4 "$ROOT_PART"

TEMP=$(mktemp -d)
trap 'rm -rf "$TEMP"; losetup -d "$LOOP"' EXIT
mkdir -p "$TEMP/boot" "$TEMP/root"
mount "$BOOT_PART" "$TEMP/boot"
mount "$ROOT_PART" "$TEMP/root"

echo "Copying boot files and modules..."
cp -r "$OUT_DIR/boot/." "$TEMP/boot/"
mkdir -p "$TEMP/root/lib/modules"
cp -r "$OUT_DIR/modules/." "$TEMP/root/lib/modules/"

if [ -n "$ROOTFS_TAR" ]; then
  echo "Extracting rootfs tar to root partition..."
  tar -xpf "$ROOTFS_TAR" -C "$TEMP/root"
fi

sync
umount "$TEMP/boot" "$TEMP/root"
sync

echo "Image $IMG written and ready. Detach loop device: $LOOP"
