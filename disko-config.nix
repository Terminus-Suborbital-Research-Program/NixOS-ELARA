{ pkgs, ... }:{
  disko.imageBuilder.qemu = (import pkgs.path { system = "x86_64-linux"; }).qemu + "/bin/qemu-system-aarch64";
  disko.devices = {
    disk = {
      main = {
        # For SD cards, this is usually /dev/mmcblk0
        device = "/dev/mmcblk0"; 
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            firmware = {
              size = "512M";
              type = "EF00"; 
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/firmware";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}