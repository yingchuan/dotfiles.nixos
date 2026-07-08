{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../shared/system-module.nix
    ./wireguard.nix
    ./yt-translate.nix
  ];

  networking.hostName = "thinkpad-t14s-gen6";

  # COSMIC (thinkpad only) — try it alongside GNOME. cosmic-greeter
  # replaces the shared GDM here; it lists all sessions so GNOME stays
  # selectable. x300m-stx keeps GNOME + GDM untouched.
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;
  services.displayManager.gdm.enable = lib.mkForce false;

  # AMD GPU acceleration for Ollama (bound to localhost for security)
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    host = "127.0.0.1";
    port = 11434;
    # ollama 0.30+ drops integrated GPUs by default; the Radeon 880M (gfx1150)
    # is fully ROCm-capable here, so opt it back in explicitly.
    environmentVariables.OLLAMA_IGPU_ENABLE = "1";
  };

  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 8080;
  };

  # AMD Ryzen AI NPU (XDNA2) 堆疊，走 noamsto/nix-amd-ai module（import 見 flake.nix）。
  # kernel 層已備妥：7.0.12 內建 in-tree amdxdna 驅動、/dev/accel/accel0 已認到；module 只
  # modprobe 這顆 in-tree 驅動（boot.kernelModules），不塞 out-of-tree 模組、不與之衝突。
  # 疊上的是純 userspace：XRT + xrt-plugin-amdxdna（源碼建）+ FastFlowLM NPU runtime。
  #
  # 第一刀刻意只上 NPU + FastFlowLM（目標本身），隔離失敗面、驗證用 `flm` 直接跑；
  # enableLemonade（OpenAI 相容 server + web UI）等 FLM 確認通了再開。
  hardware.amd-npu = {
    enable = true;
    enableLemonade = true;
    # headless：跳過 Tauri 桌面殼（唯一拉 Rust/npm build + cargo-vendor 的部分），
    # 只出 lemond server + CLI。web UI 仍在（server 內建），port 預設 13305。
    lemonade.desktopApp.enable = false;
    # 只做 LLM 推論，關掉 stable-diffusion.cpp（省 ~150MB CPU-only 閉包）。
    enableImageGen = false;
    # enableLemonade=true 時此 option 無 default、必設，否則 eval 直接報錯。
    lemonade.user = "richard";
  };

  # NPU 裝置存取：module 的 udev 把 /dev/accel/accel0 設 GROUP=video MODE=0660、memlock
  # unlimited 給 @video/@render。richard 原本只在 users/wheel/networkmanager，補這兩群否則
  # 非 root 開不了 NPU。extraGroups 是 list、與 shared/system-module.nix 的定義自動合併。
  users.users.richard.extraGroups = [ "video" "render" ];

  # nix-amd-ai 的 Cachix：XRT/xrt-plugin/FastFlowLM 皆源碼建，命中快取免本機長編。
  # 必須放 nix.settings（daemon 層），非 flake nixConfig（那只對 trusted user 生效）。
  nix.settings = {
    substituters = [ "https://nix-amd-ai.cachix.org" ];
    trusted-public-keys = [ "nix-amd-ai.cachix.org-1:F4OU4vw/lV2oiG6SBHZ+nqjl4EFJuqI4X9A7pvaBmhQ=" ];
  };
}
