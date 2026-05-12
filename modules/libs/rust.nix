{ pkgs, rust-overlay, ... }:

{
  nixpkgs.overlays = [
    rust-overlay.overlays.default
  ];

  environment.systemPackages = with pkgs; [
    (rust-bin.stable.latest.default.override {
      extensions = [ "rust-src" "rust-analyzer" ];
    })
  ];
}