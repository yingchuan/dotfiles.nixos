# Project Context: Richard's NixOS Dotfiles

This document serves as the primary context for Gemini CLI when working in this workspace.

## Machine Information
- **Model:** Lenovo ThinkPad T14s Gen 6
- **OS Version:** NixOS 26.05 (latest/unstable due to new hardware)
- **Primary User:** richard

## Repository Structure
- **Root:** `/home/richard/dotfiles.nixos`
- **System Config:** `hosts/thinkpad-t14s-gen6/configuration.nix` (NixOS level)
- **User Config:** `hosts/thinkpad-t14s-gen6/home.nix` (Home Manager level)
- **Hardware Config:** `hosts/thinkpad-t14s-gen6/hardware-configuration.nix`
- **Flake Entrypoint:** `flake.nix`

## Critical Workflows

### Applying Changes
- **System-level:** `sudo nixos-rebuild switch --flake .#thinkpad-t14s-gen6`
- **User-level:** `home-manager switch --flake .#richard@thinkpad-t14s-gen6`

### ohmytmux Configuration
- The file `~/.tmux.conf.local` is managed via `home.nix`.
- **Parsing Mandate:** `ohmytmux` uses a `cut -c3-` trick. 
  - Tmux variables must **NOT** have leading `# ` or indentation.
  - Custom shell functions (like `mem_usage`) **MUST** start with `# ` at column 0 and end with a `"$@"` dispatch line.

### Gaming & Graphics
- **Steam:** Enabled via `programs.steam.enable`.
- **32-bit Support:** Enabled via `hardware.graphics.enable32Bit`.
- **Unfree Software:** Must have `nixpkgs.config.allowUnfree = true` in `configuration.nix` and `home.nix`.

## Development Runtimes & Tools

### JavaScript/TypeScript Runtime
- **Bun** is installed and used as the primary runtime, replacing Node.js for general development tasks.
- **OpenCode** is specifically configured to run using **Bun** (e.g., via `bunx` or `bun run`) instead of Node.js.

## Versioning
- **system.stateVersion:** 26.05
- **home.stateVersion:** 26.05

