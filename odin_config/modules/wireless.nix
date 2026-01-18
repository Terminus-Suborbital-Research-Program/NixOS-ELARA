{ config, pkgs, ... }: {
  networking.wireless = {
    enable = true;
    networks."Staff5".pskRaw =
      "66fe08674eda745336a1ac1dddf2e7fef7d1374a6c73184194a05332e0648ff1";
    networks."Pixel_8877".pskRaw =
      "8f866ba6b78b2fc0ba26bf81b232f02f7b4f4f0141018507e0bd9e2761dbd9b4";
  };

  # Disable bluetooth
  hardware.bluetooth.enable = false;
}
