{ lib, config, pkgs, ... }: { # Set a static IP on the "downstream" interface
  networking.interfaces."end0" = {
    useDHCP = false;
    ipv4.addresses = [{
      address = "10.0.0.1";
      prefixLength = 24;
    }];
  };
  networking.firewall.extraCommands = ''
    # Set up SNAT on packets going from downstream to the wider internet
    iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE

    # Accept all connections from downstream. May not be necessary
    iptables -A INPUT -i enp2s0 -j ACCEPT
  '';
  # Run a DHCP server on the downstream interface
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
        pools = [{ pool = "10.0.0.2 - 10.0.0.255"; }];
        subnet = "10.0.0.1/24";
      }];
      valid-lifetime = 4000;
      option-data = [{
        name = "routers";
        data = "10.0.0.1";
      }];
    };
  };
}
