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
  buildInputs = [ pkgs.libnl pkgs.openssl pkgs.dbus ];
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
    '';

  buildPhase = ''
    #make BINDIR=$out/sbin \
    #          EXTRA_CFLAGS="-I. -I../src -I${pkgs.libnl.dev}/include/libnl3 -I${pkgs.openssl.dev}/include" \
    #          LIBS="-lnl-3 -lnl-genl-3 -lssl -lcrypto -ldbus-1"

    make -j$(nproc) BINDIR=$out/sbin \
            EXTRA_CFLAGS="-I. -I../src -I${pkgs.libnl.dev}/include/libnl3 -I${pkgs.openssl.dev}/include -I${pkgs.dbus.dev}/include/dbus-1.0 -I${pkgs.dbus.lib}/lib/dbus-1.0/include" \
            LIBS="-lnl-3 -lnl-genl-3 -lnl-route-3 -lssl -lcrypto -ldbus-1"
      '';

  installPhase = ''
    
    mkdir -p $out/sbin

    cp wpa_supplicant_s1g $out/sbin/wpa_supplicant_s1g
    cp wpa_cli_s1g $out/sbin/wpa_cli_s1g
    cp wpa_passphrase_s1g $out/sbin/wpa_passphrase_s1g
  '';

  
};
in {
  environment.systemPackages = [
    morseCli 
    wpaSupplicantS1G 
    pkgs.iw 
    pkgs.libnl 
    pkgs.openssl
  ];

  environment.etc."morse/wpa_supplicant.conf".text = wpaConfContent;

  systemd.services.morse-supplicant = {
    bindsTo = [ "sys-subsystem-net-devices-wlan1.device" ];
    after = [ "sys-subsystem-net-devices-wlan1.device" ];
    description = "Morse Micro HaLow Supplicant (S1G + P2P)";
    # after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      User = "root"; 
      RuntimeDirectory = "wpa_supplicant_s1g"; 
      
      # -D nl80211 : Use the modern Linux wireless driver
      # -i wlan1   : The interface name (verify this on your device!)
      # -c ...     : The config file path
      # -s         : Output to syslog (journalctl)
      ExecStart = "${wpaSupplicantS1G}/sbin/wpa_supplicant_s1g -Dnl80211 -iwlan1 -c/etc/morse/wpa_supplicant.conf -s";
      
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
