{ config, pkgs, lib, spiDisablerDtbo, ... }:

{
  imports = [ ./esp.nix ];

  # NVMD repo style
  system.activationScripts.esp-overlays = ''
    mkdir -p /boot/firmware/overlays
    cp ${spiDisablerDtbo}/overlays/*.dtbo /boot/firmware/overlays/
  '';

  hardware.raspberry-pi.config.all.dt-overlays = {
    "spi_disabler" = { enable = true; params = {}; };
  };
  hardware.raspberry-pi.config.all.base-dt-params = {
    spi = {
      enable = true;
      value = "on";
    };
  };

  # client config
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
    after = [ "sys-subsystem-net-devices-wlan3.device" "load-esp-driver.service" ];
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