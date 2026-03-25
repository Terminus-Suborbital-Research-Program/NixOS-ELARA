{ config, pkgs, lib, ... }: 
stdenv.mkDerivation {
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
    
    # appendRunpaths = [ "${placeholder "out"}/opt/pylon/lib" ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/opt/pylon
      tar -C $out/opt/pylon -xzf ./pylon-*.tar.gz

      ln -s $out/opt/pylon/include $out/include

      runHook postInstall
    '';

}

  