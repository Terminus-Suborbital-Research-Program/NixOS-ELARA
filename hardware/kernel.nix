{ config, pkgs, lib, ... }:

let
  kernelBundle = pkgs.linuxAndFirmware.v6_12_34;

  tnDriver = pkgs.fetchFromGitHub {
    owner = "TechNexion-Vision";
    repo = "tn-rpi-camera-driver";
    rev = "tn_rpi_kernel-6.12";
    hash = "sha256-jBEy7JXL/ibqDQDfGDOCAMDSQAPgRDZhjal5zAC3zVE=";
  };

  linuxPackages_rpi5_tevs =
    kernelBundle.linuxPackages_rpi5.extend (_final: prev: {
      kernel = prev.kernel.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          echo "Injecting TechNexion TEVS sources"

          # Copy the TEVS driver directory only
          rm -rf drivers/media/i2c/tevs
          cp -rv ${tnDriver}/drivers/media/i2c/tevs drivers/media/i2c/

          # Copy only the TEVS overlay source(s), not vendor Makefile/Kconfig
          if [ -f ${tnDriver}/arch/arm64/boot/dts/overlays/tevs-rpi22.dts ]; then
            cp -v ${tnDriver}/arch/arm64/boot/dts/overlays/tevs-rpi22.dts \
              arch/arm64/boot/dts/overlays/
          fi
          if [ -f ${tnDriver}/arch/arm64/boot/dts/overlays/tevs-rpi15.dts ]; then
            cp -v ${tnDriver}/arch/arm64/boot/dts/overlays/tevs-rpi15.dts \
              arch/arm64/boot/dts/overlays/
          fi

          # Hook the driver into the existing media/i2c Makefile
          grep -q 'obj-$(CONFIG_VIDEO_TEVS) += tevs/' drivers/media/i2c/Makefile || \
            printf '\nobj-$(CONFIG_VIDEO_TEVS) += tevs/\n' >> drivers/media/i2c/Makefile

          # Add the Kconfig entry without replacing the whole file
          if ! grep -q '^config VIDEO_TEVS$' drivers/media/i2c/Kconfig; then
            cat >> /tmp/tevs.kconfig <<'EOF'
config VIDEO_TEVS
	tristate "TechNexion TEVS sensor support"
	depends on OF
	depends on GPIOLIB && VIDEO_DEV && I2C
	select MEDIA_CONTROLLER
	select VIDEO_V4L2_SUBDEV_API
	select V4L2_FWNODE
	help
	  This is a Video4Linux2 sensor driver for the TechNexion
	  TEVS camera sensor with a MIPI CSI-2 interface.

EOF
            sed -i '/^source "drivers\/media\/i2c\/ccs\/Kconfig"/e cat /tmp/tevs.kconfig' \
              drivers/media/i2c/Kconfig
          fi

          # Register only the TEVS overlays that actually exist
          if [ -f arch/arm64/boot/dts/overlays/tevs-rpi22.dts ]; then
            grep -q 'tevs-rpi22.dtbo' arch/arm64/boot/dts/overlays/Makefile || \
              sed -i '/^targets += dtbs dtbs_install/i\	tevs-rpi22.dtbo \\' \
                arch/arm64/boot/dts/overlays/Makefile
          fi

          if [ -f arch/arm64/boot/dts/overlays/tevs-rpi15.dts ]; then
            grep -q 'tevs-rpi15.dtbo' arch/arm64/boot/dts/overlays/Makefile || \
              sed -i '/^targets += dtbs dtbs_install/i\	tevs-rpi15.dtbo \\' \
                arch/arm64/boot/dts/overlays/Makefile
          fi
        '';

        extraStructuredConfig = with lib.kernel; {
          VIDEO_TEVS = module;
        };

        env = (old.env or {}) // {
          KCONFIG_MODE = "alldefconfig";
        };
      });
    });
in
{
  boot.loader.raspberryPi.firmwarePackage = kernelBundle.raspberrypifw;
  boot.kernelPackages = linuxPackages_rpi5_tevs;

  boot.extraModprobeConfig = ''
    softdep tevs pre: gpio_pca953x
  '';

  nixpkgs.overlays = [
    (final: prev: {
      inherit (kernelBundle) raspberrypiWirelessFirmware;
      inherit (kernelBundle) raspberrypifw;
    })
  ];
}