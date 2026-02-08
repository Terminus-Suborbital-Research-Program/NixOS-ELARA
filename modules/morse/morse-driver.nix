{ config, pkgs, lib, ... }:
let
  morseDriver = config.boot.kernelPackages.callPackage ({ stdenv, lib, fetchFromGitHub, kernel, bc }: 
    stdenv.mkDerivation {
      pname = "morse-halow-usb-driver";
      version = "1.16.4";

      src = fetchFromGitHub {
        owner = "MorseMicro";
        repo = "morse_driver";
        rev = "master"; 
        sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Update this
        # CRITICAL: Makefile requires the mmrc-submodule
        fetchSubmodules = true; 
      };

      sourceRoot = "source"; # Adjust if the Makefile is in a /src/ directory
      nativeBuildInputs = kernel.moduleBuildDependencies ++ [ bc ];

      # Makefile Analysis Integration
      makeFlags = [
        "KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        "ARCH=arm64"
        "CROSS_COMPILE=${stdenv.cc.targetPrefix}"

        "CONFIG_MORSE_POWERSAVE_MODE=0"

        "CONFIG_MORSE_VENDOR_COMMAND=y"
        #
        # CONFIG_MORSE_POWERSAVE_MODE ?= 2
        
        # ACTIVATE USB SUPPORT (Lines 31 & 118 of Makefile)
        "CONFIG_MORSE_USB=y"
        "CONFIG_WLAN_VENDOR_MORSE=y"
        
        # REGULATORY (Line 46 of Makefile)
        "CONFIG_MORSE_COUNTRY=\"US\""
        
        # DEBUGGING (Optional: Set to 'n' for flight to reduce log spam)
        "DEBUG=y"
      ];

      installPhase = ''
        mkdir -p $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless/morse
        # The Makefile produces morse.ko (amalgamated)
        cp morse.ko dot11ah/dot11ah.ko $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless/morse/      '';
    }) {};
in
{
  boot.extraModulePackages = [ morseDriver ];
  boot.kernelModules = [ "dot11ah" "morse" ];

  boot.kernelPatches = [
  {
    name = "morse-micro-s1g-support";
    patch = pkgs.fetchurl {
      url = "https://github.com/raspberrypi/linux/compare/rpi-6.12.y...MorseMicro:rpi-linux:mm/rpi-6.12.21/1.16.x.patch";
      # Nix will require a sha256. You can find this by running:
      # nix-prefetch-url https://github.com/raspberrypi/linux/compare/rpi-6.12.y...MorseMicro:rpi-linux:mm/rpi-6.12.21/1.16.x.patch
      sha256 = "sha256-1kssz1dyjhch4sq4mp3gjh3yhx23ia4cvri5krgimaf8z5imwp95=";
    };
  }
];
}

# Test with nm -u result/.../morse.ko | grep usb
# Use:
# sudo dmesg | grep Morse 
# to verify US cxountry code