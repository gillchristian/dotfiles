# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repository for macOS (ported from Ubuntu/Linux). Manages configurations for Neovim, Zsh, Tmux, Git, Alacritty, and various language toolchains via symlinks.

## Installation & Deployment

Configs are deployed via symlinks using a `link()` helper from `helpers.sh`. Each tool has its own install function in the install scripts.

```bash
# macOS install (primary)
./mac/install.sh

# Selective module install
MODULE=nvim ./mac/install.sh

# Link only nvim config
./linknvim.sh
```

There is no build system, test suite, or CI. Changes are validated manually.

## Architecture

### Symlink-based deployment

`helpers.sh` defines `link()` which symlinks config files from this repo to their expected locations (e.g., `~/.config/nvim` → `./nvim/`). Install scripts (`mac/install.sh`, `install.sh`) call tool-specific functions that use Homebrew (macOS) or apt (Linux) for packages, then `link()` for configs.

### Neovim (`nvim/`)

Lua-based config. Entry point: `nvim/init.lua` → loads `nvim/lua/gillchristian/init.lua`.

- `lua/gillchristian/packer.lua` — Plugin declarations (packer.nvim)
- `lua/gillchristian/set.lua` — Editor options
- `lua/gillchristian/remap.lua` — Key mappings
- `after/plugin/*.lua` — Per-plugin configuration (telescope, lsp, treesitter, copilot, harpoon, etc.)

LSP setup uses mason + mason-lspconfig + nvim-lspconfig. Completion via nvim-cmp + LuaSnip.

### Zsh (`zsh/`)

- `zshrc` — Main RC file, loaded from `~/.zshrc` symlink
- `exports.zsh` — PATH and environment variables for multiple language toolchains (Rust, Go, Haskell, Node/fnm, Deno, .NET)
- `aliases.zsh` — Command aliases (git, docker, misc tools)
- `functions.zsh` — 60+ custom shell functions
- `zsh_plugins.txt` — Plugin list for antidote (plugin manager)
- `private.zsh` — Gitignored user-specific secrets

Prompt: purs (custom Rust prompt). Lazy loading via `load()` function for heavy tools.

### Tmux (`tmux/tmux.conf`)

Prefix remapped to `Ctrl+S`. Pane navigation via `C-h/j/k/l`. Splits and new windows preserve current path.

### Git (`git/`)

`gitconfig` — Global git config. `gitignore_global` — Global gitignore patterns.
