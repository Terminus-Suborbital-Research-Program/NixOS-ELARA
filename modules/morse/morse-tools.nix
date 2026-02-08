{ config, pkgs, lib, ... }:
let
morseCli = pkgs.stdenv.mkDerivation {
  pname = "morse-cli";
  version = "1.16.4"; # Match your driver version

  src = pkgs.fetchFromGitHub {
    owner = "MorseMicro";
    repo = "morse_cli";
    rev = "master"; # Or a specific tag if available
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  # Dependencies from APPNOTE-24 
  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ pkgs.libnl pkgs.libusb1 ];

  # Fix hardcoded paths in Makefile if necessary, or just run make
  # The guide specifies this config flag [cite: 183]
  buildPhase = ''
    make CONFIG_MORSE_TRANS_NL80211=1
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp morse_cli $out/bin/
    # Optional: Symlink morsectrl if compiled
  '';
};

wpaSupplicantS1G = pkgs.stdenv.mkDerivation {
  pname = "wpa-supplicant-s1g";
  version = "1.16.4";

  src = pkgs.fetchFromGitHub {
    owner = "MorseMicro";
    repo = "hostap";
    rev = "master"; # Ensure this matches your driver release version
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ pkgs.pkg-config ];
  # Dependencies from APPNOTE-24 
  buildInputs = [ pkgs.libnl pkgs.openssl ];

  # Configure based on the guide [cite: 139]
  configurePhase = ''
    cd wpa_supplicant
    cp defconfig .config
    # You might need to echo additional configs here if needed
  '';

  # Compilation flags from APPNOTE-24 [cite: 148-152]
  buildPhase = ''
    make BINDIR=$out/sbin \
          CFLAGS="-I${pkgs.libnl.dev}/include/libnl3 -I${pkgs.openssl.dev}/include" \
          LIBS="-lnl-3 -lnl-genl-3 -lssl -lcrypto"
  '';

  installPhase = ''
    mkdir -p $out/sbin
    # The guide says these binaries are produced [cite: 160-162]
    cp wpa_supplicant_s1g $out/sbin/
    cp wpa_cli_s1g $out/sbin/
    cp wpa_passphrase_s1g $out/sbin/
  '';
};
in {
  environment.systemPackages = [
    morseCli 
    wpaSupplicantS1G 
    pkgs.iw 
    pkgs.libnl 
    pkgs.openssl
  ]
}