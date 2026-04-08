{ stdenv, requireFile, autoPatchelfHook, libusb1, zlib}: 
let
  basler-pylon = stdenv.mkDerivation {
  pname = "basler-pylon";
  version = "26.03.1";

  src = requireFile {
      name = "pylon-26.03.1_linux-aarch64_setup.tar.gz";
      url = "https://www.baslerweb.com/en-us/downloads/software/3922788174/";
      sha256 = "11lhyildcsi7dhw3q4709j3am3gva1b5b6k9qj3ksgc132dc42gp";
      message = ''
        Basler Pylon is proprietary software.
        Please download the ARM64 Linux tarball from:
        https://www.baslerweb.com/en-us/downloads/software/3922788174/

        If that does not work, go to https://www.baslerweb.com/en-us/downloads/software/
        and find version pylon 26.03 and download the linux arm tar.gz
        
        Then add it to the Nix store by running:
        nix-prefetch-url file://$PWD/pylon-26.03.1_linux-aarch64_setup.tar.gz
      '';
    };

    nativeBuildInputs = [
      autoPatchelfHook
    ];

    buildInputs = [
      stdenv.cc.cc.lib
      libusb1
      zlib
    ];

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/opt/pylon
      
      tar -C $out/opt/pylon --strip-components=1 -xzf ./pylon-*.tar.gz

      rm -f $out/opt/pylon/bin/pylonviewer
      rm -f $out/opt/pylon/bin/pylonviewer-start-with-logging
      rm -f $out/opt/pylon/bin/ipconfigurator
      rm -f $out/opt/pylon/bin/PylonGigEConfigurator
      rm -f $out/opt/pylon/bin/PylonAIAgent
      rm -f $out/opt/pylon/bin/qt.conf

      rm -rf $out/opt/pylon/lib/Qt
      rm -rf $out/opt/pylon/lib/pylonviewer
      rm -rf $out/opt/pylon/lib/pylondataprocessingplugins
      rm -rf $out/opt/pylon/lib/dataprocessingpluginsb

      rm -f $out/opt/pylon/lib/libPylonDataProcessingGui*
      
      ln -s $out/opt/pylon/include $out/include

      runHook postInstall
    '';

}; 

in 
{
  environment.systemPackages = [ basler-pylon ];

  services.udev.extraRules = ''
    # Basler USB3 Vision Cameras
    SUBSYSTEM=="usb", ATTRS{idVendor}=="2676", MODE="0666"
  '';

}
  