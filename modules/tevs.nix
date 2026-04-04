{ config, pkgs, lib, ... }:

let
  kernel = config.boot.kernelPackages.kernel;
  kernelSrc = kernel.src;

  tnSource = pkgs.fetchFromGitHub {
    owner = "TechNexion-Vision";
    repo = "tn-rpi-camera-driver";
    rev = "tn_rpi_kernel-6.12";
    hash = "sha256-jBEy7JXL/ibqDQDfGDOCAMDSQAPgRDZhjal5zAC3zVE=";
  };

  dtsSource = ./.;

  # OOT Kernel mod
  tevsModule = config.boot.kernelPackages.callPackage ({ stdenv, kernel }:
    stdenv.mkDerivation {
      pname = "tevs-oot-driver";
      version = "6.12-tn";

      src = tnSource;
      sourceRoot = "source/drivers/media/i2c/tevs";

      nativeBuildInputs = kernel.moduleBuildDependencies;

      buildPhase = ''
        make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
          M=$(pwd) \
          CONFIG_VIDEO_TEVS=m \
          modules
      '';
      installPhase = ''
        mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
        cp tevs.ko $out/lib/modules/${kernel.modDirVersion}/extra/
      '';
    }
  ) {};


  #  Device tree overlays
  tevsDtbo = pkgs.stdenv.mkDerivation {
    pname = "tevs-dtbo";
    version = "6.12-tn";
    src = dtsSource;
    
    nativeBuildInputs = [ pkgs.dtc ];

    buildPhase = ''
      mkdir -p compiled_overlays
      
      for dts_file in ./*.dts; do
        filename=$(basename "$dts_file" .dts)
        
        # Preprocess (pulling headers from the actual kernel source)
        cpp -nostdinc -undef -P -x assembler-with-cpp \
          -I "${kernelSrc}/include" \
          -I "${kernelSrc}/arch/arm64/boot/dts" \
          -I "${kernelSrc}/arch/arm64/boot/dts/overlays" \
          -I include \
          -I arch/arm64/boot/dts/overlays \
          "$dts_file" > "compiled_overlays/$filename.preprocessed.dts"
          
        # Compile
        dtc -@ -I dts -O dtb -o "compiled_overlays/$filename.dtbo" "compiled_overlays/$filename.preprocessed.dts"
      done

    '';

    installPhase = ''
      mkdir -p $out/overlays
      cp compiled_overlays/*.dtbo $out/overlays/
    '';
  };

in
{
  boot.extraModulePackages = [ tevsModule ];
  boot.kernelModules = [ "tevs" ];

  boot.extraModprobeConfig = ''
    softdep tevs pre: gpio_pca953x
  '';

  hardware.raspberry-pi.config.all.dt-overlays = {
    "tevs,cam0" = {
      enable = true;
      params = {
      };
    };
    "tevs,cam1" = {
      enable = true;
      params = {
      };
    };
  };

  system.activationScripts.tevs-overlays = ''
    mkdir -p /boot/firmware/overlays
    cp ${tevsDtbo}/overlays/*.dtbo /boot/firmware/overlays/
  '';

  services.udev.extraRules = ''
    # When an rp1-cfe media device appears start the script
    SUBSYSTEM=="media", KERNEL=="media*", ATTRS{model}=="rp1-cfe", TAG+="systemd", ENV{SYSTEMD_WANTS}+="tevs-media-setup@%k.service"
  '';

  systemd.services."tevs-media-setup@" = {
    description = "Configure TEVS Camera Pipeline on %I";
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    
    path = [ pkgs.v4l-utils pkgs.gnugrep pkgs.coreutils ];
    
    scriptArgs = "%I";
    
    script = ''
      mdev="/dev/$1"
      echo "Udev triggered configuration for $mdev"

      media-ctl -d "$mdev" -p > /dev/null 2>&1

      tevs_entity=$(media-ctl -d "$mdev" -p 2>/dev/null | grep -o 'entity [0-9]*: tevs [^ ]*' | cut -d' ' -f3- || true)

      if [ -n "$tevs_entity" ]; then
        echo "Found TEVS sensor '$tevs_entity' on $mdev. Applying routing..."
        
        media-ctl -d "$mdev" -l "'csi2':4 -> 'rp1-cfe-csi2_ch0':0 [1]"
        media-ctl -d "$mdev" -V "'$tevs_entity':0 [fmt:UYVY8_1X16/1280x720 field:none]"
        media-ctl -d "$mdev" -V "'csi2':0 [fmt:UYVY8_1X16/1280x720 field:none]"
        media-ctl -d "$mdev" -V "'csi2':4 [fmt:UYVY8_1X16/1280x720 field:none]"
        
        echo "Pipeline $mdev ready for V4L2 grab."
      else
        echo "No TEVS sensor attached to $mdev. Exiting cleanly."
      fi
    '';
  };
}