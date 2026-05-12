{ config, pkgs, lib, ... }:

{
    nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nixos-raspberrypi.cachix.org"
      "https://terminus.cachix.org"
      "https://atmopierce.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      "terminus.cachix.org-1:UjZ4GF7MykvHYub8KHNNZs8D83XY2OiVFgHGzkIpkFI="
    ];
  };


  imports = [
    ./hardware-pi-4/hardware-jupiter.nix
    ./hardware-pi-4/pi-4-kernel.nix
    ./hardware-pi-4/ethernet-bridge.nix
    ./modules/libs/morse/mm8108.nix
    ./modules/libs/morse/morse-driver.nix
    ./modules/libs/morse/morse-tools.nix
    ./modules/jupiter/radiacode.nix
   #./modules/libs/esp/esp-jupiter.nix
    ./modules/libs/programs.nix
    ./modules/libs/rust.nix
    ./modules/config/user.nix
    ./modules/config/wireless.nix
  ];

  # hardware.tevs.enable = true;s

 
  system.stateVersion = "25.11";# Pinned, DON"T CHANGE

  systemd.services.systemd-timesyncd.enable = false;

  hardware.deviceTree = {
    enable = true;
    overlays = [{
      name = "uart1-overlay";
      dtsText = builtins.readFile ./uart1-overlay.dts;
    }];
  };
  hardware.i2c.enable = true;
hardware.raspberry-pi."4" = {
  i2c1.enable = true;
  bluetooth.enable = false;
};

  services.udev.extraRules = ''
    SUBSYSTEM=="bcm2835-gpiomem", KERNEL=="gpiomem", GROUP="gpio", MODE="0660"
    
    SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP="gpio", MODE="0660"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="f123", MODE="0660", GROUP="dialout", SYMLINK+="radia_code"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="2676", MODE:="0666", TAG+="uaccess", TAG+="udev-acl"

  '';
  
   boot.kernelParams = [
    "console=tty1"
    "8250.nr_uarts=4"
    "console=serial0,115200n8"
    "dtoverlay=uart2"
    "usbcore.autosuspend=-1"
    "usbcore.usbfs_memory_mb=1000"
  ];
  
  # Group for GPIO access
  users.groups.gpio = { };
  users.groups.video = { };

  services.timesyncd.enable = false;


  # General Config
  nixpkgs.config.allowUnfree = true;

  hardware.enableRedistributableFirmware = true;

  networking.hostName = "jupiter";
  # networking.useNetworkd = true;
  # networking.wireless.iwd = { enable = true; settings.Settings.AutoConnect = true; };
  
  security.sudo.wheelNeedsPassword = false;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
