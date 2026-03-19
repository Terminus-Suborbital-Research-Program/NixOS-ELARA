{ config, pkgs, lib, ... }:

let
  cfg = config.hardware.tevs;
  kernelSrc = config.boot.kernelPackages.kernel.src;

  defaultTnDriver = pkgs.fetchFromGitHub {
    owner = "TechNexion-Vision";
    repo = "tn-rpi-camera-driver";
    rev = "tn_rpi_kernel-6.12";
    hash = "sha256-jBEy7JXL/ibqDQDfGDOCAMDSQAPgRDZhjal5zAC3zVE=";
  };

  tnDriver = if cfg.src != null then cfg.src else defaultTnDriver;

  tevsKernelOverlay = final: prev: {
    linuxPackages_rpi5 = prev.linuxPackages_rpi5.extend (_final: prevLinux: {
      kernel = prevLinux.kernel.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          echo "Injecting TechNexion TEVS sources"

          rm -rf drivers/media/i2c/tevs
          cp -rv ${tnDriver}/drivers/media/i2c/tevs drivers/media/i2c/

          if [ -f ${tnDriver}/arch/arm64/boot/dts/overlays/tevs-rpi22.dts ]; then
            cp -v ${tnDriver}/arch/arm64/boot/dts/overlays/tevs-rpi22.dts \
              arch/arm64/boot/dts/overlays/
          fi

          if [ -f ${tnDriver}/arch/arm64/boot/dts/overlays/tevs-rpi15.dts ]; then
            cp -v ${tnDriver}/arch/arm64/boot/dts/overlays/tevs-rpi15.dts \
              arch/arm64/boot/dts/overlays/
          fi

          grep -q 'obj-$(CONFIG_VIDEO_TEVS) += tevs/' drivers/media/i2c/Makefile || \
            printf '\nobj-$(CONFIG_VIDEO_TEVS) += tevs/\n' >> drivers/media/i2c/Makefile

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

          if [ -f arch/arm64/boot/dts/overlays/tevs-rpi22.dts ]; then
            grep -q 'tevs-rpi22.dtbo' arch/arm64/boot/dts/overlays/Makefile || \
              sed -i '/^targets += dtbs dtbs_install/i\	tevs-rpi22.dtbo \\\' \
                arch/arm64/boot/dts/overlays/Makefile
          fi

          if [ -f arch/arm64/boot/dts/overlays/tevs-rpi15.dts ]; then
            grep -q 'tevs-rpi15.dtbo' arch/arm64/boot/dts/overlays/Makefile || \
              sed -i '/^targets += dtbs dtbs_install/i\	tevs-rpi15.dtbo \\\' \
                arch/arm64/boot/dts/overlays/Makefile
          fi
        '';

        env = (old.env or {}) // {
          KCONFIG_MODE = "alldefconfig";
        };
      });
    });
  };

  tevsDtbo =
    if cfg.enable then
      pkgs.stdenvNoCC.mkDerivation {
        pname = "tevs-dtbo";
        version = "unstable";
        src = tnDriver;
        nativeBuildInputs = [ pkgs.dtc pkgs.gcc ];
        dontBuild = true;

        installPhase = ''
          runHook preInstall

          mkdir -p "$out/overlays"

          while IFS= read -r dts; do
            name="$(basename "$dts" .dts)"
            output_name="''${name%-overlay}"
            preprocessed="$(mktemp)"

            cpp -nostdinc -undef -P -x assembler-with-cpp \
              -I "${kernelSrc}/include" \
              -I "${kernelSrc}/arch/arm64/boot/dts" \
              -I "${kernelSrc}/arch/arm64/boot/dts/overlays" \
              -I "$src/arch/arm64/boot/dts" \
              -I "$src/arch/arm64/boot/dts/overlays" \
              "$dts" "$preprocessed"

            dtc -@ -I dts -O dtb -o "$out/overlays/$output_name.dtbo" "$preprocessed"
          done < <(find "$src" -type f -name 'tevs-*.dts')

          runHook postInstall
        '';
      }
    else
      null;

  firmwareWithTevs =
    if cfg.enable then
      pkgs.runCommand "rpi-firmware-with-tevs" {
        nativeBuildInputs = [ pkgs.coreutils ];
      } ''
        mkdir -p "$out"

        # Preserve the full firmware package layout expected by the Raspberry Pi
        # image builder, especially share/raspberrypi/boot.
        cp -a "${cfg.firmwarePackage}/." "$out/"

        mkdir -p "$out/share/raspberrypi/boot/overlays"

        if [ -d "${tevsDtbo}/overlays" ]; then
          cp -r "${tevsDtbo}/overlays"/* "$out/share/raspberrypi/boot/overlays/" || true
        fi
      ''
    else
      null;
in
{
  options.hardware.tevs = {
    enable = lib.mkEnableOption "TEVS camera kernel support";

    src = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "./vendor/tn-rpi-camera-driver";
      description = ''
        Optional override for the TechNexion TEVS driver source tree. When not
        set, the upstream TechNexion repository pinned in this module is used.
      '';
    };

    firmwarePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.raspberrypifw;
      defaultText = lib.literalExpression "pkgs.raspberrypifw";
      description = "Base Raspberry Pi firmware package to extend with TEVS overlays.";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [ tevsKernelOverlay ];

    boot.kernelPatches = [
      {
        name = "tevs-kconfig";
        patch = null;
        structuredExtraConfig = with lib.kernel; {
          VIDEO_TEVS = module;
        };
      }
    ];

    boot.loader.raspberryPi.firmwarePackage = firmwareWithTevs;

    boot.extraModprobeConfig = ''
      softdep tevs pre: gpio_pca953x
    '';

    system.build.tevsDtbo = tevsDtbo;
    system.build.tevsSource = tnDriver;
  };
}