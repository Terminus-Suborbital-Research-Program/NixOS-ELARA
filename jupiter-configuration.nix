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
    ./modules/morse/mm8108.nix
    ./modules/morse/morse-driver.nix
    ./modules/morse/morse-tools.nix
    ./modules/jupiter/radiacode.nix
    ./modules/jupiter/jupiter-esp.nix
    ./modules/programs.nix
    ./modules/rust.nix
    ./modules/user.nix
    ./modules/wireless.nix
  ];

  # hardware.tevs.enable = true;s

 
  system.stateVersion = "25.11";# Pinned, DON"T CHANGE

  services.udev.extraRules = ''
    # /etc/udev/rules.d/99-radiacode.rules
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="f123", MODE="0660", GROUP="dialout", SYMLINK+="radia_code"
  '';

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

  # Group for GPIO access
  users.groups.gpio = { };
  users.groups.video = { };


  # General Config
  nixpkgs.config.allowUnfree = true;

  hardware.enableRedistributableFirmware = true;

  networking.hostName = "jupiter";
  # networking.useNetworkd = true;
  # networking.wireless.iwd = { enable = true; settings.Settings.AutoConnect = true; };
  
  security.sudo.wheelNeedsPassword = false;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.networkmanager.unmanaged = [ "wlan3" "wlan1" ];

  environment.etc."esp32/wpa_ap.conf".text = ''
    ctrl_interface=/var/run/wpa_supplicant_esp
    ctrl_interface_group=wheel
    update_config=1
    country=US

    network={
        ssid="ELARA_ESP_LINK"
        mode=2               # AP Mode
        key_mgmt=WPA-PSK
        psk="ElaraFlight"
        frequency=2437       # Channel 6
    }
  '';

  systemd.services.esp-ap = {
    description = "ESP32 Access Point (wlan3)";
    bindsTo = [ "sys-subsystem-net-devices-wlan3.device" ];
    after = [ "sys-subsystem-net-devices-wlan3.device" "load-esp-driver.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.wpa_supplicant}/bin/wpa_supplicant -Dnl80211 -iwlan3 -c/etc/esp32/wpa_ap.conf -s";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  networking.interfaces.wlan3.ipv4.addresses = [{
    address = "192.168.4.1";
    prefixLength = 24;
  }];

}
