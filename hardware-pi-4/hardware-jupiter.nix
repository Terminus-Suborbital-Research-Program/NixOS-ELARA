{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
boot.initrd.availableKernelModules = lib.mkForce [
    "vc4"          # Broadcom display
    "bcm2835_dma"  # DMA
    "i2c_bcm2835"  # I2C
    "xhci_pci"     # USB
    "usbhid"       # Keyboard
    "sdhci_iproc"  # SD Card
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];
  boot.blacklistedKernelModules =
    [ "bluetooth" "btusb" "btbcm" "btrtl" "btintel" "hci_uart" ];

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/NIXOS_SD"; # this is important!
    fsType = "ext4";
    options = [ "noatime" ];
  };

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.end0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlan0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
}

