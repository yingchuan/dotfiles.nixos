{
  description = "Richard's Dotfiles Flake (NixOS + Home Manager)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Claude Code 開發加速器：把 codebase 索引成知識圖譜，用結構化查詢取代 grep/read
    # 只裝 thinkpad（見 hosts/thinkpad-t14s-gen6/home.nix）；非 JARVIS 記憶層
    codebase-memory-mcp.url = "github:DeusData/codebase-memory-mcp";

    # AMD Ryzen AI NPU 堆疊（XRT + xrt-plugin-amdxdna + FastFlowLM + Lemonade）。
    # 只裝 thinkpad（Strix Point / gfx1150 帶 XDNA2 NPU）。刻意「不」follows 本 flake 的
    # nixpkgs——它 overlay 對自己 pin 的 nixpkgs 建，follows 會讓所有後端從源碼重編（見上游 README）。
    nix-amd-ai.url = "github:noamsto/nix-amd-ai";
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
          inputs.nix-amd-ai.nixosModules.default
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
          ./hosts/thinkpad-t14s-gen6/home.nix
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
