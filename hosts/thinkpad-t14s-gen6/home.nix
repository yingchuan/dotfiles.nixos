{ config, pkgs, lib, ... }:

{
  home.username = "richard";
  home.homeDirectory = "/home/richard";
  home.stateVersion = "25.11";

  nixpkgs.config.allowUnfree = true;

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
    
    # 系統工具 (Tmux 狀態列依賴)
    procps
    coreutils
    gnused
    gnugrep
    gawk
    nettools # 提供 ifconfig/hostname
    bc       # oh-my-tmux 計算 CPU/Mem 必備
    distrobox # 容器化執行其他 Linux 發行版
    htop
  ];

  # 啟用 SSH Agent 服務
  services.ssh-agent.enable = true;

  # Git 設定 (依照最新版本的 Home Manager 語法修正)
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Richard Chen";
        email = "yingchuan.chen.2007@gmail.com";
      };
      init = {
        defaultBranch = "main";
      };
      core = {
        sshCommand = "ssh -o AddKeysToAgent=yes";
      };
    };
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
    # 在 Wayland 下，建議不要設定 GTK_IM_MODULE 和 QT_IM_MODULE
    # 讓程式自動使用 Wayland text-input 協定
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "fcitx";
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
      font-family = "JetBrainsMono Nerd Font";
      font-style = "Medium";
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

    initContent = ''
      # 指向 Systemd 管理的 ssh-agent socket
      export SSH_AUTH_SOCK="/run/user/1000/ssh-agent"

      # 自動載入金鑰 (如果尚未載入)
      if [ -z "$(ssh-add -l | grep 'yingchuan')" ]; then
        ssh-add ~/.ssh/yingchuan 2>/dev/null
      fi
    '';
  };

  # Tmux 設定 (交給 oh-my-tmux 管理，所以這裡關閉以免衝突)
  programs.tmux = {
    enable = false;
  };

  # Oh My Tmux (gpakosz/.tmux)
  home.file.".tmux.conf".source = pkgs.fetchFromGitHub {
    owner = "gpakosz";
    repo = ".tmux";
    rev = "master";
    sha256 = "sha256-nXm664l84YSwZeRM4Hsweqgz+OlpyfwXcgEdyNGhaGA=";
  } + "/.tmux.conf";

  home.file.".tmux.conf.local".text = ''
# : << 'EOF'
# -- 基礎設定
set -g mouse on
setw -g clock-mode-style 24

# -- Tokyo Night 配色定義
tmux_conf_theme_24b_colour=true

# 顏色定義 (Tokyo Night 風格)
tmux_conf_theme_colour_1="#1a1b26"    # 極深藍 (背景)
tmux_conf_theme_colour_2="#24283b"    # 深藍 (次要背景)
tmux_conf_theme_colour_3="#c0caf5"    # 淡藍灰 (主文字)
tmux_conf_theme_colour_4="#7aa2f7"    # 亮藍 (重點)
tmux_conf_theme_colour_5="#bb9af7"    # 淺紫 (重點)
tmux_conf_theme_colour_6="#7dcfff"    # 青色 (重點)
tmux_conf_theme_colour_7="#9ece6a"    # 柔和綠 (電池)
tmux_conf_theme_colour_8="#f7768e"    # 柔和紅 (警告)
tmux_conf_theme_colour_9="#e0af68"    # 橙色

# 分隔符號
tmux_conf_theme_left_separator_main=''
tmux_conf_theme_left_separator_sub=''
tmux_conf_theme_right_separator_main=''
tmux_conf_theme_right_separator_sub=''

# 狀態欄內容設計
tmux_conf_theme_status_left=" ❐ #S | 󰒋 #{hostname} "
tmux_conf_theme_status_right=" #{prefix}#{pairing}#{synchronized} |  #{cpu_percentage} |  #{mem_percentage} | #{battery_status} #{battery_percentage} | #{my_date} "

# 狀態欄顏色配置
# 左側 (Session): 深藍文字 (#1a1b26) 配 亮藍背景 (#7aa2f7)
tmux_conf_theme_status_left_fg="$tmux_conf_theme_colour_1"
tmux_conf_theme_status_left_bg="$tmux_conf_theme_colour_4"

# 右側 (5 個區段): 1.模式 | 2.CPU | 3.記憶體 | 4.電池 | 5.時間
tmux_conf_theme_status_right_fg="$tmux_conf_theme_colour_3,$tmux_conf_theme_colour_4,$tmux_conf_theme_colour_5,$tmux_conf_theme_colour_7,$tmux_conf_theme_colour_1"
tmux_conf_theme_status_right_bg="$tmux_conf_theme_colour_2,$tmux_conf_theme_colour_1,$tmux_conf_theme_colour_1,$tmux_conf_theme_colour_1,$tmux_conf_theme_colour_4"

# 樣式與行為
tmux_conf_theme_focused_pane_bg='default'
tmux_conf_theme_pane_border_style='thin'
tmux_conf_update_interval=5
tmux_conf_battery_bar_palette="gradient"

# 電池圖示
tmux_conf_battery_status_charging="󱐋"
tmux_conf_battery_status_discharging="󰂂"

# vi 模式
setw -g mode-keys vi
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-selection-and-cancel
# EOF

# cpu_percentage() {
#   uptime | awk -F'load average:' '{ print $2 }' | cut -d',' -f1 | sed 's/ //g'
# }

# mem_percentage() {
#   free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2 }'
# }

# my_date() {
#   LC_TIME=C date +'%y-%m-%d %a %H:%M'
# }

# "$@"
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
      enabled-extensions = [ "kimpanel@kde.org" ];
    };
    "org/gnome/mutter" = {
      experimental-features = [ "scale-monitor-framebuffer" ];
    };
  };
}
