{
  description = "ODIN Flight Software System";

  nixConfig = {
    extra-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
    extra-trusted-public-keys = [ "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI=" ];
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

    nixosConfigurations.disk-odin = nixos-raspberrypi.lib.nixosSystemFull {
      specialArgs = inputs;
      modules = [

        # nixos-raspberrypi.nixosModules.raspberry-pi-5
        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
        # nixos-raspberrypi.nixosModules.raspberry-pi-5-page-size-16k
        nixos-raspberrypi.nixosModules.raspberry-pi-5.display-vc4
        # nixos-raspberrypi.nixosModules.sd-image
        disko.nixosModules.disko
        ./disko-config.nix
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

    installerImages.rpi5 = (nixos-raspberrypi.lib.nixosInstaller {
      specialArgs = inputs;
      modules = [
        nixos-raspberrypi.nixosModules.raspberry-pi-5.base

        ({ config, pkgs, lib, ... }: {
          # networking.wireless.iwd.enable = true;
          
          # networking.wireless.iwd.settings = {
          #   KnownNetworks = {
          #     "Staff5" = "66fe08674eda745336a1ac1dddf2e7fef7d1374a6c73184194a05332e0648ff1"; # Using your pskRaw from earlier
          #     "Pixel_8877" = "8f866ba6b78b2fc0ba26bf81b232f02f7b4f4f0141018507e0bd9e2761dbd9b4";
          #   };
          # };
          boot.kernelParams = [ "copytoram" ];
          system.stateVersion = "25.11";

          hardware.enableRedistributableFirmware = true;

          # networking.wireless.enable = false; 
          # networking.wireless.iwd = {
          #   enable = true;
          #   settings = {
          #     Network = {
          #       EnableIPv6 = true;
          #       RoutePriorityOffset = 300;
          #     };
          #     Settings = {
          #       AutoConnect = true;
          #     };
          #   };
          # };
          # networking.networkmanager.enable = lib.mkForce false;
          networking.networkmanager.enable = lib.mkOverride 0 false;
          networking.wireless = {
            enable = true;
            networks."Staff5".pskRaw =
              "66fe08674eda745336a1ac1dddf2e7fef7d1374a6c73184194a05332e0648ff1";
            networks."Pixel_8877".pskRaw =
              "8f866ba6b78b2fc0ba26bf81b232f02f7b4f4f0141018507e0bd9e2761dbd9b4";
            networks."MoonAndStars".psk = "CatholicAndHeretic";
          };
          

          users.users.nixos.openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFXPxcaJrD7Lu2P1/CxCwoKySNrszKuXgJteVZFo9vk3 supergoodname77@cachyos-x8664"
          ];

          # rpi5-installer.local
          services.avahi.enable = true;
          services.avahi.nssmdns4 = true;
          services.avahi.publish.enable = true;
          services.avahi.publish.addresses = true;
        })
      ];
    }).config.system.build.sdImage;
  };
}
