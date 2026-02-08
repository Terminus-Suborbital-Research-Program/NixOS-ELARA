{ config, pkgs, ... }:

{
    nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nixos-raspberrypi.cachix.org"
      "https://terminus.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      "terminus.cachix.org-1:UjZ4GF7MykvHYub8KHNNZs8D83XY2OiVFgHGzkIpkFI="
    ];
  };


  imports = [
    ./hardware/hardware-pi-5.nix
    ./hardware/kernel.nix
    ./hardware/pi5-configtxt.nix
    ./modules/morse/mm8108.nix
    ./modules/morse/morse-driver.nix
    ./modules/morse/morse-tools.nix
    ./modules/programs.nix
    ./modules/user.nix
    ./modules/wireless.nix
  ];

  system.stateVersion = "25.11";# Pinned, DON"T CHANGE

  # General Config
  nixpkgs.config.allowUnfree = true;

  hardware.enableRedistributableFirmware = true;

  networking.hostName = "odin";
  # networking.useNetworkd = true;
  # networking.wireless.iwd = { enable = true; settings.Settings.AutoConnect = true; };
  
  security.sudo.wheelNeedsPassword = false;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

}
