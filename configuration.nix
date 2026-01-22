{ config, pkgs, ... }:

{
  imports = [
    ./hardware/hardware-pi-5.nix
    # ./hardware/kernel.nix
    ./hardware/pi5-configtxt.nix
    ./modules/programs.nix
    ./modules/user.nix
    ./modules/wireless.nix
  ];

  system.stateVersion = "25.11";# Pinned, DON"T CHANGE

  # General Config
  nixpkgs.config.allowUnfree = true;

  hardware.enableRedistributableFirmware = true;
  networking.hostName = "odin-compute";
  # networking.useNetworkd = true;
  # networking.wireless.iwd = { enable = true; settings.Settings.AutoConnect = true; };
  
  security.sudo.wheelNeedsPassword = false;
  services.openssh.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

}
