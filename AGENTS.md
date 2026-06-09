# Richard's NixOS Dotfiles

## Project

Personal NixOS dotfiles repo. Manages 2 hosts via Nix Flakes + Home Manager.

## Hosts

- **thinkpad-t14s-gen6** — Lenovo ThinkPad T14s Gen 6 (主力機, AMD, ollama/open-webui)
- **x300m-stx** — ASUS x300m-stx (次要機, gen-ui-hub host, ollama CPU/bge-m3)

## Apply Changes

- **System:** `sudo nixos-rebuild switch --flake .#<hostname>`
- **User:** `home-manager switch --flake .#richard@<hostname>`

## Repo Structure

```
flake.nix hosts/
  shared/
    home.nix              ← 共用 home-manager 設定
    system-module.nix     ← 共用系統模組 (imports locale/desktop/podman/steam)
    locale.nix            ← 時區/語系/fcitx5/鍵盤
    desktop.nix           ← GNOME/GDM/PipeWire/列印
    podman.nix            ← Podman/Docker
    steam.nix             ← Steam/32-bit 圖形
  <hostname>/
    configuration.nix     ← 極簡, import shared + host-specific
    hardware-configuration.nix
```

## Conventions

- Nix files: one line per brace, two-space indent.
- All `${self}` / `inputs` references only in `flake.nix`; modules get values via `specialArgs`.
- Home-manager configs are shared: per-host overrides happen inline in `flake.nix`.
- **Keep code clean** — no leftover whitespace, unused imports, or commented-out dead code.
- **Always format after changes** — run formatter on every modified file before committing.

## Critical Rules

- **Do NOT edit `~/.config/opencode/` directly.** It's deployed from `hosts/shared/home.nix`.
- **Do NOT edit `~/.config/nvim/` directly.** It's deployed from Nix.
- **Do NOT modify `hardware-configuration.nix`.** It's auto-generated.
- `.tmux.conf.local` has parsing quirks: tmux vars = no leading `# `; custom shell functions = must start with `# ` + end with `"$@"`.
- **If the user's request mentions "股票" (stocks) or "findmind" / "FinMind", read [findmind.md](file:///home/richard/dotfiles.nixos/findmind.md) to understand how to query financial data.**

## Dev Environment

- **Bun** is primary JS runtime (also runs OpenCode). Node.js is only kept for LSPs/Neovim.
- `home.activation` installs `opencode-ai` globally via bun.
- Git: richard@ (ssh key: `~/.ssh/yingchuan`).
- GitHub: `yingchuan.chen.2007@gmail.com`.

## Per-Host Quirks

- **thinkpad-t14s-gen6**: ghostty font-size 14, has ollama/open-webui.
- **x300m-stx**: ghostty font-size 18, ollama (CPU, bge-m3) for gen-ui-hub embedding.
