{ config, lib, pkgs, nixos-raspberrypi, ... }: {
   # Filesystem
    boot.loader.raspberryPi.bootloader = "kernel";
    # boot.supportedFilesystems = lib.mkForce [ "vfat" "ext4" ];
    # boot.zfs.enabled = false;
    # fileSystems = {
    #   "/boot/firmware" = {
    #     device = "/dev/disk/by-label/FIRMWARE";
    #     fsType = "vfat";
    #     options = [ "noatime" "noauto" "x-systemd.automount" "x-systemd.idle-timeout=1min" ];
    #   };
    #   "/" = {
    #     device = "/dev/disk/by-label/NIXOS_SD";
    #     fsType = "ext4";
    #     options = [ "noatime" ];
    #   };
    # };

    fileSystems = {
      "/boot/firmware" = {
        device = "/dev/disk/by-label/FIRMWARE";
        fsType = "vfat";
        # options = [ "nofail" "noauto" ];
      };
      "/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
      };
    };

    fileSystems."/boot/firmware".options = lib.mkForce [
      "noatime"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=1min"
    ];
    fileSystems."/".options = [ "noatime" ];
}