{ config, lib, pkgs, nixos-raspberrypi, ... }: {
   # Filesystem
    boot.supportedFilesystems = lib.mkForce [ "vfat" "ext4" ];

    fileSystems = {
      "/boot/firmware" = {
        device = "/dev/disk/by-label/FIRMWARE";
        fsType = "vfat";
        options = [ "noatime" "noauto" "x-systemd.automount" "x-systemd.idle-timeout=1min" ];
      };
      "/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
        options = [ "noatime" ];
      };
    };
}