{ pkgs, ... }: {
  boot.kernelModules = [ "st_lsm6dsx_i2c" ]; # IIO ST driver

  # Device tree overlay
  hardware.deviceTree.enable = true;
  hardware.deviceTree.overlays = [{
    name = "lsm6dsl";
    dtsText = ''
      /dts-v1/;
      /plugin/;

      / {
        /* <---- add this line */
        compatible = "brcm,bcm2711";

        fragment@0 {
          target = <&i2c1>;          /* CM4-S / RPi4 I²C-1 controller */
          __overlay__ {
            #address-cells = <1>;
            #size-cells   = <0>;

            lsm6dsl@6a {
              compatible       = "st,lsm6dsl";
              reg              = <0x6a>;
            };
          };
        };
      };
    '';
  }];

  # Udev rules to configure parameters
  services.udev.extraRules = ''
    # LSM6DSL: set ±16 g / 416 Hz
    ACTION=="add", SUBSYSTEM=="iio", KERNEL=="iio:device*", ATTR{name}=="lsm6dsl_accel", \
      RUN+="${pkgs.bash}/bin/sh -c 'echo 0.000488 > /sys/bus/iio/devices/%k/in_accel_scale; echo 416 > /sys/bus/iio/devices/%k/sampling_frequency'"

    # LSM6DSL: set ±2000 dps / 416 Hz
    ACTION=="add", SUBSYSTEM=="iio", KERNEL=="iio:device*", ATTR{name}=="lsm6dsl_gyro", \
      RUN+="${pkgs.bash}/bin/sh -c 'echo 0.017500 > /sys/bus/iio/devices/%k/in_anglvel_scale; echo 416 > /sys/bus/iio/devices/%k/sampling_frequency'"
  '';
}
