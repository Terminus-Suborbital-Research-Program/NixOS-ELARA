# JUPITER Operating System Configuation
This is the operating system configuration `nixos` flake for our ejectable interferometer ODIN and our spacecraft bus JUPITER. It will boot up a chosen system into a headless environment - the only offline item will be the ZeroTier VPN, that must be provisioned by Ethan Pascuales in order to run.

# Nix Commands

**Rebuild the system with new changes to the nix flake:**
nixos-rebuild switch --flake .#odin

**Build new system without replacing the currently running one (useful for validating if you can compile all packages):**
nix build .#nixosConfigurations.odin.config.system.build.toplevel

**Test to see what packages will be build and what will be pulled from the cache:**
nix build .#nixosConfigurations.odin.config.system.build.toplevel --dry-run

### Managing Nix Generations

Every time you run `nixos-rebuild switch`, NixOS creates a new system generation. If you fill up the Pi's storage or need to see which version is active, use these commands.

List all current system generations:

``` shell
nix-env -p /nix/var/nix/profiles/system --list-generations
```

Check exactly which generation the system is currently booted into (useful if you suspect the bootloader failed to update):

```
readlink /nix/var/nix/profiles/system
```

Clear out old generations to free up space on the Pi (this removes all generations except the active one):

```shell
sudo nix-collect-garbage -d
```
# SSH

## If you are added to the zero-tier network:

On a terminal on your computer, type:
```shell
sudo zerotier-one -d
```

This will connect you to the vpn while your computer is on (you have to redo this every time you restart your computer)

Then if a pi with odin flashed is running, you can check to see if your laptop can identify it with:

```shell
ping odin.local
```

And connect to it with

```shell
ssh terminus@odin.local
```

## If you are not on the zero-tier network or are just suspicious it's not working but wifi on the pi still is:

Connect the pi to a keyboard and monitor, and type

```shell
ip addr show
```

You should be able to view the address of odin with in the inet subsection of the wlan0 section:

E.g. The four x.x.x.x following inet like highlighted in the example below.

wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000  
   link/ether 94:b6:09:87:b1:8a brd ff:ff:ff:ff:ff:ff  
   inet **10.0.0.222**/24 brd 10.0.0.255 scope global dynamic noprefixroute wlan0  
      valid_lft 85038sec preferred_lft 85038sec  
   inet6 fe80::ba45:a1e0:5abd:efc8/64 scope link noprefixroute    
      valid_lft forever preferred_lft forever

Following this example: (replace 10.0.0.222 with whatever address pops up)

```shell
ssh terminus@10.0.0.222
```

When prompted for password, the password is terminus



## Linux Troubleshooting tips

**Diagnostic Message**: Shows kernel diagnostics, which includes the success or failures of module/driver loading:

Base command:
```shell
sudo dmesg
```

Looking for somehting specific: (replace esp with morse, or whatever keyword is associated with the driver you're looking for)
``` shell
sudo dmesg | grep esp32
```

Look at tail end of dmesg to see 10 latest lines of the kernel buffer - if you just made a change and want to see how the system reacted:

``` shell
sudo dmesg | tail
```

Or with specific number of lines (replace 15 with however many lines):

``` shell
sudo dmesg | tail -n 15
```

**List Modules**: List all currently loaded kernel modules. Useful for validating a module is properly loaded


Base command - list all modules:
```shell
lsmod
```

Find specific module
```shell
lsmod esp32_spi
```

Load a module into the kernel:
```shell
sudo modprobe esp32_spi
```

Remove a module from running in th kernel:
```shell
sudo modprobe -r esp32_spi
```

View detailed information about a compiled module
```
modinfo esp32_spi
```

**View logs for a service**

Example targeting the wpa_supplicant service. Replace with whichever service you want to view the logs of. -e lets you view the end e.g. most recent logs.
```shell
journalctl -u wpa_supplicant -e
```


**Restart a service

Replace wpa_supplicant with any valid service
```shell
sudo systemctl restart wpa_supplicant
```
