{ config, pkgs, ... }:

{
  # Time
  time.timeZone = "Asia/Taipei";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_TW.UTF-8";
    LC_IDENTIFICATION = "zh_TW.UTF-8";
    LC_MEASUREMENT = "zh_TW.UTF-8";
    LC_MONETARY = "zh_TW.UTF-8";
    LC_NAME = "zh_TW.UTF-8";
    LC_NUMERIC = "zh_TW.UTF-8";
    LC_PAPER = "zh_TW.UTF-8";
    LC_TELEPHONE = "zh_TW.UTF-8";
    LC_TIME = "zh_TW.UTF-8";
  };

  # Input Method（框架 + 引擎）＝系統層單一真相。
  # 必須在系統層，才壓得過 GNOME 用 mkDefault 硬塞的 ibus（gnome.nix）——
  # home-manager 是另一套 module system，動不到 NixOS 的 i18n.inputMethod。
  # IM env（XMODIFIERS / SDL_IM_MODULE / GLFW_IM_MODULE=ibus）由本模組自動注入。
  # rime 的注音 schema／詞庫屬使用者資料，在 home（見 hosts/shared/input-method.nix），
  # 故調 schema／詞庫免 sudo；增刪引擎（罕見）才動這裡、需 sudo rebuild。
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    # GNOME Wayland 走原生 text-input-v3：waylandFrontend=true 時刻意不設
    # GTK_IM_MODULE / QT_IM_MODULE，讓 Wayland 接手（XWayland 才靠自動帶的 env）。
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-rime               # 注音走 rime bopomofo（智慧選詞、動態學習，遠勝 chewing）
      fcitx5-chewing            # 退路；驗完 rime 手感後可砍此行
      fcitx5-gtk
      qt6Packages.fcitx5-chinese-addons
    ];
  };

  # Keyboard
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
}
