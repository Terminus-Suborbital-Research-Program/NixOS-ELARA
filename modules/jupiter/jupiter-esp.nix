{ config, pkgs, lib, ... }:
let
  # Define the kernel module package
  espHostedModule = config.boot.kernelPackages.callPackage ({ stdenv, lib, fetchFromGitHub, kernel, bc }: 
    stdenv.mkDerivation {
      pname = "esp-hosted-ng";
      version = "master-2025-02-03";
      
      src = fetchFromGitHub {
        owner = "espressif";
        repo = "esp-hosted";
        rev = "master"; # Pin this to a specific commit hash later so we know it won't break
        sha256 = "sha256-3tMBG57PhZMjLRehg/B28iYPYnvuU6iYfnS2KxAtTBo="; 
      };

      sourceRoot = "source/esp_hosted_ng/host";

      nativeBuildInputs = kernel.moduleBuildDependencies ++ [ bc ];

      postPatch = ''
        # Remove clean calls because we are in snadbox
        
        sed -i 's/all: clean/all:/g' Makefile
        
        sed -i '/-C.*clean/d' Makefile
       # sed -i 's/#define HANDSHAKE_PIN.*/#define HANDSHAKE_PIN 15/' spi/esp_spi.h
       # sed -i 's/#define SPI_DATA_READY_PIN.*/#define SPI_DATA_READY_PIN 13/' spi/esp_spi.h
        sed -i 's/#define HANDSHAKE_PIN.*/#define HANDSHAKE_PIN 584/' spi/esp_spi.h
        sed -i 's/#define SPI_DATA_READY_PIN.*/#define SPI_DATA_READY_PIN 582/' spi/esp_spi.h
      '';

      makeFlags = [
        "target=spi"
        "KERNEL=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
      ];

      installPhase = ''
        # Using the 'extra' directory is the NixOS standard for out-of-tree modules
        mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
        cp esp32_spi.ko $out/lib/modules/${kernel.modDirVersion}/extra/
      '';
    }) {};

  # spiDisablerDtbo = pkgs.stdenv.mkDerivation {
  #   pname = "spi-disabler-dtbo";
  #   version = "1.0";
  #   dontUnpack = true; 
  #   nativeBuildInputs = [ pkgs.dtc ];
  #   passAsFile = [ "dtsText" ];
  #   dtsText = ''
  #       /dts-v1/;
  #       /plugin/;
  #       / {
  #         compatible = "brcm,bcm2712";
  #         fragment@0 {
  #           target = <&spidev0>;
  #           __overlay__ {
  #             status = "disabled";
  #           };
  #         };
  #       };
  #   '';
  #   buildPhase = "dtc -@ -I dts -O dtb -o spi_disabler.dtbo $dtsTextPath";
  #   installPhase = "mkdir -p $out/overlays; cp spi_disabler.dtbo $out/overlays/";
  # };
in
{
  # Load module on boot
  boot.extraModulePackages = [ espHostedModule ];

  # Disable this becuase rpi_init.sh disables it so that it
  # does not hold the spi interface instead of the esp driver
  #boot.blacklistedKernelModules = [ "spidev" ];

  # cfg80211 should be loading in with networking.wireless, but if it's not loading before
  # the driver then I should try explicit import

 # boot.kernelModules = [ "esp32_spi" ]; # check the .ko with 
  # ls -R /run/current-system/kernel-modules/lib/modules/$(uname -r)/
  # or 
  # find /run/current-system/kernel-modules/ -name "*.ko" | grep -E "esp|morse"

  # /run/booted-system/kernel-modules/lib/modules/$(uname -r)/kernel/drivers/net/wireless/esp32_spi.ko
  # check loading with lsmod | grep esp32


  # See if SPI is enabled with 
  # ls /dev/spidev*
  # ls /sys/class/spi_master/
  # If not enabled, uncomment this and rebuild


  hardware.deviceTree = {
    enable = true;
    overlays = [
      {
        name = "spi-disabler";
        filter = "*-rpi-4-b.dtb";
        dtsText = ''
          /dts-v1/;
          /plugin/;
          / {
            /* IMPORTANT: Changed from 2712 (Pi 5) to 2711 (Pi 4) */
            compatible = "brcm,bcm2711"; 
            fragment@0 {
              target = <&spidev0>;
              __overlay__ {
                status = "disabled";
              };
            };
          };
        '';
      }
      {
        filter = "*-rpi-4-b.dtb"; 
        name = "spi0-0cs";
        dtboFile = "${pkgs.device-tree_rpi.overlays}/spi0-0cs.dtbo";
      }
    ];
  };


  # system.activationScripts.esp-overlays = ''
  #   mkdir -p /boot/firmware/overlays
  #   cp ${spiDisablerDtbo}/overlays/*.dtbo /boot/firmware/overlays/
  # '';


  # hardware.raspberry-pi.config.all.dt-overlays = {
  #   "spi_disabler" = { enable = true; params = {}; };
  # };
  # hardware.raspberry-pi.config.all.base-dt-params = {
  #   spi = {
  #     enable = true;
  #     value = "on";
  #   };
  # };

  systemd.services.load-esp-driver = {
    description = "Load ESP32 SPI Driver";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.kmod}/bin/modprobe esp32_spi resetpin=575";
    };
  };

}


