````markdown
The Pi5 needs to  the linux kernel from source to get access to the technexion camera modules.


```
$ sudo apt install -y git bc bison flex libssl-dev make libc6-dev libncurses5-dev

# Install the 64-bit toolchain for a 64-bit kernel
$ sudo apt install -y crossbuild-essential-arm64
```

```
# raspberrypi linux kerbel
$ git clone --depth=1 -b rpi-6.12.y https://github.com/raspberrypi/linux

# technexion rpi camera driver
$ git clone --depth=1 -b tn_rpi_kernel-6.12 https://github.com/TechNexion-Vision/tn-rpi-camera-driver.git
```

```
$ cp -rv tn-rpi-camera-driver/drivers/media/i2c/* linux/drivers/media/i2c/
$ cp -rv tn-rpi-camera-driver/arch/arm64/boot/dts/overlays/* linux/arch/arm64/boot/dts/overlays/
```

```
$ cd linux
$ export KERNEL=kernel_2712

# default configuration
$ make distclean
$ make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2712_defconfig
```

```

# config camera
$ make menuconfig
# -> Device Drivers
#   -> Multimedia support
#     -> Media ancillary drivers
#       -> Camera sensor devices
#         -> TechNexion TEVS sensor support
#            Set "VIDEO_TEVS" to module,
#            Press "m", save to original name (.config) and exit

# build kernel
$ mkdir -p modules
$ export MODULE_PATH=./modules
$ make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION="-tn-raspi" -j$(nproc) Image.gz modules dtbs
$ sudo make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=$MODULE_PATH modules_install
```

```
$ sudo cp arch/arm64/boot/Image.gz /media/$(users)/bootfs/$KERNEL.img
$ sudo cp arch/arm64/boot/dts/broadcom/*.dtb /media/$(users)/bootfs
$ sudo cp arch/arm64/boot/dts/overlays/*.dtb* /media/$(users)/bootfs/overlays/
$ sudo cp arch/arm64/boot/dts/overlays/README /media/$(users)/bootfs/overlays/

# you can use "make kernelversion" to check kernel version
$ sudo cp -ra modules/lib/modules/$(make kernelversion)-v8-16k-tn-raspi/ /media/$(users)/rootfs/lib/modules/.
$ sync
```

```
$ sudo nano /boot/firmware/config.txt

# Automatically load overlays for detected cameras
camera_auto_detect=0
dtoverlay=tevs-rpi22,cam0
dtoverlay=tevs-rpi22
```

```
$ sudo touch /etc/modprobe.d/tevs.conf
$ sudo nano /etc/modprobe.d/tevs.conf
> softdep tevs pre: gpio_pca953x
```

````

Nix usage
---------

This repository includes a minimal `flake.nix` and helper scripts to build the kernel artifacts via Nix and create an SD image locally.

- Build kernel artifacts (runs the build inside a Nix environment with the cross-compiler):

```
cd pi5
nix run .#build -- --output out
```

The above places boot files in `out/boot` and kernel modules in `out/modules`.

- Create a partitioned SD image (must be run as root):

```
sudo ./create-image.sh out pi5.img [rootfs.tar]
```

If you already have an SD rootfs, instead copy `out/boot` and the modules under `out/modules` into the existing rootfs.

Notes
- `nix run .#build` provides a reproducible toolchain for building the kernel; the image creation step is performed outside of Nix because it requires privileged host operations (`losetup`, `mkfs`, `mount`).
- If you prefer, you can run `nix run .#image` to get a wrapped script; `sudo` is still required to actually write partitions.
