{
  description = "ODIN Flight Software System";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    rust-overlay.url = "github:oxalica/rust-overlay";
    jupiter.url = "github:Terminus-Suborbital-Research-Program/Styx";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    guard.url = "github:Terminus-Suborbital-Research-Program/GUARD";
  };

  outputs = { self, nixpkgs, nixos-raspberrypi, rust-overlay, guard, nixos-anywhere, ... }@inputs:
    let
      hostSystem = "x86_64-linux";

      commonModules = [
        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        ./configuration.nix

        ({ ... }: {
          nixpkgs.overlays = [
            rust-overlay.overlays.default

            (final: prev: {
              gjs = prev.gjs.overrideAttrs (old: {
                mesonFlags = (old.mesonFlags or [ ]) ++ [ "-Dskip_gtk_tests=true" ];
                doCheck = false;
                doInstallCheck = false;
                checkPhase = "true";
              });
            })
          ];
        })
      ];
    in
    {
      nixosConfigurations.odin = nixos-raspberrypi.lib.nixosSystemFull {
        specialArgs = inputs;
        modules = commonModules;
      };

      installerImages.odin = (
        nixos-raspberrypi.lib.nixosInstaller {
          specialArgs = inputs;
          modules = commonModules;
        }
      ).config.system.build.sdImage;

      packages = {
        ${hostSystem} = {
          odin-image = self.installerImages.odin;
        };
      };
    };
}