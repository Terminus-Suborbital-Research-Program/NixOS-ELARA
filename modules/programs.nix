{ pkgs, ... }: {
  
  environment.systemPackages = with pkgs; [
    # System Tools
    # git 
    lazygit
    htop 
    tmux 
    wget 
    vim 
    usbutils 
    pciutils
    
    # Rust Development
    (rust-bin.stable.latest.default.override { 
      extensions = [ "rust-src" "rust-analyzer" ]; 
    })
    
    # SDR & Radio Astronomy
    soapysdr 
    soapyairspy 
    airspy 
    rtl-sdr 
    ffmpeg 
    gcc 
    pkg-config
  ];

  # Udev rules for SDR hardware
  services.udev.packages = [ pkgs.airspy pkgs.rtl-sdr ];
}
