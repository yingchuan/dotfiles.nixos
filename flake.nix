{
  description = "Richard's Dotfiles Flake";

  inputs = {
    # 使用 unstable 分支以獲取最新軟體
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      # 定義不同主機的 home-manager 配置
      # 使用方式: home-manager switch --flake .#richard@thinkpad-t14s-gen6
      homeConfigurations."richard@thinkpad-t14s-gen6" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./hosts/thinkpad-t14s-gen6/home.nix ];
      };
    };
}
