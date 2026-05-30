{ config, pkgs, lib, ... }:

{
  imports = [
    ./locale.nix
    ./desktop.nix
    ./podman.nix
    ./steam.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.networkmanager.enable = true;

  networking.firewall.allowedTCPPorts = [ 58888 ];

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AllowUsers = [ "richard" ];
    };
  };

  # User Account
  users.users."richard" = {
    isNormalUser = true;
    shell = pkgs.zsh;
    description = "Richard Chen";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    autoSubUidGidRange = true;
  };

  # Basic programs
  programs.firefox.enable = true;
  programs.zsh.enable = true;
  programs.nix-ld.enable = true;

  # Allow unfree
  nixpkgs.config.allowUnfree = true;

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    home-manager
    gnomeExtensions.kimpanel
    docker-compose
  ];

  system.stateVersion = "26.05";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
