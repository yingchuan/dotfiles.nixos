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
      # 建立一個允許非自由軟體的 pkgs 實例
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      # 系統層級配置
      nixosConfigurations.thinkpad-t14s-gen6 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/thinkpad-t14s-gen6/configuration.nix
        ];
      };

      nixosConfigurations.X300M-STX = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/X300M-STX/configuration.nix
        ];
      };

      # 用戶層級配置
      homeConfigurations."richard@thinkpad-t14s-gen6" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [ ./hosts/thinkpad-t14s-gen6/home.nix ];
      };

      homeConfigurations."richard@X300M-STX" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [ ./hosts/X300M-STX/home.nix ];
      };
    };
}
