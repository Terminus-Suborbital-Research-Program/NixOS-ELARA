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

  systemd.services.tevs-media-setup = {
    description = "Configure TEVS Camera Media Controller Pipeline";
    wantedBy = [ "multi-user.target" ];
    

    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    
    path = [ pkgs.v4l-utils ]; 
    
    script = ''
      echo "Waiting for /dev/media0 to initialize..."
      
      # Wait up to 15 seconds
      timeout=15
      while [ ! -e /dev/media0 ]; do
        sleep 1
        timeout=$((timeout - 1))
        if [ "$timeout" -eq 0 ]; then
          echo "Timeout waiting for /dev/media0"
          exit 1
        fi
      done
      
      echo "/dev/media0 found. Configuring pipeline..."

      # Link the CSI2 source pad to the RP1 CFE (Camera Frontend) sink pad
      media-ctl -d /dev/media0 -l "'csi2':4 -> 'rp1-cfe-csi2_ch0':0 [1]" 
      
      # Configure pipeline formats
      media-ctl -d /dev/media0 -V "'tevs 10-0048':0 [fmt:UYVY8_1X16/1280x720 field:none]" 
      media-ctl -d /dev/media0 -V "'csi2':0 [fmt:UYVY8_1X16/1280x720 field:none]" 
      media-ctl -d /dev/media0 -V "'csi2':4 [fmt:UYVY8_1X16/1280x720 field:none]"
    '';
  };
}