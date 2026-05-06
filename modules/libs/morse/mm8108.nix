{ config, pkgs, lib, ... }:
let
morseFirmware = pkgs.stdenv.mkDerivation {
    pname = "morse-firmware";
    version = "master-2025-02-03";

    src = pkgs.fetchFromGitHub {
      owner = "MorseMicro";
      repo = "morse-firmware";
      rev = "master"; 
      sha256 = "sha256-KgWL8Yx1V3Q5Ylz1SjaM/ZoD2OhToyBQaCCDDlwHYqw=";
    };

    dontBuild = true;

    installPhase = ''

      mkdir -p $out/lib/firmware/morse

      cp ./firmware/mm8108b2-rl.bin $out/lib/firmware/morse/
 
      cp ./bcf/morsemicro/bcf_mf15457.bin $out/lib/firmware/morse/

      ln -s $out/lib/firmware/morse/bcf_mf15457.bin $out/lib/firmware/morse/bcf_default.bin

      ln -s $out/lib/firmware/morse/bcf_mf15457.bin $out/lib/firmware/morse/bcf_boardtype_0807.bin
    '';
  };
  in {
    hardware.firmware = [ morseFirmware ];
  }
