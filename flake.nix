{
  description = "ODIN Flight Software System";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-25.11";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    rust-overlay.url = "github:oxalica/rust-overlay";
    jupiter.url = "github:Terminus-Suborbital-Research-Program/Styx";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    guard.url = "github:Terminus-Suborbital-Research-Program/GUARD";
  };

  outputs = { self, nixpkgs, nixos-raspberrypi, rust-overlay, guard
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
        ({ pkgs, ... }: 
        let 
        # Extract the package for the Pi's architecture
        radiaread = guard.packages.aarch64-linux.radiaread;
        in {
          nixpkgs.overlays = [ (import rust-overlay) ];
          environment.systemPackages = [ radiaread ];

          systemd.tmpfiles.rules = [
            "d /home/terminus/rad_data 0755 terminus terminus - -"
          ];

          systemd.services.radiaread = {
            description = "Terminus Radiacode Data Reader";
            after = [ "systemd-tmpfiles-setup.service" ];
            path = [ radiaread ];
            serviceConfig = {
              User = "terminus";
              WorkingDirectory = "/home/terminus/rad_data";
              ExecStart = "${radiaread}/bin/radiaread /home/terminus/rad_data";
              Restart = "always";
              RestartSec = "20s";
              Group = "dialout";
            };
            wantedBy = [ "multi-user.target" ];
          };
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
