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

    experimental-features = [ "nix-command" "flakes" ];
  };

  imports = [
    ../hardware/hardware-pi-5.nix
    ../hardware/kernel.nix
    ../hardware/pi5-configtxt.nix
    ../modules/radiacode.nix
    ../modules/programs.nix
    ../modules/rust.nix
    ../modules/user.nix
    ../modules/wireless.nix
  ];

  system.stateVersion = "25.11";

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="f123", MODE="0660", GROUP="dialout", SYMLINK+="radia_code"
  '';

  nixpkgs.config.allowUnfree = true;
  hardware.enableRedistributableFirmware = true;

  networking.hostName = "odin";

  security.sudo.wheelNeedsPassword = false;
}