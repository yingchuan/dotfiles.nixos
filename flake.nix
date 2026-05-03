{
  description = "Richard's Dotfiles Flake (NixOS + Home Manager)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      # 系統層級配置: sudo nixos-rebuild switch --flake .#thinkpad-t14s-gen6
      nixosConfigurations.thinkpad-t14s-gen6 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/thinkpad-t14s-gen6/configuration.nix
        ];
      };

      # 用戶層級配置: home-manager switch --flake .#richard@thinkpad-t14s-gen6
      homeConfigurations."richard@thinkpad-t14s-gen6" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [ ./hosts/thinkpad-t14s-gen6/home.nix ];
      };
    };
}
