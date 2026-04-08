{ config, pkgs, lib, ... }:

let
  kernel = config.boot.kernelPackages.kernel;
  kernelSrc = kernel.src;

  tnSource = pkgs.fetchFromGitHub {
    owner = "TechNexion-Vision";
    repo = "tn-rpi-camera-driver";
    rev = "tn_rpi_kernel-6.12";
    hash = "sha256-jBEy7JXL/ibqDQDfGDOCAMDSQAPgRDZhjal5zAC3zVE=";
  };

  dtsSource = ./.;

  # OOT Kernel mod
  tevsModule = config.boot.kernelPackages.callPackage ({ stdenv, kernel }:
    stdenv.mkDerivation {
      pname = "tevs-oot-driver";
      version = "6.12-tn";

      src = tnSource;
      sourceRoot = "source/drivers/media/i2c/tevs";

      nativeBuildInputs = kernel.moduleBuildDependencies;

      buildPhase = ''
        make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
          M=$(pwd) \
          CONFIG_VIDEO_TEVS=m \
          modules
      '';
      installPhase = ''
        mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
        cp tevs.ko $out/lib/modules/${kernel.modDirVersion}/extra/
      '';
    }
  ) {};


  #  Device tree overlays
  tevsDtbo = pkgs.stdenv.mkDerivation {
    pname = "tevs-dtbo";
    version = "6.12-tn";
    src = dtsSource;
    
    nativeBuildInputs = [ pkgs.dtc ];

    buildPhase = ''
      mkdir -p compiled_overlays
      
      for dts_file in ./*.dts; do
        filename=$(basename "$dts_file" .dts)
        
        # Preprocess (pulling headers from the actual kernel source)
        cpp -nostdinc -undef -P -x assembler-with-cpp \
          -I "${kernelSrc}/include" \
          -I "${kernelSrc}/arch/arm64/boot/dts" \
          -I "${kernelSrc}/arch/arm64/boot/dts/overlays" \
          -I include \
          -I arch/arm64/boot/dts/overlays \
          "$dts_file" > "compiled_overlays/$filename.preprocessed.dts"
          
        # Compile
        dtc -@ -I dts -O dtb -o "compiled_overlays/$filename.dtbo" "compiled_overlays/$filename.preprocessed.dts"
      done

    '';

    installPhase = ''
      mkdir -p $out/overlays
      cp compiled_overlays/*.dtbo $out/overlays/
    '';
  };

in
{
  boot.extraModulePackages = [ tevsModule ];
  boot.kernelModules = [ "tevs" ];

  boot.extraModprobeConfig = ''
    softdep tevs pre: gpio_pca953x
  '';

  hardware.raspberry-pi.config.all.dt-overlays = {
    "tevs,cam0" = {
      enable = true;
      params = {
      };
    };
    "tevs,cam1" = {
      enable = true;
      params = {
      };
    };
  };

  system.activationScripts.tevs-overlays = ''
    mkdir -p /boot/firmware/overlays
    cp ${tevsDtbo}/overlays/*.dtbo /boot/firmware/overlays/
  '';

  services.udev.extraRules = ''
    # When an rp1-cfe media device appears start the script
    SUBSYSTEM=="media", KERNEL=="media*", ATTRS{model}=="rp1-cfe", TAG+="systemd", ENV{SYSTEMD_WANTS}+="tevs-media-setup@%k.service"
  '';

  systemd.services."tevs-media-setup@" = {
    description = "Configure TEVS Camera Pipeline on %I";
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    
    path = [ pkgs.v4l-utils pkgs.gnugrep pkgs.coreutils pkgs.gawk];
    
    scriptArgs = "%I";
    
    script = ''
      mdev="/dev/$1"
      echo "Udev triggered configuration for $mdev"

      media-ctl -d "$mdev" -p > /dev/null 2>&1

      tevs_entity=$(media-ctl -d "$mdev" -p 2>/dev/null | grep -o 'entity [0-9]*: tevs [^ ]*' | cut -d' ' -f3- || true)

      if [ -n "$tevs_entity" ]; then
        echo "Found TEVS sensor '$tevs_entity' on $mdev. Applying routing..."

        vnode=$(media-ctl -d "$mdev" -p | grep -A 5 "entity.*rp1-cfe-csi2_ch0" | grep "device node name" | awk '{print $4}')

        echo "TEVS sensor '$tevs_entity' on $mdev is mapped to $vnode"
        
        media-ctl -d "$mdev" -l "'csi2':4 -> 'rp1-cfe-csi2_ch0':0 [1]"
        media-ctl -d "$mdev" -V "'$tevs_entity':0 [fmt:UYVY8_1X16/1280x720 field:none]"
        media-ctl -d "$mdev" -V "'csi2':0 [fmt:UYVY8_1X16/1280x720 field:none]"
        media-ctl -d "$mdev" -V "'csi2':4 [fmt:UYVY8_1X16/1280x720 field:none]"
        
        echo "Pipeline $mdev ready for V4L2 grab."

        if [[ "$tevs_entity" == *"10-0048"* ]]; then
          ln -sf "$vnode" /dev/tevs-main
        else
          ln -sf "$vnode" /dev/tevs-aux
        fi
      else
        echo "No TEVS sensor attached to $mdev. Exiting cleanly."
      fi
    '';
  };

  environment.interactiveShellInit = ''
    # csi0 cam
    tevs0r() {
      # If no argument is provided, default to test_main.yuv
      local filename="''${1:-test_main.yuv}"
      
      echo "Grabbing frame from /dev/tevs-main to $filename..."
      v4l2-ctl -d /dev/tevs-main --set-fmt-video=width=1280,height=720,pixelformat=UYVY --stream-mmap --stream-count=1 --stream-to="$filename"
    }

    # Function for the csi2 cam
    tevs1r() {
      # If no argument is provided, default to test_aux.yuv
      local filename="''${1:-test_aux.yuv}"
      
      echo "Grabbing frame from /dev/tevs-aux to $filename..."
      v4l2-ctl -d /dev/tevs-aux --set-fmt-video=width=1280,height=720,pixelformat=UYVY --stream-mmap --stream-count=1 --stream-to="$filename"
    }

    # output grayscale tiff
    tevs0() {
      local filename="''${1:-starfield_main.tiff}"
      
      echo "Grabbing Luma frame from /dev/tevs-main to $filename..."
      
      # Pipe v4l2-ctl stdout (-) to ffmpeg stdin (-)
      v4l2-ctl -d /dev/tevs-main --set-fmt-video=width=1280,height=720,pixelformat=UYVY --stream-mmap --stream-count=1 --stream-to=- | \
      ffmpeg -y -f rawvideo -pixel_format uyvy422 -video_size 1280x720 -i - -pix_fmt gray "$filename"
    }

    # Output Grayscale tiff for csi1 camera
    tevs1() {
      local filename="''${1:-starfield_aux.tiff}"
      
      echo "Grabbing Luma frame from /dev/tevs-aux to $filename..."
      
      v4l2-ctl -d /dev/tevs-aux --set-fmt-video=width=1280,height=720,pixelformat=UYVY --stream-mmap --stream-count=1 --stream-to=- | \
      ffmpeg -y -f rawvideo -pixel_format uyvy422 -video_size 1280x720 -i - -pix_fmt gray "$filename"
    }
  '';
}