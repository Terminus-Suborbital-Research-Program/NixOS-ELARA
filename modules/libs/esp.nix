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
        rev = "8626b42fd3f9eb5a1ccb5daea481f0d8d32b1685"; # Pin this to a specific commit hash later so we know it won't break
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
        sed -i 's/udelay(200);/msleep(400);/g' main.c
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
lib.mkMerge [

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
  {
    boot.extraModulePackages = [ espHostedModule ];
    
    networking.networkmanager.unmanaged = [ "wlan3" ];

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

  # Jupiter config (AP)
  (lib.mkIf (config.networking.hostName == "jupiter") {
    
    # Standard NixOS Hardware Overlays
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

    # Access Point Configuration
    environment.etc."esp32/wpa_ap.conf".text = ''
      ctrl_interface=/var/run/wpa_supplicant_esp
      ctrl_interface_group=wheel
      update_config=1
      country=US

      network={
          ssid="ELARA_ESP_LINK"
          mode=2               # AP Mode
          key_mgmt=WPA-PSK
          psk="ElaraFlight"
          frequency=2437       # Channel 6
      }
    '';

    systemd.services.esp-ap = {
      description = "ESP32 Access Point (wlan3)";
      bindsTo = [ "sys-subsystem-net-devices-wlan3.device" ];
      after = [ "sys-subsystem-net-devices-wlan3.device" "load-esp-driver.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.wpa_supplicant}/bin/wpa_supplicant -Dnl80211 -iwlan3 -c/etc/esp32/wpa_ap.conf -s";
        Restart = "always";
        RestartSec = "5s";
      };
    };

    networking.interfaces.wlan3.ipv4.addresses = [{
      address = "192.168.4.1";
      prefixLength = 24;
    }];
  })


  (lib.mkIf (config.networking.hostName == "odin") {

    # NVMD Style Overlays
    system.activationScripts.esp-overlays = ''
      mkdir -p /boot/firmware/overlays
      cp ${spiDisablerDtbo}/overlays/*.dtbo /boot/firmware/overlays/
    '';

    hardware.raspberry-pi.config.all.dt-overlays = {
      "spi_disabler" = { enable = true; params = {}; };
    };
    hardware.raspberry-pi.config.all.base-dt-params = {
      spi = {
        enable = true;
        value = "on";
      };
    };

    # Client Configuration
    environment.etc."esp32/wpa_client.conf".text = ''
      ctrl_interface=/var/run/wpa_supplicant_esp
      ctrl_interface_group=wheel
      update_config=1
      country=US

      network={
          ssid="ELARA_ESP_LINK"
          scan_ssid=1
          key_mgmt=WPA-PSK
          psk="ElaraFlight"
      }
    '';

    systemd.services.esp-client = {
      description = "ESP32 Client (wlan3)";
      bindsTo = [ "sys-subsystem-net-devices-wlan3.device" ];
      after = [ "sys-subsystem-net-devices-wlan3.device" "load-esp-driver.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.wpa_supplicant}/bin/wpa_supplicant -Dnl80211 -iwlan3 -c/etc/esp32/wpa_client.conf -s";
        Restart = "always";
        RestartSec = "5s";
      };
    };

    networking.interfaces.wlan3.ipv4.addresses = [{
      address = "192.168.4.2";
      prefixLength = 24;
    }];
  })
]

