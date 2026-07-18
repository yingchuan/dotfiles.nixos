{
  description = "Richard's Dotfiles Flake (NixOS + Home Manager)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    # 只給少數快動工具吃 unstable（codex CLI 版本比 26.05 stable 新很多、官方 source-build）。
    # 系統其餘一律走上面的 26.05 stable，靠 overlay 只覆蓋單一 package。
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
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
      unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        # 單一 package pin unstable（overlay 會傳進 home-manager 的 pkgs；config 不會，故用 overlay）：
        #   codex   → 26.05 stable 只有 0.133，走 unstable 拿 0.144.x。
        #   prettier→ 26.05 的 prettier wasm binding 建置期拉 pnpm-9.15.9（stable 標 insecure、
        #             會擋掉整個 home eval，是既有問題非 codex 引入）；unstable 同 3.8.3 但未標
        #             insecure，改拉 unstable 版繞過（比 permittedInsecurePackages 可靠，後者到不了 HM pkgs）。
        overlays = [
          (final: prev: {
            codex = unstable.codex;
            prettier = unstable.prettier;
          })
        ];
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
