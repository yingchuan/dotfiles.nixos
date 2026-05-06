# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
    ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "thinkpad-t14s-gen6";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Taipei";

  # Internationalisation
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_TW.UTF-8";
    LC_IDENTIFICATION = "zh_TW.UTF-8";
    LC_MEASUREMENT = "zh_TW.UTF-8";
    LC_MONETARY = "zh_TW.UTF-8";
    LC_NAME = "zh_TW.UTF-8";
    LC_NUMERIC = "zh_TW.UTF-8";
    LC_PAPER = "zh_TW.UTF-8";
    LC_TELEPHONE = "zh_TW.UTF-8";
    LC_TIME = "zh_TW.UTF-8";
  };

  # Desktop Environment
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Input Method (Fcitx5)
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-chewing
      fcitx5-gtk
      qt6Packages.fcitx5-chinese-addons
    ];
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  # Sound
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # User Account
  users.users."richard" = {
    isNormalUser = true;
    shell = pkgs.zsh;
    description = "Richard Chen";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
  };

  # Container Engine
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  programs.firefox.enable = true;
  programs.zsh.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    gnomeExtensions.kimpanel
    google-chrome
    docker-compose
  ];

  system.stateVersion = "26.05";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
