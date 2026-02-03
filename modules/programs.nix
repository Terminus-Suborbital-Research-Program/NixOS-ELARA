{ config, pkgs, lib, ... }: 
  let
    soapyextra = pkgs.soapysdr.override {
      extraPackages = [ 
        pkgs.soapyairspy 
        pkgs.soapyrtlsdr 
      ];
    };
  in 
  {
    environment.systemPackages = [
      soapyextra
    ] ++ (with pkgs; [
      git
      lazygit
      htop 
      tmux 
      wget 
      vim 
      usbutils 
      pciutils
      gcc 
      pkg-config

      # Rust
      (rust-bin.stable.latest.default.override { 
        extensions = [ "rust-src" "rust-analyzer" ]; 
      })

      # Hardware access
      libgpiod
      i2c-tools

      # raspberrypi-utils 
      # bluez
      # bluez-tools
      util-linux
      bc

      # Sensing
      soapysdr 
      soapyairspy 
      airspy 
      rtl-sdr 
      ffmpeg 
    ]);


    services.udev.packages = [ pkgs.airspy pkgs.rtl-sdr ];
    environment.variables.SOAPY_SDR_PLUGIN_PATH = "${soapyextra}/lib/SoapySDR/modules0.8";
  }
  

