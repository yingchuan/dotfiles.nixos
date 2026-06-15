{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../shared/system-module.nix
    ./wireguard.nix
  ];

  networking.hostName = "thinkpad-t14s-gen6";

  # COSMIC (thinkpad only) — try it alongside GNOME. cosmic-greeter
  # replaces the shared GDM here; it lists all sessions so GNOME stays
  # selectable. x300m-stx keeps GNOME + GDM untouched.
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;
  services.displayManager.gdm.enable = lib.mkForce false;

  # AMD GPU acceleration for Ollama (bound to localhost for security)
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    host = "127.0.0.1";
    port = 11434;
  };

  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 8080;
  };
}
