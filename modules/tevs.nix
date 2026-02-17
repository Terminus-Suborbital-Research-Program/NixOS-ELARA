{ config, pkgs, lib, ... }:

let
  # Access your pinned kernel headers
  kernel = config.boot.kernelPackages.kernel;

  tevs-driver-src = pkgs.fetchFromGitHub {
    owner = "TechNexion-Vision";
    repo = "tn-rpi-camera-driver";
    rev = "tn_rpi_kernel-6.6"; 
    sha256 = "sha256-mpmywww4bw88f49a2x8sdl5c0rxnpcxcaaaaaaaaaaa="; # Use actual hash
  };

  tevs-module = pkgs.stdenv.mkDerivation {
    pname = "tevs-driver";
    version = "6.6.y";
    src = tevs-driver-src;

    nativeBuildInputs = [ pkgs.bc pkgs.gnumake ] ++ kernel.moduleBuildDependencies;


    buildPhase = ''
      cd drivers/media/i2c
      make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M=$(pwd) \
        modules
    '';

    installPhase = ''
      mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
      cp tevs.ko $out/lib/modules/${kernel.modDirVersion}/extra/
    '';
  };

  tevs-overlay = pkgs.stdenv.mkDerivation {
    pname = "tevs-overlay";
    version = "6.6.y";
    src = tevs-driver-src;

    nativeBuildInputs = [ pkgs.dtc ];

    buildPhase = ''
      cd arch/arm64/boot/dts/overlays
      # Compile the .dts into a .dtbo
      dtc -@ -I dts -O dtb -o tevs-rpi22.dtbo tevs-rpi22-overlay.dts
    '';

    installPhase = ''
      mkdir -p $out
      cp tevs-rpi22.dtbo $out/
    '';
  };

in {
  # Load the compiled module into the kernel
  boot.extraModulePackages = [ tevs-module ];
  boot.kernelModules = [ "tevs" ];

  # Apply the compiled Device Tree Overlay
  hardware.deviceTree = {
    enable = true;
    overlays = [
      {
        name = "tevs-rpi22";
        dtboFile = "${tevs-overlay}/tevs-rpi22.dtbo";
      }
    ];
  };

  # Configure Raspberry Pi specific boot flags (config.txt)
  hardware.raspberry-pi.config.all.options = {
    camera_auto_detect = {
      enable = true;
      value = 0;
    };
    
    "dtoverlay=tevs-rpi22" = {
      enable = true;
      value = "cam0"; 
    };
  };

  boot.extraModprobeConfig = ''
    softdep tevs pre: gpio_pca953x
  '';
}
