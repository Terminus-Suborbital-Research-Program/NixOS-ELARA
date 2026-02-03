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
        sha256 = "sha256-Ju4gcjcMKJZ/FFJrVYLQC+ERgePNyzFOHbtVA/bN0TU="; # Update this after first fail
      };

      # Point to the specific subdirectory for the driver
      sourceRoot = "source/esp_hosted_ng/host";

      # CRITICAL: Inject the Kernel Headers and Build Tools
      nativeBuildInputs = kernel.moduleBuildDependencies ++ [ bc ];

      # Fix the Makefile to use NixOS kernel paths instead of /lib/modules/$(uname -r)
      makeFlags = [
        "target=spi"
        "KERNEL=${kernel.dev}"
        "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
      ];

      # Install the .ko file to the correct NixOS module path
      installPhase = ''
        mkdir -p $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless
        cp esp32_spi.ko $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless/
        # Check if esp_hosted_ng.ko exists and copy it too if the name changed in your version
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

  hardware.raspberry-pi.config.all.base-dt-params = {
    spi = { enable = true; value = "on"; };
  };
}