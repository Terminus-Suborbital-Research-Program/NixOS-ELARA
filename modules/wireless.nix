{ config, pkgs, lib, ... }: {

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true; 
    };
  };

  services.zerotierone = {
    enable = true;
    joinNetworks = [ "a581878f7d3a5d76" ];
  };

  services.openssh.enable = true;

  hardware.bluetooth.enable = true;


  hardware.enableRedistributableFirmware = true;
  networking.networkmanager.enable = lib.mkOverride 0 false;
  networking.useDHCP = lib.mkDefault true;
  networking.wireless = {
    enable = true;
    networks."Student5".pskRaw =
      "6b478d4e5dd413b48e554afe74144e44823cf57bc183d19d7d410d0737c35fa1";
    # networks."Staff5".pskRaw =
    #   "66fe08674eda745336a1ac1dddf2e7fef7d1374a6c73184194a05332e0648ff1";
    networks."Pixel_8877".pskRaw =
      "8f866ba6b78b2fc0ba26bf81b232f02f7b4f4f0141018507e0bd9e2761dbd9b4";
  };
}
