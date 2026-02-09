{ config, pkgs, lib, ... }:

let
  morseDriver = config.boot.kernelPackages.callPackage ({ stdenv, lib, fetchFromGitHub, kernel, bc, gnumake }: 
    let
      shouldCross = stdenv.buildPlatform.system != stdenv.hostPlatform.system;
      version = "1.16.4";
    in
    stdenv.mkDerivation rec {
      pname = "morse-halow-usb-driver";
      inherit version;

      outputs = [ "out" "modules" ];

      src = fetchFromGitHub {
        owner = "MorseMicro";
        repo = "morse_driver";
        rev = "refs/heads/main"; 
        sha256 = "sha256-kMEFl1sfDGqh96t5emF9UtzOqauFClKXBsXrS1NZ33E=";
        fetchSubmodules = true;
      };


      nativeBuildInputs = [ gnumake bc ] ++ kernel.moduleBuildDependencies;
      buildInputs = [ kernel.dev ];

      postPatch = ''
        substituteInPlace Makefile \
          --replace "-Werror" ""
      '';

      makeFlags = [
        "V=1"
        "KBUILD_VERBOSE=1"
        "MORSE_TRACE_PATH=."
        "MORSE_VERSION=0-rel_1_16_4_2025_Sep_18"
        "ARCH=arm64"
        "KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        
        # Driver Configuration
        "CONFIG_WLAN_VENDOR_MORSE=m"
        "CONFIG_MORSE_USB=y"
        "CONFIG_MORSE_USER_ACCESS=y"
        "CONFIG_MORSE_VENDOR_COMMAND=y"
        "CONFIG_MORSE_MONITOR=y"
        "CONFIG_MORSE_ENABLE_TEST_MODES=y"
        "DEBUG=y"

      ] ++ lib.optionals shouldCross [
        "CROSS_COMPILE=${stdenv.hostPlatform.config}-"
      ];

      installPhase = ''
         mkdir -p "$modules/lib/modules/${kernel.modDirVersion}/extra"
       cp morse.ko "$modules/lib/modules/${kernel.modDirVersion}/extra/"
       cp dot11ah/dot11ah.ko "$modules/lib/modules/${kernel.modDirVersion}/extra/"

        # Main output
       mkdir -p "$out"
       echo "morse_driver ${version}" > $out/README
      '';
    }) {};
in
{
  boot.extraModulePackages = [ morseDriver.modules ];
  
  boot.kernelModules = [ "dot11ah" "morse" ];

  boot.kernelPatches = [
    {
      name = "morse-micro-s1g-support";
      patch = pkgs.fetchurl {
        url = "https://github.com/raspberrypi/linux/compare/rpi-6.6.y...MorseMicro:rpi-linux:mm/rpi-6.6.31/1.16.x.patch";
        sha256 = "sha256-zskyBxJDr2GK52yGr7qbs3eT0AvfaOdxJ3UU1e2Gw/I=";
      };
    }
  ];
}
