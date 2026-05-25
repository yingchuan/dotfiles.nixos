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
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      # 系統層級配置
      nixosConfigurations.thinkpad-t14s-gen6 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/thinkpad-t14s-gen6/configuration.nix
        ];
      };

      nixosConfigurations.x300m-stx = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/x300m-stx/configuration.nix
        ];
      };

      # 用戶層級配置 (共用 hosts/shared/home.nix，每台 host 可疊加差異)
      homeConfigurations."richard@thinkpad-t14s-gen6" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./hosts/shared/home.nix
        ];
      };

      homeConfigurations."richard@x300m-stx" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./hosts/shared/home.nix
          {
            programs.ghostty.settings.font-size = 18;
          }
        ];
      };
    };
}
