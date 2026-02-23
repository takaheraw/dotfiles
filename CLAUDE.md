# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

macOS dotfiles repository using mise (tool management) + sheldon (zsh plugin manager) + XDG Base Directory compliant structure. All configuration files are symlinked from this repo to `$HOME` via `install.sh`.

## Key Commands

```bash
# Install/reinstall everything (Homebrew → mise → sheldon → symlinks → tools)
./install.sh

# Reflect shell changes without restarting terminal
exec zsh

# Add a new mise-managed tool
mise use -g <tool>@latest    # updates .config/mise/config.toml + installs

# Install all mise tools defined in config
mise install --yes
```

## Architecture

### Symlink Strategy

`install.sh` creates file-level symlinks (not directory-level) from this repo to `$HOME`:
- Top-level: `.zshrc`, `.zshenv`, `.vimrc` → `$HOME/`
- Directories: `.config/`, `.zsh/`, `.claude/` → recursive file-by-file symlinks
- Existing non-symlink files are backed up to `*.backup`

### Shell Loading Order

```
.zshenv     → Environment vars, PATH, aliases (ALL sessions)
.zshrc      → brew shellenv → mise activate → sheldon source (interactive only)
  sheldon loads:
    sync/   → .zsh/sync/*.zsh (immediate: history, options, colors)
    defer/  → .zsh/defer/*.zsh (deferred via zsh-defer: completion, git aliases)
.zshrc.local → Secrets, machine-specific (gitignored)
```

### Tool Management Split

- **mise** (`.config/mise/config.toml`): Languages (node, python, ruby, go, deno) and CLI tools (gh, ghq, fzf, eza, ripgrep, delta, bat, fd, jq, lazygit, yazi, uv, terraform)
- **Homebrew**: System-level tools not in mise (git, curl, awscli)
- **sheldon** (`.config/sheldon/plugins.toml`): zsh plugins only (zsh-defer, autosuggestions, syntax-highlighting, pure prompt)

### Git Config

XDG compliant at `.config/git/config` (not `~/.gitconfig`). Uses `includeIf` for work-specific config (`config_work`). Delta configured as pager for diffs.

### Secrets

Never committed. Stored in `~/.zshrc.local` (gitignored via `*.local` pattern).

## When Modifying

- **Adding a CLI tool**: Edit `.config/mise/config.toml`, run `mise install --yes`
- **Adding a zsh plugin**: Edit `.config/sheldon/plugins.toml`
- **Adding a shell alias**: Add to `.zshenv` (global) or `.zsh/defer/*.zsh` (deferred)
- **Adding a new dotfile**: Add to repo, update `install.sh` symlink section if needed
- **Adding a new .config/ app**: Add directory to `config_dirs` array in `install.sh`
