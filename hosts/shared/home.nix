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
    openssl

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
      font-size = 14;
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


  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      claude = "bunx @anthropic-ai/claude-code";
    };

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

  programs.newsboat = {
    enable = true;
    autoReload = true;
    urls = [
      { url = "https://hnrss.org/best"; tags = [ "tech" "news" ]; title = "Hacker News (Best)"; }
      { url = "https://hnrss.org/frontpage"; tags = [ "tech" "news" ]; title = "Hacker News (Frontpage)"; }
      { url = "https://lobste.rs/rss"; tags = [ "tech" "dev" ]; title = "Lobsters"; }
      { url = "https://simonwillison.net/atom/entries/"; tags = [ "tech" "ai" ]; title = "Simon Willison"; }
      { url = "https://jvns.ca/atom.xml"; tags = [ "tech" "linux" ]; title = "Julia Evans (b0rk)"; }
      { url = "https://nixos.org/blog/announcements-rss.xml"; tags = [ "linux" "nixos" ]; title = "NixOS Blog"; }
      { url = "https://lwn.net/headlines/rss"; tags = [ "linux" "news" ]; title = "LWN.net"; }
      { url = "https://www.phoronix.com/rss.php"; tags = [ "linux" "hardware" ]; title = "Phoronix"; }
      { url = "https://deepmind.google/blog/rss.xml"; tags = [ "ai" "research" ]; title = "Google DeepMind"; }
      { url = "https://openai.com/blog/rss.xml"; tags = [ "ai" "research" ]; title = "OpenAI Blog"; }
      { url = "https://huggingface.co/blog/feed.xml"; tags = [ "ai" "dev" ]; title = "Hugging Face Blog"; }
      { url = "https://blog.cloudflare.com/rss/"; tags = [ "tech" "infra" ]; title = "Cloudflare Blog"; }
      { url = "https://github.blog/feed/"; tags = [ "tech" "dev" ]; title = "GitHub Blog"; }
      { url = "https://www.ithome.com.tw/rss"; tags = [ "taiwan" "news" ]; title = "iThome"; }
      { url = "https://www.inside.com.tw/feed"; tags = [ "taiwan" "news" ]; title = "INSIDE"; }
    ];

    extraConfig = ''
      # 基本介面顏色
      color background          default   default
      color listnormal          default   default
      color listfocus           black     magenta   bold
      color listfocus_unread    black     magenta   bold
      color listnormal_unread   cyan      default   bold
      
      # 頂部/底部資訊列
      color info                cyan      black     reverse
      
      # 文章內容配色
      color article             default   default
      
      # 快捷鍵提示列 (自訂突顯按鍵)
      color hint-key            black     cyan      bold
      color hint-separator      black     cyan
      color hint-description    white     cyan

      # 列表排版優化 (加入分隔線與呼吸空間)
      feedlist-format "%4i %n %11u │ %t"
      articlelist-format "%4i %f %D │ %t"
      # 針對文章內的特定標籤上色 (Highlight)
      highlight article "^(Title):.*$" blue default bold
      highlight article "https?://[^ ]+" cyan default underline
      highlight article "\\[image\\ [0-9]+\\]" green default
    '';
  };

  programs.tmux.enable = false;

  home.file.".tmux.conf".source = pkgs.fetchFromGitHub
    {
      owner = "gpakosz";
      repo = ".tmux";
      rev = "master";
      sha256 = "sha256-nXm664l84YSwZeRM4Hsweqgz+OlpyfwXcgEdyNGhaGA=";
    } + "/.tmux.conf";

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
        },
        "puppeteer": {
          "command": "npx",
          "args": ["-y", "@modelcontextprotocol/server-puppeteer"],
          "type": "stdio"
        },
        "memory": {
          "command": "npx",
          "args": ["-y", "@modelcontextprotocol/server-memory"],
          "type": "stdio"
        },
        "mem0": {
          "command": "node",
          "args": ["/home/richard/mcp-mem0/index.js"],
          "type": "stdio"
        }
      }
    }
  '';

  home.file.".gemini/antigravity-cli/mcp_config.json".text = ''
    {
      "mcpServers": {
        "deepwiki": {
          "serverUrl": "https://mcp.deepwiki.com/mcp"
        },
        "puppeteer": {
          "command": "npx",
          "args": ["-y", "@modelcontextprotocol/server-puppeteer"]
        },
        "memory": {
          "command": "npx",
          "args": ["-y", "@modelcontextprotocol/server-memory"]
        },
        "mem0": {
          "command": "node",
          "args": ["/home/richard/mcp-mem0/index.js"]
        }
      }
    }
  '';

  home.file.".gemini/config/mcp_config.json".text = ''
    {
      "mcpServers": {
        "deepwiki": {
          "serverUrl": "https://mcp.deepwiki.com/mcp"
        },
        "puppeteer": {
          "command": "npx",
          "args": ["-y", "@modelcontextprotocol/server-puppeteer"]
        },
        "memory": {
          "command": "npx",
          "args": ["-y", "@modelcontextprotocol/server-memory"]
        },
        "mem0": {
          "command": "node",
          "args": ["/home/richard/mcp-mem0/index.js"]
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

  # OpenCode Configs
  xdg.configFile."opencode/opencode.jsonc".text = ''
    {
      "$schema": "https://opencode.ai/config.json",
      "provider": {
        "bailian-payg": {
          "npm": "@ai-sdk/anthropic",
          "name": "Alibaba Cloud Model Studio",
          "options": {
            "baseURL": "https://dashscope-intl.aliyuncs.com/apps/anthropic/v1"
          },
          "models": {
            "qwen3.7-max": {
              "name": "Qwen3.7 Max (Newest Flagship)",
              "options": {
                "thinking": {
                  "type": "enabled",
                  "budgetTokens": 16384
                }
              }
            },
            "qwen3-max": {
              "name": "Qwen3 Max (Flagship)",
              "options": {
                "thinking": {
                  "type": "enabled",
                  "budgetTokens": 16384
                }
              }
            },
            "qwen3.6-plus": {
              "name": "Qwen3.6 Plus",
              "options": {
                "thinking": {
                  "type": "enabled",
                  "budgetTokens": 8192
                }
              }
            },
            "qwen3.5-plus": {
              "name": "Qwen3.5 Plus (1M context)",
              "options": {
                "thinking": {
                  "type": "enabled",
                  "budgetTokens": 8192
                }
              }
            },
            "qwen3.5-flash": {
              "name": "Qwen3.5 Flash (Fast & Cheap)"
            },
            "deepseek-v3.2": {
              "name": "DeepSeek V3.2"
            },
            "deepseek-v4-pro": {
              "name": "DeepSeek V4 Pro (1M context, frontier reasoning)",
              "options": {
                "thinking": {
                  "type": "enabled",
                  "budgetTokens": 16384
                }
              }
            }
          }
        }
      },
      "plugin": ["oh-my-openagent"],
      "mcp": {
        "puppeteer": {
          "type": "local",
          "command": ["npx", "-y", "@modelcontextprotocol/server-puppeteer"],
          "enabled": true,
          "environment": {
            "PUPPETEER_LAUNCH_OPTIONS": "{\"executablePath\": \"${pkgs.google-chrome}/bin/google-chrome-stable\", \"args\": [\"--no-sandbox\", \"--disable-setuid-sandbox\", \"--disable-dev-shm-usage\"]}",
            "ALLOW_DANGEROUS": "true"
          }
        }
      }
    }
  '';

  xdg.configFile."opencode/oh-my-openagent.jsonc".text = ''
    {
      "$schema": "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json",
      "agents": {
        "sisyphus": { "model": "bailian-payg/deepseek-v4-pro" },
        "prometheus": { "model": "bailian-payg/qwen3-max" },
        "atlas": { "model": "bailian-payg/qwen3.6-plus" },
        "oracle": { "model": "bailian-payg/deepseek-v3.2" },
        "metis": { "model": "bailian-payg/qwen3.6-plus" },
        "momus": { "model": "bailian-payg/qwen3.5-plus" },
        "librarian": { "model": "bailian-payg/qwen3.5-flash" },
        "explore": { "model": "bailian-payg/qwen3.5-flash" },
        "multimodal-looker": { "model": "bailian-payg/qwen3.5-plus" }
      },
      "categories": {
        "visual-engineering": { "model": "bailian-payg/qwen3.6-plus" },
        "deep": { "model": "bailian-payg/deepseek-v3.2" },
        "ultrabrain": { "model": "bailian-payg/qwen3.7-max" },
        "quick": { "model": "bailian-payg/qwen3.5-flash" },
        "artistry": { "model": "bailian-payg/qwen3.6-plus" },
        "unspecified-low": { "model": "bailian-payg/qwen3.5-flash" },
        "unspecified-high": { "model": "bailian-payg/qwen3-max" },
        "writing": { "model": "bailian-payg/qwen3.6-plus" }
      }
    }
  '';

  # Automatically install global Bun packages (e.g. OpenCode CLI) on home-manager activation
  home.activation = {
    installGlobalBunPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      echo "Installing/Updating global Bun packages..."
      $DRY_RUN_CMD ${pkgs.bun}/bin/bun install -g opencode-ai
    '';
  };

}
