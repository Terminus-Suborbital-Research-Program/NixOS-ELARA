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

  dtsSource = ./;

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
    "tevs-rpi22" = {
      enable = true;
      params = {
      };
    };
  };

  system.activationScripts.tevs-overlays = ''
    mkdir -p /boot/firmware/overlays
    cp ${tevsDtbo}/overlays/*.dtbo /boot/firmware/overlays/
  '';
}