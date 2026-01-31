{
  description = "ODIN Flight Software System";

  nixConfig = {
    extra-substituters = [ 
    "https://nixos-raspberrypi.cachix.org" 
    "https://terminus.cachix.org" 
    ];
    extra-trusted-public-keys = [
       "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI=" 
       "terminus.cachix.org-1:UjZ4GF7MykvHYub8KHNNZs8D83XY2OiVFgHGzkIpkFI="
       ];
    connect-timeout = 5;
  };

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-25.11";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    rust-overlay.url = "github:oxalica/rust-overlay";
    jupiter.url = "github:Terminus-Suborbital-Research-Program/Styx";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-raspberrypi, rust-overlay, disko
            , nixos-anywhere, ... } @inputs: {

    # packages.x86_64-linux.odin-image = self.nixosConfigurations.odin.config.system.build.sdImage;

    # installerImages = nixos-raspberrypi.installerImages.rpi5;

    # packages.x86_64-linux.odin-image = 
    # self.nixosConfigurations.odin.config.system.build.diskoImages;

    nixosConfigurations.odin = nixos-raspberrypi.lib.nixosSystemFull {
      specialArgs = inputs;
      modules = [

        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        # nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
        nixos-raspberrypi.nixosModules.raspberry-pi-5.display-vc4
        # nixos-raspberrypi.nixosModules.sd-image
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ (import rust-overlay) ];
        })
        ./configuration.nix

        ({ config, pkgs, lib, ... }:
        {
          nixpkgs.overlays = [
            (self: super: {
              gjs = super.gjs.overrideAttrs (oldAttrs: {
                # This tells the Meson build system to STFU about GTK
                mesonFlags = (oldAttrs.mesonFlags or []) ++ [ "-Dskip_gtk_tests=true" ];
                doCheck = false;
                doInstallCheck = false;
                checkPhase = "true";
              });
            })
          ];
        })
      ];
    };

    installerImages.odin = (nixos-raspberrypi.lib.nixosInstaller {
      specialArgs = inputs;
      modules = [
        # nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        nixos-raspberrypi.nixosModules.raspberry-pi-5.display-vc4
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ (import rust-overlay) ];
        })
        ./configuration.nix

        # Disable specific unit tests from gjs triggered by the display-vc4
        # For some reason the last two always file, maybe because of the sandbox nix builds
        # stuff in, but either way it breaks every build including vc4 when not disabled
        ({ config, pkgs, lib, ... }:
        {
          nixpkgs.overlays = [
            (self: super: {
              gjs = super.gjs.overrideAttrs (oldAttrs: {
                # This tells the Meson build system to STFU about GTK
                mesonFlags = (oldAttrs.mesonFlags or []) ++ [ "-Dskip_gtk_tests=true" ];
                doCheck = false;
                doInstallCheck = false;
                checkPhase = "true";
              });
            })
          ];
        })
      ];
    }).config.system.build.sdImage;
  };
}
