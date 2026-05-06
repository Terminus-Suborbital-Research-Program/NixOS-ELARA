{ lib, pkgs, ... }:

{
  # boot.loader.raspberryPi.firmwarePackage = lib.mkDefault pkgs.raspberrypifw;
  /*
  boot.kernelPackages = pkgs.linuxPackages_rpi4.extend (_self: super: {
    kernel = super.kernel.override {
      argsOverride = rec {
        version = "6.12.25";
        modDirVersion = "6.12.25";

        src = pkgs.fetchFromGitHub {
          owner = "raspberrypi";
          repo = "linux";
          rev = "stable_20250428";
          hash = "sha256-jVvJJJP4wSJm91jOz8QMXIujjGZ+IisTMCvusxarons=";
        };
      };
    };
  });
  */
  boot.kernelPackages = pkgs.linuxPackages_rpi4;
  # hardware.firmware = [ pkgs.raspberrypiWirelessFirmware ];

  # Note this should be disabled eventually if brcmfmac is suspected to cause a problem
  boot.kernelParams = [ 
    "quiet" 
    "loglevel=3"        # Only show Errors and above, hide Warnings/Info
    "systemd.show_status=auto" 
    "rd.udev.log_level=3" 
  ];
}
