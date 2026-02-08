{ config, pkgs, lib, ... }:
let
morseFirmware = pkgs.stdenv.mkDerivation {
    pname = "morse-firmware";
    version = "master-2025-02-03";

    src = pkgs.fetchFromGitHub {
      owner = "MorseMicro";
      repo = "morse-firmware";
      rev = "master"; # Ideally, find a specific tag/commit hash for flight stability
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Run install once to get the real hash
    };

    # We skip the 'buildPhase' because there is nothing to compile (they are just binaries)
    dontBuild = true;

    # We manually install to avoid the Makefile trying to write to /lib/firmware
    installPhase = ''
      mkdir -p $out/lib/firmware/morse

      # 1. Copy the core firmware (the "brain")
      cp mm8108_release.bin $out/lib/firmware/morse/

      # 2. Copy all BCFs so they are available for manual switching
      cp bcf_mm8108_mf15457_*.bin $out/lib/firmware/morse/

      # 3. CRITICAL: Symlink the MF15457 US config to the default
      ln -s $out/lib/firmware/morse/bcf_mm8108_mf15457_us.bin $out/lib/firmware/morse/bcf_default.bin
    '';
  };
  in {
    hardware.firmware = [ morseFirmware ];
  }