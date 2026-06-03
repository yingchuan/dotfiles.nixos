{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../shared/system-module.nix
    ./wireguard.nix
  ];

  networking.hostName = "x300m-stx";
}
