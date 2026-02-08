{ pkgs, guard,... }: 
let 
# Extract the package for the Pi's architecture
radiaread = guard.packages.aarch64-linux.radiaread;
in {
  environment.systemPackages = [ radiaread ];

  systemd.tmpfiles.rules = [
    "d /home/terminus/rad_data 0755 terminus terminus - -"
  ];

  systemd.services.radiaread = {
    description = "Terminus Radiacode Data Reader";
    after = [ "systemd-tmpfiles-setup.service" ];
    path = [ radiaread ];
    serviceConfig = {
      User = "terminus";
      WorkingDirectory = "/home/terminus/";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /home/terminus/rad_data";
      ExecStart = "${radiaread}/bin/radiaread /home/terminus/rad_data";
      Restart = "always";
      RestartSec = "20s";
      Group = "dialout";
    };
    wantedBy = [ "multi-user.target" ];
  };
}