{ config, pkgs, ... }:

{
  home.username = "richard";
  home.homeDirectory = "/home/richard";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    # 字體
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    sarasa-gothic
    
    # 終端機
    gemini-cli
    tmux
    jq
    
    # Neovim 依賴工具
    git
    lazygit
    ripgrep
    fd
    gcc
    gnumake
    unzip
    wget
    tree-sitter
    
    # 語言開發環境 (LSP & Mason 依賴)
    nodejs
    python3
    luarocks
    go
    rustup
    
    # 必要的編譯函式庫 (解決 tree-sitter 編譯問題)
    stdenv.cc.cc.lib
    pkg-config
    
    # 多媒體與圖形 (Snacks.image 依賴)
    imagemagick
    
    # 輸入法相關 (雖然 i18n.inputMethod 會處理，但列在這裡方便查看)
    fcitx5-configtool
  ];

  # Fcitx5 新酷音設定
  i18n.inputMethod = {
    enabled = "fcitx"; # Home Manager 中通常使用 "fcitx5" 或 "fcitx"，目前多數推薦 fcitx5
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-chewing
      fcitx5-chinese-addons
      fcitx5-gtk
    ];
  };

  # fzf 設定
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # 設定環境變數
  home.sessionVariables = {
    CC = "gcc";
    # 輸入法環境變數
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "ibus";
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = false;
    withRuby = false;
  };

  programs.ghostty = {
    enable = true;
    settings = {
      font-size = 14;
      background = "000000";
      foreground = "ffffff";
      cursor-color = "ffffff";
      clipboard-read = "allow";
      clipboard-write = "allow";
    };
  };

  # 連結 LazyVim starter 模板
  home.file.".config/nvim" = {
    source = pkgs.fetchFromGitHub {
      owner = "LazyVim";
      repo = "starter";
      rev = "main";
      sha256 = "sha256-QrpnlDD4r1X4C8PqBhQ+S3ar5C+qDrU1Jm/lPqyMIFM=";
    };
    recursive = true;
  };

  # 自定義全黑主題設定
  xdg.configFile."nvim/lua/plugins/theme.lua".text = ''
    return {
      {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        opts = {
          style = "night",
          transparent = true, -- 透明背景會顯示 Ghostty 的 000000
          styles = {
            sidebars = "transparent",
            floats = "transparent",
          },
        },
      },
    }
  '';

  # Zsh 與 Oh My Zsh 設定
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" "fzf" ];
      theme = "bira";
    };

    initExtra = '''';
  };

  # Tmux 設定 (交給 oh-my-tmux 管理，所以這裡關閉以免衝突)
  programs.tmux = {
    enable = false;
  };

  # Oh My Tmux (gpakosz/.tmux)
  # 下載並連結設定檔
  home.file.".tmux.conf".source = pkgs.fetchFromGitHub {
    owner = "gpakosz";
    repo = ".tmux";
    rev = "master";
    sha256 = "sha256-nXm664l84YSwZeRM4Hsweqgz+OlpyfwXcgEdyNGhaGA=";
  } + "/.tmux.conf";

  # 建立 local 設定檔，啟用 Nerd Font 視覺特效
  home.file.".tmux.conf.local".text = ''
    # -- 基礎設定 (從 programs.tmux 移過來) ---------------------------------------
    set -g mouse on
    setw -g clock-mode-style 24

    # -- 視覺外觀 (Nerd Font & Powerline) ---------------------------------------
    tmux_conf_theme_24b_colour=true

    # 使用 Powerline 符號 (需要 Nerd Font)
    tmux_conf_theme_left_separator_main='\uE0B0'
    tmux_conf_theme_left_separator_sub='\uE0B1'
    tmux_conf_theme_right_separator_main='\uE0B2'
    tmux_conf_theme_right_separator_sub='\uE0B3'

    # 狀態欄內容配置
    tmux_conf_theme_status_left=" ❐ #S | ↑#{?uptime_y, #{uptime_y}y,}#{?uptime_d, #{uptime_d}d,}#{?uptime_h, #{uptime_h}h,}#{?uptime_m, #{uptime_m}m,} "
    tmux_conf_theme_status_right=" #{prefix}#{pairing}#{synchronized} , %R , %d %b | #{username}#{root} | #{hostname} "

    # 電池設定 (Nerd Font 圖標)
    tmux_conf_battery_bar_symbol_full="█"
    tmux_conf_battery_bar_symbol_empty="░"
    tmux_conf_battery_bar_length="auto"
    tmux_conf_battery_bar_palette="gradient"
    tmux_conf_battery_status_charging="󱐋"
    tmux_conf_battery_status_discharging="󰂃"

    # 加入電池和負載到右側狀態欄
    tmux_conf_theme_status_right=" #{prefix}#{pairing}#{synchronized} | #{cpu_load} CPU | #{battery_status} #{battery_bar} #{battery_percentage} | %R , %d %b "

    # 樣式優化
    tmux_conf_theme_focused_pane_bg='default'
    tmux_conf_theme_pane_border_style='thin'

    # -- vi 複製模式 -----------------------------------------------------------
    setw -g mode-keys vi
    bind -T copy-mode-vi v send -X begin-selection
    bind -T copy-mode-vi y send -X copy-selection-and-cancel
    bind -T copy-mode-vi Escape send -X cancel
    bind -T copy-mode-vi L send -X end-of-line
    bind -T copy-mode-vi H send -X start-of-line

    # -- 剪貼簿 (OSC 52 支援，適合 SSH) ----------------------------------------
    set -s set-clipboard on
  '';

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      sansSerif = [ "Noto Sans CJK TC" ];
      serif = [ "Noto Serif CJK TC" ];
      monospace = [ "JetBrainsMono Nerd Font" "Sarasa Mono TC" ];
    };
  };

  xdg.configFile."fontconfig/conf.d/99-beautify.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <match target="font">
        <edit name="antialias" mode="assign"><bool>true</bool></edit>
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
        <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
        <edit name="rgba" mode="assign"><const>rgb</const></edit>
        <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
      </match>
    </fontconfig>
  '';

  programs.home-manager.enable = true;

  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        "kimpanel@kde.org"
      ];
    };
    "org/gnome/mutter" = {
      experimental-features = [ "scale-monitor-framebuffer" ];
    };
  };
}
