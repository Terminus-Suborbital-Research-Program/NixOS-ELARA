{
  description = "ODIN Flight Software System";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-25.11";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    rust-overlay.url = "github:oxalica/rust-overlay";
    jupiter.url = "github:Terminus-Suborbital-Research-Program/Styx";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    guard.url = "github:Terminus-Suborbital-Research-Program/GUARD";
    styx.url = "github:Terminus-Suborbital-Research-Program/Styx";
  };

  outputs = { self, nixpkgs, nixos-raspberrypi, rust-overlay, guard
            , nixos-anywhere, styx, ... } @inputs:
    let
      gjsOverlay = final: prev: {
        gjs = prev.gjs.overrideAttrs (oldAttrs: {
          # This tells the Meson build system to STFU about GTK
          mesonFlags = (oldAttrs.mesonFlags or []) ++ [ "-Dskip_gtk_tests=true" ];
          doCheck = false;
          doInstallCheck = false;
          checkPhase = "true";
        });
      };

      pkgs = import nixpkgs { inherit system; };

      basler-pkg = pkgs.callPackage ./libs/basler.nix { };

      jupiter-pkg = pkgs.callPackage "${styx}/machines/pi-5/jupiter-fsw/jupiter.nix" {
        src = styx;
        basler-pylon = basler-pkg;
      };
    in {


    nixosConfigurations.odin = nixos-raspberrypi.lib.nixosSystemFull {
      specialArgs = inputs;
      modules = [

        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        # nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
        nixos-raspberrypi.nixosModules.raspberry-pi-5.display-vc4
        # nixos-raspberrypi.nixosModules.sd-image
        ./configuration.nix

        ({ config, pkgs, lib, ... }:
        {
          nixpkgs.overlays = [ gjsOverlay ];
          environment.systemPackages = [ odin-pkg ];
        })
      ];
    };

    installerImages.odin = (nixos-raspberrypi.lib.nixosInstaller {
      specialArgs = inputs;
      modules = [
        # nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        nixos-raspberrypi.nixosModules.raspberry-pi-5.display-vc4
        ./configuration.nix

        ({ config, pkgs, lib, ... }:
        {
          nixpkgs.overlays = [ gjsOverlay ];
          environment.systemPackages = [ odin-pkg ];
        })
      ];
    }).config.system.build.sdImage;
  };
}
