{ config, pkgs, lib, spiDisablerDtbo, ... }:

{
  imports = [ ./esp.nix ];

  hardware.deviceTree = {
    enable = true;
    overlays = [
      {
        name = "spi-disabler";
        filter = "*-rpi-4-b.dtb";
        dtboFile = "${spiDisablerDtbo}/overlays/spi_disabler.dtbo";
      }
      {
        filter = "*-rpi-4-b.dtb"; 
        name = "spi0-0cs";
        dtboFile = "${pkgs.device-tree_rpi.overlays}/spi0-0cs.dtbo";
      }
    ];
  };

  # ap config
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