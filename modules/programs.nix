{ pkgs, ... }: {
  
  environment.systemPackages = with pkgs; [
    # System
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

    # Sensing
    soapysdr 
    soapyairspy 
    airspy 
    rtl-sdr 
    ffmpeg 
  ];

  services.udev.packages = [ pkgs.airspy pkgs.rtl-sdr ];
}
