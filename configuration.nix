{ config, pkgs, ... }:

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
    ./hardware-pi-5/hardware-pi-5.nix
    ./hardware-pi-5/kernel.nix
    ./hardware-pi-5/pi5-configtxt.nix
    ./modules/morse/mm8108.nix
    ./modules/morse/morse-driver.nix
    ./modules/morse/morse-tools.nix
    ./modules/jupiter/radiacode.nix
    ./modules/odin/odin-esp.nix
    ./modules/odin/tevs.nix
    ./modules/programs.nix
    ./modules/rust.nix
    ./modules/user.nix
    ./modules/wireless.nix
  ];


 
  system.stateVersion = "25.11";# Pinned, DON"T CHANGE

  services.udev.extraRules = ''
    # /etc/udev/rules.d/99-radiacode.rules
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="f123", MODE="0660", GROUP="dialout", SYMLINK+="radia_code"
  '';

  # General Config
  nixpkgs.config.allowUnfree = true;

  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = true;

  networking.hostName = "odin";
  # networking.useNetworkd = true;
  # networking.wireless.iwd = { enable = true; settings.Settings.AutoConnect = true; };
  
  security.sudo.wheelNeedsPassword = false;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.networkmanager.unmanaged = [ "wlan1" "wlan3"];

  # esp32 odin config
  environment.etc."esp32/wpa_client.conf".text = ''
    ctrl_interface=/var/run/wpa_supplicant_esp
    ctrl_interface_group=wheel
    update_config=1
    country=US

    network={
        ssid="ELARA_ESP_LINK"
        scan_ssid=1
        key_mgmt=WPA-PSK
        psk="ElaraFlight"
    }
  '';

  systemd.services.esp-client = {
    description = "ESP32 Client (wlan3)";
    bindsTo = [ "sys-subsystem-net-devices-wlan3.device" ];
    after = [ "sys-subsystem-net-devices-wlan3.device" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.wpa_supplicant}/bin/wpa_supplicant -Dnl80211 -iwlan3 -c/etc/esp32/wpa_client.conf -s";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  networking.interfaces.wlan3.ipv4.addresses = [{
    address = "192.168.4.2";
    prefixLength = 24;
  }];

}
