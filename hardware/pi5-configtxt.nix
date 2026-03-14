{ config, pkgs, lib, ... }:

{
  hardware.raspberry-pi.config = {
    all = {
      options = {
        enable_uart = {
          enable = true;
          value = true;
        };

        uart_2ndstage = {
          enable = true;
          value = true;
        };

        camera_auto_detect = {
          enable = true;
          value = false;
        };
      };

      base-dt-params = {
        pciex1 = {
          enable = true;
          value = "on";
        };

        pciex1_gen = {
          enable = true;
          value = "3";
        };
      };

      dt-overlays = {
        tevs-rpi22 = {
          enable = true;
          params = {
            cam0.enable = true;
          };
        };
      };
    };
  };

  boot.extraModprobeConfig = ''
    softdep tevs pre: gpio_pca953x
  '';
}