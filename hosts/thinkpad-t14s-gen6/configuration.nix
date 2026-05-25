{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../shared/system-module.nix
  ];

  networking.hostName = "thinkpad-t14s-gen6";

  # AMD GPU acceleration for Ollama
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
  };

  services.open-webui.enable = true;
}
