# Richard's NixOS Dotfiles

Welcome to my personal NixOS configuration repository! This repository uses **Nix Flakes** to manage both the system-level configuration (via `nixosConfigurations`) and the user-level environment (via `home-manager`).

This setup is tailored for my development workflow on the **Lenovo ThinkPad T14s Gen 6**, providing a robust, reproducible, and declarative system.

## 🚀 System Architecture

- **OS:** NixOS (Unstable channel)
- **Hosts:** `thinkpad-t14s-gen6` (primary, AMD, Ollama + Open WebUI) and `x300m-stx` (secondary)
- **Architecture:** `x86_64-linux`
- **Desktop Environment:** GNOME (Wayland)
- **Container Engine:** Podman (Docker-compatible CLI; system socket disabled for security)
- **Input Method:** Fcitx5 (with Chewing/Zhuyin and GTK/Qt support)

## 📁 Repository Structure

```text
~/dotfiles.nixos/
├── flake.nix                                # The entry point for the Nix Flake.
├── flake.lock                               # Locked dependencies for reproducibility.
├── AGENTS.md                                # Cross-tool AI agent context (Linux Foundation standard).
└── hosts/
    ├── shared/
    │   ├── home.nix                         # Shared Home Manager configuration (all hosts).
    │   ├── system-module.nix                # Combines all shared system sub-modules.
    │   ├── locale.nix                       # Timezone, locale, Fcitx5, keyboard.
    │   ├── desktop.nix                      # GNOME, GDM, PipeWire, printing.
    │   ├── podman.nix                       # Podman & Docker compatibility.
    │   └── steam.nix                        # Steam & 32-bit graphics.
    ├── thinkpad-t14s-gen6/
    │   ├── configuration.nix                # Minimal system config (imports shared + Ollama/Open WebUI).
    │   └── hardware-configuration.nix       # Auto-generated hardware specifics.
    └── x300m-stx/
        ├── configuration.nix                # Minimal system config (imports shared).
        └── hardware-configuration.nix       # Auto-generated hardware specifics.
```

## 🛠️ Key Features & Tools

### Development Environment
- **Editor:** Neovim, powered by a heavily customized [LazyVim](https://www.lazyvim.org/) starter configuration. Includes specialized setups for markdown rendering (`render-markdown.nvim`), SQLite integration, and the Tokyo Night theme.
- **Terminal Multiplexer:** Tmux, utilizing the [gpakosz/.tmux](https://github.com/gpakosz/.tmux) (ohmytmux) framework with a custom Tokyo Night color palette and custom status bar functions.
- **Shell:** Zsh with `oh-my-zsh`, integrated with `fzf` for fuzzy finding and enhanced completions.
- **Languages & LSPs:** Pre-configured environments for Go, Rust, Python, Bun (installed as the primary runtime to replace Node.js; OpenCode is run using Bun), Zig, and C/C++, managed declaratively.
- **Terminal Emulator:** Ghostty with JetBrainsMono Nerd Font.

### AI Integration
The environment includes a custom FHS (Filesystem Hierarchy Standard) environment (`ai-env`) specifically designed to run AI CLIs like `@google/gemini-cli` and `@mem0/cli` seamlessly within NixOS, handling necessary NPM global paths and dynamic library linking.

### Gaming
- Steam is enabled at the system level with dedicated firewall rules opened for Remote Play and Local Network Game Transfers.
- Full 32-bit graphics support is enabled.

### Security
- **SSH:** Hardened — root login disabled, password authentication disabled, only the `richard` user is permitted.
- **AI Services:** Ollama and Open WebUI (ThinkPad host only) are bound to `127.0.0.1` and not exposed on any external interface.
- **Containers:** Podman's Docker-compatible socket is not exposed system-wide, preventing privilege escalation via `/var/run/docker.sock`.

## ⚙️ How to Apply Configurations

Since this is a Flake-based setup, applying changes is straightforward. 

**For System-level changes (requires root):**
Modify `hosts/<hostname>/configuration.nix`, then run:
```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

**For User-level changes (no root required):**
Modify `hosts/shared/home.nix` (or host-specific overrides in `flake.nix`), then run:
```bash
home-manager switch --flake .#richard@<hostname>
```

## 📝 Configuration Quirks & Notes

- **Tmux (`.tmux.conf.local`):** The local configuration is generated via `builtins.concatStringsSep`. Due to how ohmytmux parses the local file, custom shell functions must start with `# ` at column 0, and standard variable definitions must *not* contain leading spaces or hashes.
- **Podman:** Configured as the primary container backend with `dockerCompat` enabled. The system includes a default `policy.json` to allow insecure registry pulls (`insecureAcceptAnything`) to facilitate local development workflows without strict signature enforcement.

---
*Generated and maintained with the assistance of Gemini CLI.*