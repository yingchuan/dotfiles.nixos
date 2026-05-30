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
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC0gDvM/oioX/WQhBubJHmPXTssqGKanuFmbHtxKkz0aBpuUqSOg2NawIpVZyfrrcJeE/2BSTx6MCF02gEE8DMZucxPr9qk400qWPT0lMydF2Wdz16mHmOlHMB/EKNgAx6FX1RIxtuvFRfYM/zPbIJHoYWZeMEp9BLa+jrPTj7bjWUvHq5zIOiTxArFdrD5epBDPfcLR6DynG6ysxyMWZK645mJPC89HGNhyVDyLDwO43GxRDnBmNxcH79Hc4HoWClVgpgQMfemPUE3gKiFSokHBDULD4gbXRjqCbe10muI2SfE8kyBGXFffyJT3G/kK4ewVCzUQ3EmUUe+uRf7G3K/tSQc/adWZrUVnrpDBg4Op2/l2dnsSbdpDQri4LnL1gagVBg9fZJN0bV4him7M4cMU1WY9iUypYSXKqR5AmDObIfYZFoH0SlqL2xoyKoNEtFPaGlDpkIHEqxaT2k9paTUbiqZjKDh9iN/s1TjbTTqTXiGzB74vDF4xcpQCLcR078= richardchen@ES-C0184-MacBook-Pro-14.home"
    ];
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
