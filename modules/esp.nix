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
        sha256 = "sha256-hqUQpWCGsyre0Z/MNTMYTYMYT24kDnZ0bMKdkwlF4+w="; 
      };

      sourceRoot = "source/esp_hosted_ng/host";

      nativeBuildInputs = kernel.moduleBuildDependencies ++ [ bc ];

      postPatch = ''
        # Remove clean calls because we are in snadbox
        
        sed -i 's/all: clean/all:/g' Makefile
        
        sed -i '/-C.*clean/d' Makefile
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
in
{
  # Load module on boot
  boot.extraModulePackages = [ espHostedModule ];

  # Disable this becuase rpi_init.sh disables it so that it
  # does not hold the spi interface instead of the esp driver
  boot.blacklistedKernelModules = [ "spidev" ];

  # boot.kernelModules = [ "cfg80211" "esp32_spi" ]; 
  # cfg80211 should be loading in with networking.wireless, but if it's not loading before
  # the driver then I should try explicit import

  boot.kernelModules = [ "esp32_spi" ]; # check the .ko with 
  # ls -R /run/current-system/kernel-modules/lib/modules/$(uname -r)/
  # or 
  # find /run/current-system/kernel-modules/ -name "*.ko" | grep -E "esp|morse"

  # /run/booted-system/kernel-modules/lib/modules/$(uname -r)/kernel/drivers/net/wireless/esp32_spi.ko
  # check loading with lsmod | grep esp32

  # Note may have to tweak "esp32_spi.spi_clk_freq=10"
  # But leaving that out because it seems system dependent
  # And this may just work fine by default on the pi 5
  boot.kernelParams = [
    "esp32_spi.resetpin=6" 
    "esp32_spi.spi_handshake=15"
    "esp32_spi.spi_dataready=13"
  ];

  #

  # See if SPI is enabled with 
  # ls /dev/spidev*
  # ls /sys/class/spi_master/
  # If not enabled, uncomment this and rebuild
  #
  # Also check if kernel has direct acces to gpio through pinctrl-rp1
  # I know user access works with gpiod but not sure if that means
  # the kernel has the same access, though I'm pretty sure libgpiod requests
  # hardware access from the kernel so this is likely fine

  hardware.deviceTree.overlays = [ {
    name = "esp32-spi-link-overlay";
    dtsText = ''
        /dts-v1/;
        /plugin/;

        / {
          compatible = "brcm,bcm2712";

          fragment@0 {
            target = <&spi0>;
            __overlay__ {
              status = "okay";
              #address-cells = <1>;
              #size-cells = <0>;
              
              /* Assign the SPI pin mux (GPIOs 9, 10, 11) */
              pinctrl-names = "default";
              pinctrl-0 = <&spi0_pins>;

              esp32_spi: esp32_spi@0 {
                compatible = "espressif,esp32_spi";
                reg = <0>; 
                spi-max-frequency = <20000000>; /* 20MHz  */
                
                /* GPIO 6, Active Low (flag 1) */
                reset-gpios = <&gpio 6 1>;
                
                /* Handshake and Dataready usually Active Low*/
                handshake-gpios = <&gpio 15 0>;
                dataready-gpios = <&gpio 13 0>;
                
                status = "okay";
              };
            };
          };

          fragment@1 {
            target = <&spidev0>;
            __overlay__ {
              status = "disabled";
            };
          };
        };
      '';
    
  }];
  
  hardware.raspberry-pi.config.all.base-dt-params = {
    spi = {
      enable = true;
      value = "on";
    };
    esp32-spi-link = {
      enable = true;
    };
  };

}