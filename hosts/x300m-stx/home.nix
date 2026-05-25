{ config, pkgs, lib, ... }:

let
  sqlite_lib = "${pkgs.sqlite.out}/lib/libsqlite3.so";
in
{
  home.username = "richard";
  home.homeDirectory = "/home/richard";
  home.stateVersion = "26.05";

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
    "$HOME/.bun/bin"
  ];

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    aider-chat
    bun
    # Fonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    sarasa-gothic
    
    # Terminal & Shell Tools
    google-chrome
    tmux
    jq
    fzf
    procps
    coreutils
    gnused
    gnugrep
    gawk
    nettools
    bc
    htop
    file
    
    # Neovim & Development Dependencies
    git
    lazygit
    ripgrep
    fd
    gcc
    gnumake
    unzip
    wget
    tree-sitter
    sqlite
    ghostscript
    mermaid-cli
    tectonic
    imagemagick
    pkg-config
    stdenv.cc.cc.lib

    # Language Servers & Runtimes (Note: Bun is the primary runtime and OpenCode uses Bun; Node.js is kept for LSPs and Neovim)
    nodejs
    prettier
    marksman
    markdownlint-cli2
    go
    wails
    gopls
    gofumpt
    golangci-lint
    python3
    python312Packages.pynvim
    python312Packages.pip
    pyright
    uv
    rustup
    lua-language-server
    stylua
    lua5_1
    luarocks
    cmake
    clang-tools
    gdb
    pinentry-curses
    bitwarden-cli
    jq
  ];

  services.ssh-agent.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Richard Chen";
        email = "yingchuan.chen.2007@gmail.com";
      };
      init.defaultBranch = "main";
      core.sshCommand = "ssh -o AddKeysToAgent=yes";
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  home.sessionVariables = {
    CC = "gcc";
    LIBSQLITE_PATH = sqlite_lib;
    LIBSQLITE3_PATH = sqlite_lib;
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "fcitx";
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = true;
    withNodeJs = true;
    extraPython3Packages = ps: with ps; [ pynvim ];
    initLua = ''
      vim.g.sqlite_clib_path = "${sqlite_lib}"
    '';
    withRuby = false;
  };

  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "JetBrainsMono Nerd Font";
      font-style = "Medium";
      font-size = 18;
      background = "000000";
      foreground = "ffffff";
      cursor-color = "ffffff";
      clipboard-read = "allow";
      clipboard-write = "allow";
    };
  };

  home.file.".config/nvim" = {
    source = pkgs.fetchFromGitHub {
      owner = "LazyVim";
      repo = "starter";
      rev = "main";
      sha256 = "sha256-QrpnlDD4r1X4C8PqBhQ+S3ar5C+qDrU1Jm/lPqyMIFM=";
    };
    recursive = true;
  };

  # Neovim Custom Configs
  xdg.configFile."nvim/lua/config/nixos.lua".text = ''
    vim.g.sqlite_clib_path = "${sqlite_lib}"
  '';

  xdg.configFile."nvim/lua/plugins/nixos.lua".text = ''
    return {
      {
        "kkharji/sqlite.lua",
        lazy = false,
        config = function()
          vim.g.sqlite_clib_path = "${sqlite_lib}"
        end,
      },
    }
  '';

  xdg.configFile."nvim/lua/plugins/theme.lua".text = ''
    return {
      {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        opts = {
          style = "night",
          transparent = true,
          styles = {
            sidebars = "transparent",
            floats = "transparent",
          },
        },
      },
    }
  '';

  xdg.configFile."nvim/lua/plugins/lang.lua".text = ''
    return {
      { "LazyVim/LazyVim", opts = {
        extras = {
          "lang.go",
          "lang.zig",
          "lang.rust",
          "lang.clangd",
          "lang.python",
          "lang.json",
          "lang.toml",
          "lang.yaml",
          "lang.docker",
          "lang.markdown",
        },
      } },
      {
        "stevearc/conform.nvim",
        opts = {
          formatters_by_ft = {
            go = { "gofumpt", "goimports" },
          },
        },
      },
      {
        "mfussenegger/nvim-lint",
        opts = {
          linters_by_ft = {
            go = { "golangcilint" },
          },
        },
      },
    }
  '';

  xdg.configFile."nvim/lua/plugins/markdown.lua".text = ''
    return {
      {
        "MeanderingProgrammer/render-markdown.nvim",
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    }
  '';

  # OpenCode & oh-my-openagent Configs
  xdg.configFile."opencode/opencode.jsonc".text = ''
    {
      "$schema": "https://opencode.ai/config.json",
      "plugin": ["oh-my-openagent@latest"],
      "provider": {
        "dashscope": {
          "npm": "@ai-sdk/openai-compatible",
          "name": "Alibaba Cloud DashScope",
          "options": {
            "baseURL": "https://dashscope.aliyuncs.com/compatible-mode/v1",
            "apiKey": "''${env.DASHSCOPE_API_KEY}"
          },
          "models": {
            "qwen3.7-max": {
              "name": "Qwen 3.7 Max"
            },
            "qwen3.6-flash": {
              "name": "Qwen 3.6 Flash"
            },
            "deepseek-v4": {
              "name": "DeepSeek V4"
            },
            "deepseek-v4-reasoner": {
              "name": "DeepSeek V4 Reasoner"
            }
          }
        }
      }
    }
  '';

  xdg.configFile."opencode/oh-my-openagent.json".text = ''
    {
      "$schema": "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json",
      "agents": {
        "hephaestus": { "model": "dashscope/qwen3.7-max" },
        "oracle": { "model": "dashscope/deepseek-v4-reasoner" },
        "librarian": { "model": "dashscope/qwen3.6-flash" },
        "explore": { "model": "dashscope/qwen3.6-flash" },
        "multimodal-looker": { "model": "dashscope/deepseek-v4" },
        "prometheus": { "model": "dashscope/deepseek-v4" },
        "metis": { "model": "dashscope/qwen3.7-max" },
        "momus": { "model": "dashscope/qwen3.6-flash" },
        "atlas": { "model": "dashscope/qwen3.6-flash" },
        "sisyphus-junior": { "model": "dashscope/deepseek-v4" }
      },
      "categories": {
        "visual-engineering": { "model": "dashscope/deepseek-v4" },
        "ultrabrain": { "model": "dashscope/deepseek-v4-reasoner" },
        "deep": { "model": "dashscope/deepseek-v4-reasoner" },
        "artistry": { "model": "dashscope/qwen3.7-max" },
        "quick": { "model": "dashscope/qwen3.6-flash" },
        "unspecified-low": { "model": "dashscope/qwen3.6-flash" },
        "unspecified-high": { "model": "dashscope/deepseek-v4" },
        "writing": { "model": "dashscope/deepseek-v4" }
      }
    }
  '';

  xdg.configFile."opencode/tui.json".text = ''
    {
      "plugin": ["oh-my-openagent/tui"]
    }
  '';

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
      unset __HM_SESS_VARS_SOURCED
      . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      export SSH_AUTH_SOCK="/run/user/1000/ssh-agent"
      if [ -z "$(ssh-add -l | grep 'yingchuan')" ]; then
        ssh-add ~/.ssh/yingchuan 2>/dev/null
      fi
    '';
  };

  programs.tmux.enable = false;

  home.file.".tmux.conf".source = pkgs.fetchFromGitHub {
    owner = "gpakosz";
    repo = ".tmux";
    rev = "master";
    sha256 = "sha256-nXm664l84YSwZeRM4Hsweqgz+OlpyfwXcgEdyNGhaGA=";
  } + "/.tmux.conf";

  home.file.".gemini/GEMINI.md".text = ''
    # Global Personal Memory

    - **Primary User:** richard
    - **Rules:**
      1. No guessing, must verify (禁止猜測 必須求證).
         - Acknowledge unknowns: Inform the user when information is insufficient instead of making up answers.
         - Tool-first: Always run tools to get real data before giving conclusions.
         - Cite evidence: Answers must be based on actual file content or command output.
      2. Language: All GEMINI.md files must be written in English.
      3. Environment: Neovim/LazyVim configurations are managed by Nix. Do not modify `~/.config/nvim` directly.
    - **Note:** This file is managed by Nix (Location: `~/dotfiles.nixos/hosts/x300m-stx/home.nix`). Do not edit it directly.
  '';

  home.file.".gemini/settings.json".text = ''
    {
      "security": {
        "auth": {
          "selectedType": "oauth-personal"
        }
      },
      "general": {
        "preferredEditor": "neovim"
      },
      "mcpServers": {
        "deepwiki": {
          "url": "https://mcp.deepwiki.com/mcp",
          "type": "http"
        }
      }
    }
  '';

  home.file.".gemini/antigravity-cli/mcp_config.json".text = ''
    {
      "mcpServers": {
        "deepwiki": {
          "serverUrl": "https://mcp.deepwiki.com/mcp"
        }
      }
    }
  '';

  home.file.".tmux.conf.local".text = builtins.concatStringsSep "\n" [
    "# : << 'EOF'"
    "set -g mouse on"
    "setw -g clock-mode-style 24"
    ""
    "# Tokyo Night Theme"
    "tmux_conf_theme_24b_colour=true"
    "tmux_conf_theme_colour_1=\"#1a1b26\""
    "tmux_conf_theme_colour_2=\"#24283b\""
    "tmux_conf_theme_colour_3=\"#c0caf5\""
    "tmux_conf_theme_colour_4=\"#7aa2f7\""
    "tmux_conf_theme_colour_5=\"#bb9af7\""
    "tmux_conf_theme_colour_6=\"#7dcfff\""
    "tmux_conf_theme_colour_7=\"#9ece6a\""
    "tmux_conf_theme_colour_8=\"#f7768e\""
    "tmux_conf_theme_colour_9=\"#e0af68\""
    ""
    "tmux_conf_theme_left_separator_main=''"
    "tmux_conf_theme_left_separator_sub=''"
    "tmux_conf_theme_right_separator_main=''"
    "tmux_conf_theme_right_separator_sub=''"
    ""
    "tmux_conf_theme_status_left=\" ❐ #S | 󰒋 #{hostname} \""
    "tmux_conf_theme_status_right=\" #{prefix}#{pairing}#{synchronized} |  #{loadavg} |  #{mem_usage} | 󰂂 #{battery_percentage} | #{english_date} %H:%M \""
    ""
    "tmux_conf_theme_status_left_fg=\"$tmux_conf_theme_colour_1\""
    "tmux_conf_theme_status_left_bg=\"$tmux_conf_theme_colour_4\""
    ""
    "tmux_conf_theme_status_right_fg=\"$tmux_conf_theme_colour_3,$tmux_conf_theme_colour_4,$tmux_conf_theme_colour_5,$tmux_conf_theme_colour_7,$tmux_conf_theme_colour_1\""
    "tmux_conf_theme_status_right_bg=\"$tmux_conf_theme_colour_2,$tmux_conf_theme_colour_1,$tmux_conf_theme_colour_1,$tmux_conf_theme_colour_1,$tmux_conf_theme_colour_4\""
    ""
    "tmux_conf_theme_focused_pane_bg='default'"
    "tmux_conf_theme_pane_border_style='thin'"
    "tmux_conf_update_interval=5"
    "tmux_conf_battery_bar_palette=\"gradient\""
    ""
    "tmux_conf_battery_status_charging=\"󱐋\""
    "tmux_conf_battery_status_discharging=\"󰂂\""
    ""
    "setw -g mode-keys vi"
    "bind -T copy-mode-vi v send -X begin-selection"
    "bind -T copy-mode-vi y send -X copy-selection-and-cancel"
    ""
    "# # /!\\ do not remove the following line"
    "# EOF"
    "#"
    "# english_date() {"
    "#   LC_TIME=C date +'%a %b %d'"
    "# }"
    "#"
    "# mem_usage() {"
    "#   awk '/MemTotal/ { total=$2 } /MemAvailable/ { avail=$2 } END { printf(\"%.0f%%\", (total-avail)/total*100) }' /proc/meminfo"
    "# }"
    "#"
    "# \"$@\""
  ];

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

  home.file.".config/containers/policy.json".text = ''
    {
        "default": [
            {
                "type": "insecureAcceptAnything"
            }
        ],
        "transports":
            {
                "docker-daemon":
                    {
                        "": [{"type":"insecureAcceptAnything"}]
                    }
            }
    }
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

  # Automatically install global Bun packages (e.g. OpenCode CLI) on home-manager activation
  home.activation = {
    installGlobalBunPackages = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if command -v bun >/dev/null; then
        echo "Installing/Updating global Bun packages..."
        $DRY_RUN_CMD bun install -g opencode-ai
      fi
    '';
  };
}
