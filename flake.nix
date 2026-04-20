{
  description = "ELARA Flight Software Systems";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-25.11";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    rust-overlay.url = "github:oxalica/rust-overlay";
    jupiter.url = "github:Terminus-Suborbital-Research-Program/Styx";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    guard.url = "github:Terminus-Suborbital-Research-Program/GUARD";
    styx.url = "styx.url = "git+https://github.com/Terminus-Suborbital-Research-Program/Styx.git?ref=Basler-Nix&submodules=1";";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, nixos-raspberrypi, rust-overlay, guard
            , nixos-anywhere, styx, nixos-hardware, ... } @inputs:
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

      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };

      basler-pkg = pkgs.callPackage ./modules/libs/basler.nix { };

      jupiter-pkg = pkgs.callPackage "${styx}/machines/pi-5/jupiter-fsw/jupiter.nix" {
        src = styx;
        basler-pylon = basler-pkg;
      };
    in {

    nixosConfigurations."dev-pi" = let system = "aarch64-linux";
    in nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = inputs;
      modules = [
        nixos-hardware.nixosModules.raspberry-pi-4
        ./jupiter-configuration.nix
      ];
    };
    
    nixosConfigurations."dev-pi-image" = let system = "aarch64-linux";
    in nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = inputs;
      modules = [
        nixos-hardware.nixosModules.raspberry-pi-4
        ./jupiter-configuration.nix
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
      ];
    };
    
    nixosConfigurations.odin = nixos-raspberrypi.lib.nixosSystemFull {
      specialArgs = inputs;
      modules = [

        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        # nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
        nixos-raspberrypi.nixosModules.raspberry-pi-5.display-vc4
        ./configuration.nix

        ({ config, pkgs, lib, ... }:
        {
          nixpkgs.overlays = [ gjsOverlay ];
          environment.systemPackages = [ basler-pkg jupiter-pkg ];

          # systemd.tmpfiles.rules = [
          #   "d /home/terminus/flight_data 0755 terminus terminus - -"
          # ];

          # systemd.services.jupiter = {
          #   description = "JUPITER Flight Software";
          #   after = [ "network.target" "systemd-tmpfiles-setup.service" ];
            
          #   path = [ jupiter-pkg pkgs.libgpiod pkgs.ffmpeg ];

          #   serviceConfig = {
          #     ExecStart = "${jupiter-pkg}/bin/jupiter-fsw";
              
          #     # Execute as if in this directory
          #     WorkingDirectory = "/home/terminus/flight_data";
              
          #     User = "terminus";
          #     Group = "users"; 
              
          #     Restart = "always";
          #     RestartSec = "5s";
              
          #     # journalctl -u jupiter`
          #     StandardOutput = "journal";
          #     StandardError = "journal";
          #   };

          #   wantedBy = [ "multi-user.target" ];
          # };
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
          # environment.systemPackages = [ jupiter-pkg ];
        })
      ];
    }).config.system.build.sdImage;

    devShells.${system}.default = pkgs.mkShell {
        name = "odin-proto-shell";

        buildInputs = [
          basler-pkg   
          pkgs.pkg-config    
          pkgs.libusb1
          pkgs.zlib
        ];

        shellHook = ''
          export PYLON_ROOT="${basler-pkg}/opt/pylon"
          
          export GENICAM_GENTL64_PATH="${basler-pkg}/opt/pylon/lib/gentlproducer/gtl"
          export PYLON_GENTL64_PATH="${basler-pkg}/opt/pylon/lib/gentlproducer/gtl"


          export LD_LIBRARY_PATH="${basler-pkg}/opt/pylon/lib:${pkgs.lib.makeLibraryPath [ pkgs.libusb1 pkgs.zlib pkgs.stdenv.cc.cc.lib ]}:$LD_LIBRARY_PATH"

        '';
      };
  };
}
