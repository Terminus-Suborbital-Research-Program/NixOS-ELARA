{ config, pkgs, lib, ... }:
let
morseCli = pkgs.stdenv.mkDerivation {
  pname = "morse-cli";
  version = "1.16.4"; 

  src = pkgs.fetchFromGitHub {
    owner = "MorseMicro";
    repo = "morse_cli";
    rev = "master"; 
    sha256 = "sha256-EhrKMMbWJ6gweAt2EudyO7vHZ9ITjRYagE4k+QuUnOo=";
  };

  nativeBuildInputs = [ pkgs.pkg-config pkgs.debianutils ];
  buildInputs = [ pkgs.libnl pkgs.libusb1 ];
  postUnpack = "chmod -R u+w source";
  buildPhase = ''
  export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -I${pkgs.libnl.dev}/include/libnl3 -I${pkgs.libusb1.dev}/include/libusb-1.0 -Wno-error -Wno-unused-result"
      
        make CONFIG_MORSE_TRANS_NL80211=1
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp morse_cli $out/bin/
    # Symlink morsectrl if compiled
  '';
};

wpaConfContent = ''
    ctrl_interface=/var/run/wpa_supplicant_s1g
    ctrl_interface_group=wheel
    update_config=1
    country=US
    
    # S1G / HaLow Specifics
    pmf=2
    sae_pwe=1
    
    # P2P Settings
    device_name=ODIN_Flight_Computer
    device_type=1-0050F204-1
    config_methods=virtual_display virtual_push_button keypad
    
    # Station Network Block (from APPNOTE-24 example)
    network={
        ssid="MorseMicro"
        key_mgmt=SAE
        pairwise=CCMP
        psk="12345678"
        priority=2
    }
  '';

  wpaSupplicantS1G = pkgs.stdenv.mkDerivation {
    pname = "wpa-supplicant-s1g";
    version = "1.16.4";

  src = pkgs.fetchFromGitHub {
    owner = "MorseMicro";
    repo = "hostap";
    rev = "refs/heads/v1.15"; # driver release version
    sha256 = "sha256-IOJore8wkMGcNFZ+87QuEZLJOmf2yo33jE2zhKTCaKE=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ pkgs.libnl pkgs.openssl pkgs.dbus pkgs.glibc.dev ];
  postUnpack = "chmod -R u+w source";
  preBuild = ''
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE $(pkg-config --cflags dbus-1)"
      export NIX_LDFLAGS="$NIX_LDFLAGS $(pkg-config --libs dbus-1)"
    '';
  setSourceRoot = "sourceRoot=`echo source/wpa_supplicant`"; 
    configurePhase = ''
      ls

      # Start with the defconfig if it exists, or create new
      if [ -f defconfig ]; then
        cp defconfig .config
      else
        touch .config
      fi

      # Inject the critical P2P and Driver settings
      cat >> .config <<EOF
      CONFIG_DRIVER_NL80211=y
      CONFIG_LIBNL32=y
      CONFIG_CTRL_IFACE=y
      CONFIG_CTRL_IFACE_DBUS_NEW=y
      CONFIG_CTRL_IFACE_DBUS_INTRO=y
      
      # Security & S1G
      CONFIG_SAE=y
      CONFIG_S1G=y
      CONFIG_OWE=y
      CONFIG_SUITEB192=y
      
      # P2P (Wi-Fi Direct) Stack
      CONFIG_P2P=y
      CONFIG_AP=y
      CONFIG_WPS=y
      CONFIG_WIFI_DISPLAY=y
      
      # Debugging
      CONFIG_DEBUG_FILE=y
      CONFIG_DEBUG_SYSLOG=y
      EOF
      cd ..

      # Configure hostapd
      cd hostapd
      if [ -f defconfig ]; then cp defconfig .config; else touch .config; fi
      cat >> .config <<EOF
      CONFIG_DRIVER_NL80211=y
      CONFIG_LIBNL32=y
      CONFIG_SAE=y
      CONFIG_S1G=y
      CONFIG_OWE=y
      CONFIG_IEEE80211W=y
      EOF
      cd ..
    '';

  buildPhase = ''
    #make BINDIR=$out/sbin \
    #          EXTRA_CFLAGS="-I. -I../src -I${pkgs.libnl.dev}/include/libnl3 -I${pkgs.openssl.dev}/include" \
    #          LIBS="-lnl-3 -lnl-genl-3 -lssl -lcrypto -ldbus-1"

    export EXTRA_CFLAGS="-I. -I../src -I${pkgs.libnl.dev}/include/libnl3 -I${pkgs.openssl.dev}/include -I${pkgs.dbus.dev}/include/dbus-1.0 -I${pkgs.dbus.lib}/lib/dbus-1.0/include -I${pkgs.glibc.dev}/include"
    export LIBS="-lnl-3 -lnl-genl-3 -lnl-route-3 -lssl -lcrypto -ldbus-1 -lm"

    # Build wpa_supplicant
    cd wpa_supplicant
    make -j$(nproc) BINDIR=$out/sbin EXTRA_CFLAGS="$EXTRA_CFLAGS" LIBS="$LIBS"
    cd ..

    # Build hostapd 
    cd hostapd
    make -j$(nproc) BINDIR=$out/sbin EXTRA_CFLAGS="$EXTRA_CFLAGS" LIBS="$LIBS"
    cd ..
  '';

  installPhase = ''
    
    mkdir -p $out/sbin

    ls

    cp wpa_supplicant/wpa_supplicant_s1g $out/sbin/wpa_supplicant_s1g
    cp wpa_supplicant/wpa_cli_s1g $out/sbin/wpa_cli_s1g
    cp wpa_supplicant/wpa_passphrase_s1g $out/sbin/wpa_passphrase_s1g

    cp hostapd/hostapd_s1g $out/sbin/hostapd_s1g
    cp hostapd/hostapd_cli_s1g $out/sbin/hostapd_cli_s1g
  '';

  
};
in 
  # environment.systemPackages = [
  #   morseCli 
  #   wpaSupplicantS1G 
  #   pkgs.iw 
  #   pkgs.libnl 
  #   pkgs.openssl
  # ];

  # environment.etc."morse/wpa_supplicant.conf".text = wpaConfContent;

  # systemd.services.morse-supplicant = {
  #   bindsTo = [ "sys-subsystem-net-devices-wlan1.device" ];
  #   after = [ "sys-subsystem-net-devices-wlan1.device" ];
  #   description = "Morse Micro HaLow Supplicant (S1G + P2P)";
  #   # after = [ "network.target" ];
  #   wantedBy = [ "multi-user.target" ];
    
  #   serviceConfig = {
  #     Type = "simple";
  #     User = "root"; 
  #     RuntimeDirectory = "wpa_supplicant_s1g"; 
      
  #     # -D nl80211 : Use the modern Linux wireless driver
  #     # -i wlan1   : The interface name (verify this on your device!)
  #     # -c ...     : The config file path
  #     # -s         : Output to syslog (journalctl)
  #     ExecStart = "${wpaSupplicantS1G}/sbin/wpa_supplicant_s1g -Dnl80211 -iwlan1 -c/etc/morse/wpa_supplicant.conf -s";
      
  #     Restart = "always";
  #     RestartSec = "5s";
  #   };
  # };

  lib.mkMerge [
  
  # --- GLOBAL CONFIGURATION (Applies to both Jupiter and Odin) ---
  {
    environment.systemPackages = [
      morseCli 
      wpaSupplicantS1G 
      pkgs.iw 
      pkgs.libnl 
      pkgs.openssl
    ];

    # Ensure NetworkManager leaves the HaLow interface alone
    networking.networkmanager.unmanaged = [ "wlan1" "wlu1" ];

    # Maximize Tx Power dynamically on both machines when interface comes up
    # systemd.services.morse-txpower = {
    #   description = "Set Morse Micro MM8108 TX Power";
    #   bindsTo = [ "sys-subsystem-net-devices-wlan1.device" ];
    #   after = [ "sys-subsystem-net-devices-wlan1.device" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     RemainAfterExit = true;
    #     ExecStart = "${pkgs.iw}/bin/iw dev wlan1 set txpower fixed 1000";
    #   };
    # };
  }

  # Jupiter AP / Group owner conf
  (lib.mkIf (config.networking.hostName == "jupiter") {
    environment.etc."morse/wpa_s1g.conf".text = ''
      ctrl_interface=/var/run/wpa_supplicant_s1g
      ctrl_interface_group=wheel
      update_config=1
      country=US
      pmf=2
      sae_pwe=1
      network={
          ssid="ELARA_HALOW_LINK"
          mode=2
          key_mgmt=SAE
          psk="ElaraHalow"
          frequency=915
      }
    '';

    environment.etc."morse/hostapd_s1g.conf".text = ''
      ctrl_interface=/var/run/hostapd_s1g
      interface=wlan1
      driver=nl80211
      hw_mode=a
      ieee80211ah=1
      channel=44
      op_class=71
      country_code=US
      s1g_prim_chwidth=1
      ssid=ELARA_HALOW_LINK
      wpa=2
      wpa_key_mgmt=SAE
      rsn_pairwise=CCMP
      sae_password=ElaraHalow
      ieee80211w=2
      sae_pwe=1
    '';

    # systemd.services.morse-supplicant = {
    #   description = "Morse Micro HaLow AP (wlan1)";
    #   bindsTo = [ "sys-subsystem-net-devices-wlan1.device" ];
    #   after = [ "sys-subsystem-net-devices-wlan1.device" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     Type = "simple";
    #     RuntimeDirectory = "wpa_supplicant_s1g";
    #     ExecStart = "${wpaSupplicantS1G}/sbin/wpa_supplicant_s1g -Dnl80211 -iwlan1 -c/etc/morse/wpa_s1g.conf -s";
    #     Restart = "always";
    #     RestartSec = "5s";
    #   };
    # };

    # systemd.services.morse-hostapd = {
    #   description = "Morse Micro HaLow AP (wlan1)";
    #   bindsTo = [ "sys-subsystem-net-devices-wlan1.device" ];
    #   after = [ "sys-subsystem-net-devices-wlan1.device" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     Type = "simple";
    #     ExecStart = "${wpaSupplicantS1G}/sbin/hostapd_s1g /etc/morse/hostapd_s1g.conf -s";
    #     Restart = "always";
    #     RestartSec = "5s";
    #   };
    # };

    # systemd.services.morse-link-test-server = {
    #   description = "Morse Micro HaLow Link Test Server";
    #   requires = [ "morse-hostapd.service" ];
    #   after = [ "morse-hostapd.service" ];
    #   wantedBy = [ "multi-user.target" ];
      
    #   path = [ pkgs.util-linux pkgs.iperf3 pkgs.iw wpaSupplicantS1G ];
      
    #   script = ''
    #     echo " Unblocking RFKill "
    #     rfkill unblock all

    #     echo " Jupiter Interface Status "
    #     ip a show wlan1

    #     echo " Connected Stations "
    #     sudo hostapd_s1g /etc/morse/hostapd_s1g.conf -d
    #     #sudo hostapd_cli_s1g -p /var/run/hostapd_s1g all_sta
    #     # iw dev wlan1 station dump || true

    #     echo " Starting iperf3 Server "
    #     # exec replaces the shell with the iperf3 process
    #     exec iperf3 -s
    #   '';
      
    #   serviceConfig = {
    #     Type = "simple";
    #     Restart = "always";
    #     RestartSec = "10s";
    #   };
    # };

    networking.interfaces.wlan1.ipv4.addresses = [{
      address = "10.0.0.1";
      prefixLength = 24;
    }];
  })

  # Odin client conf
  (lib.mkIf (config.networking.hostName == "odin") {
    environment.etc."morse/wpa_s1g.conf".text = ''
      ctrl_interface=/var/run/wpa_supplicant_s1g
      ctrl_interface_group=wheel
      update_config=1
      country=US
      pmf=2
      sae_pwe=1
      network={
          ssid="ELARA_HALOW_LINK"
          scan_ssid=1
          key_mgmt=SAE
          psk="ElaraHalow"
      }
    '';

    environment.etc."morse/hostapd_s1g.conf".text = ''
      ctrl_interface=/var/run/hostapd_s1g
      interface=wlu1
      driver=nl80211
      hw_mode=a
      ieee80211ah=1
      channel=44
      op_class=71
      country_code=US
      s1g_prim_chwidth=1
      ssid=ELARA_HALOW_LINK
      wpa=2
      wpa_key_mgmt=SAE
      rsn_pairwise=CCMP
      sae_password=ElaraHalow
      ieee80211w=2
      sae_pwe=1
    '';

    # systemd.services.morse-link-test-client = {
    #   description = "Morse Micro HaLow Link Test Client";
    #   requires = [ "morse-supplicant.service" ];
    #   after = [ "morse-supplicant.service" ];
    #   wantedBy = [ "multi-user.target" ];
      
    #   path = [ pkgs.util-linux pkgs.iperf3 pkgs.iw pkgs.iproute2 pkgs.iputils wpaSupplicantS1G ];
      
    #   script = ''
    #     echo " Unblocking RFKill "
    #     rfkill unblock all

    #     echo "Waiting for Wi-Fi association and connection to Jupiter (10.0.0.1)..."
    #     # Ping Jupiter continuously until we get a response
    #     until ping -c 1 -W 1 10.0.0.1 >/dev/null 2>&1; do
    #       sleep 2
    #     done

    #     echo " Link Established! "
        
    #     echo " Odin Interface Status "
    #     ip a show wlu1

    #     echo " WPA Supplicant Status "
    #     wpa_cli_s1g -p /var/run/wpa_supplicant_s1g status || true

    #     echo " Link Layer Diagnostics "
    #     iw dev wlu1 link || true

    #     echo " 5-Packet Ping Test "
    #     ping -c 5 10.0.0.1

    #     echo " Running UDP Throughput Test (1 Mbps) "
    #     iperf3 -c 10.0.0.1 -u -b 1M
    #   '';
      
    #   serviceConfig = {
    #     # Oneshot means it runs the script to completion once per boot/restart
    #     Type = "oneshot";
    #     RemainAfterExit = true; 
    #   };
    # };

    # systemd.services.morse-supplicant = {
    #   description = "Morse Micro HaLow Client (wlu1)";
    #   bindsTo = [ "sys-subsystem-net-devices-wlu1.device" ];
    #   after = [ "sys-subsystem-net-devices-wlu1.device" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     Type = "simple";
    #     RuntimeDirectory = "wpa_supplicant_s1g";
    #     ExecStart = "${wpaSupplicantS1G}/sbin/wpa_supplicant_s1g -Dnl80211 -i wlu1 -c/etc/morse/wpa_s1g.conf -s";
    #     Restart = "always";
    #     RestartSec = "5s";
    #   };
    # };

    networking.interfaces.wlu1.ipv4.addresses = [{
      address = "10.0.0.2";
      prefixLength = 24;
    }];
  })

]

