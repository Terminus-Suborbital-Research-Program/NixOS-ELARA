{ config, pkgs, rust-overlay, ... }: 

let
  # Cached Kernel Definition
  # kernelBundle = pkgs.linuxAndFirmware.v6_12_34; 
  kernelBundle = pkgs.linuxAndFirmware.v6_6_31;
in {
  
  boot.loader.raspberryPi.firmwarePackage = kernelBundle.raspberrypifw;
  boot.kernelPackages = kernelBundle.linuxPackages_rpi5;

  # Note this should be disabled eventually if brcmfmac is suspected to cause a problem
  boot.kernelParams = [ 
    "quiet" 
    "loglevel=3"        # Only show Errors and above, hide Warnings/Info
    "systemd.show_status=auto" 
    "rd.udev.log_level=3" 
  ];

  nixpkgs.overlays = [
    rust-overlay.overlays.default
    (self: super: {
      inherit (kernelBundle) raspberrypiWirelessFirmware;
      inherit (kernelBundle) raspberrypifw;
    })
  ];
}