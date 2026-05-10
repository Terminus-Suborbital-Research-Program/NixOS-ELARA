{ lib, config, pkgs, ... }: 
{ 
  # Set a static IP on the "downstream" interface
  networking.interfaces."end0" = {
    useDHCP = false;
    ipv4.addresses = [{
      address = "192.168.50.1"; 
      prefixLength = 24;
    }];
  };

  networking.firewall.interfaces."end0" = {
    allowedTCPPorts = [ 22 ];   # Allow SSH
    allowedUDPPorts = [ 67 ];   # Allow DHCP requests
  };

  networking.nat = {
    enable = true;
    internalInterfaces = [ "end0" ];
    externalInterface = "wlan0";
  };

  # Enable packet forwarding in the kernel
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  # Run the DHCP server on the downstream interface
  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config = { interfaces = [ "end0" ]; };
      lease-database = {
        name = "/var/lib/kea/dhcp4.leases";
        persist = true;
        type = "memfile";
      };
      rebind-timer = 2000;
      renew-timer = 1000;
      subnet4 = [{
        id = 1;
        pools = [{ pool = "192.168.50.2 - 192.168.50.255"; }];
        subnet = "192.168.50.0/24";
      }];
      valid-lifetime = 4000;
      option-data = [{
        name = "routers";
        data = "192.168.50.1";
      }];
    };
  };
}
