{ config, pkgs, rust-overlay, ... }: 

let
  # Cached Kernel Definition
  # kernelBundle = pkgs.linuxAndFirmware.v6_12_34; 
  kernelBundle = pkgs.linuxAndFirmware.v6_6_31;
in {
  
  boot.loader.raspberryPi.firmwarePackage = kernelBundle.raspberrypifw;
  boot.kernelPackages = kernelBundle.linuxPackages_rpi5;

  nixpkgs.overlays = [
    rust-overlay.overlays.default
    (self: super: {
      inherit (kernelBundle) raspberrypiWirelessFirmware;
      inherit (kernelBundle) raspberrypifw;
    })
  ];
}