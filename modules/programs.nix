{ pkgs, ... }: {
  
  environment.systemPackages = with pkgs; [
    # git 
    lazygit
    htop 
    tmux 
    wget 
    vim 
    usbutils 
    pciutils
    
    (rust-bin.stable.latest.default.override { 
      extensions = [ "rust-src" "rust-analyzer" ]; 
    })
    
    soapysdr 
    soapyairspy 
    airspy 
    rtl-sdr 
    ffmpeg 
    gcc 
    pkg-config
  ];

  services.udev.packages = [ pkgs.airspy pkgs.rtl-sdr ];
}
