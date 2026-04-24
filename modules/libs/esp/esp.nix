{ config, pkgs, lib, ... }:
let
  espHostedModule = config.boot.kernelPackages.callPackage ({ stdenv, lib, fetchFromGitHub, kernel, bc }: 
    stdenv.mkDerivation {
      pname = "esp-hosted-ng";
      version = "master-2025-02-03";
      
      src = fetchFromGitHub {
        owner = "espressif";
        repo = "esp-hosted";
        rev = "8626b42fd3f9eb5a1ccb5daea481f0d8d32b1685"; 
        sha256 = "sha256-DCPj3t1V7clO43dTWwRmlEYbrQ/Gcqdh3EkERZHgHQo="; 
      };

      sourceRoot = "source/esp_hosted_ng/host";

      nativeBuildInputs = kernel.moduleBuildDependencies ++ [ bc ];

      postPatch = ''
        # Remove clean calls because we are in snadbox
        
        sed -i 's/all: clean/all:/g' Makefile
        
        sed -i '/-C.*clean/d' Makefile
       # sed -i 's/#define HANDSHAKE_PIN.*/#define HANDSHAKE_PIN 15/' spi/esp_spi.h
       # sed -i 's/#define SPI_DATA_READY_PIN.*/#define SPI_DATA_READY_PIN 13/' spi/esp_spi.h
     
        sed -i 's/#define HANDSHAKE_PIN.*/#define HANDSHAKE_PIN 591/' spi/esp_spi.h
        sed -i 's/#define SPI_DATA_READY_PIN.*/#define SPI_DATA_READY_PIN 596/' spi/esp_spi.h
        sed -i 's/udelay(200);/msleep(500);/g' main.c
        sed -i 's/gpio_request(resetpin, "sysfs");/int err = gpio_request(resetpin, "sysfs"); if(err) { esp_err("Failed to request reset pin %d, error %d\\n", resetpin, err); } else { esp_info("SUCCESS: Kernel granted lock on pin %d\\n", resetpin); }/g' main.c
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

  spiDisablerDtbo = pkgs.stdenv.mkDerivation {
    pname = "spi-disabler-dtbo";
    version = "1.0";
    dontUnpack = true; 
    nativeBuildInputs = [ pkgs.dtc ];
    passAsFile = [ "dtsText" ];
    dtsText = ''
        /dts-v1/;
        /plugin/;
        / {
          compatible = "brcm,bcm2712";
          fragment@0 {
            target = <&spidev0>;
            __overlay__ {
              status = "disabled";
            };
          };
        };
    '';
    buildPhase = "dtc -@ -I dts -O dtb -o spi_disabler.dtbo $dtsTextPath";
    installPhase = "mkdir -p $out/overlays; cp spi_disabler.dtbo $out/overlays/";
  };
in
{

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

  # Global config:
  _module.args.espHostedModule = espHostedModule;
  _module.args.spiDisablerDtbo = spiDisablerDtbo;

  boot.extraModulePackages = [ espHostedModule ];
  networking.networkmanager.unmanaged = [ "wlan3" ];

  # systemd.services.load-esp-driver = {
  #   description = "Load ESP32 SPI Driver";
  #   wantedBy = [ "multi-user.target" ];
  #   after = [ "network.target" "systemd-udev-settle.service" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #     ExecStart = "${pkgs.kmod}/bin/modprobe esp32_spi resetpin=575";
  #   };
  # };

  systemd.services.load-esp-driver = {
      description = "Load ESP32 SPI Driver";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "systemd-udev-settle.service" ];

      path = [ pkgs.libgpiod ]; 
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        
        ExecStartPre = "-${pkgs.libgpiod}/bin/gpioset -c 0 26=0; sleep 0.4; ${pkgs.libgpiod}/bin/gpioset -c 0 26=1";
        
        ExecStart = "${pkgs.kmod}/bin/modprobe esp32_spi resetpin=575";
      };
    };
}

