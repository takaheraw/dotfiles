#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

info() { printf '\033[34m[INFO]\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$1"; }
ok()   { printf '\033[32m[ OK ]\033[0m %s\n' "$1"; }

# --- Homebrew ---
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  ok "Homebrew installed"
else
  ok "Homebrew already installed"
fi

# --- mise ---
if ! command -v mise &>/dev/null; then
  info "Installing mise..."
  curl -fsSL https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
  ok "mise installed"
else
  ok "mise already installed"
fi

# --- sheldon ---
if ! command -v sheldon &>/dev/null; then
  info "Installing sheldon..."
  curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh \
    | bash -s -- --repo rossmacarthur/sheldon --to "$HOME/.local/bin"
  ok "sheldon installed"
else
  ok "sheldon already installed"
fi

# --- Symlink helper ---
link_file() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    warn "Backing up existing $dst -> ${dst}.backup"
    mv "$dst" "${dst}.backup"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  ok "Linked $dst -> $src"
}

# --- Dotfiles (top-level) ---
for f in .zshrc .zshenv .vimrc; do
  [ -f "$DOTFILES_DIR/$f" ] && link_file "$DOTFILES_DIR/$f" "$HOME/$f"
done

# --- .config directories (file-level recursive symlinks) ---
config_dirs=("ghostty" "git" "mise" "sheldon")
for dir in "${config_dirs[@]}"; do
  src_dir="$DOTFILES_DIR/.config/$dir"
  [ -d "$src_dir" ] || continue
  while IFS= read -r -d '' file; do
    rel="${file#"$src_dir/"}"
    link_file "$file" "$HOME/.config/$dir/$rel"
  done < <(find "$src_dir" -type f -print0)
done

# --- .zsh directory ---
for subdir in sync defer; do
  src_dir="$DOTFILES_DIR/.zsh/$subdir"
  [ -d "$src_dir" ] || continue
  while IFS= read -r -d '' file; do
    rel="${file#"$src_dir/"}"
    link_file "$file" "$HOME/.zsh/$subdir/$rel"
  done < <(find "$src_dir" -type f -print0)
done

# --- Install mise tools (must run before skills install; needs symlinked mise config) ---
info "Installing mise tools..."
mise install --yes

# --- Install datadog agent skills ---
# Note: `skills experimental_install` ignores --full-depth state stored in skills-lock.json,
# so we re-run the original `skills add` command directly. skills-lock.json is still committed
# as an audit trail and is regenerated on each run.
# Upstream: https://github.com/datadog-labs/agent-skills
info "Installing datadog agent skills..."
(cd "$DOTFILES_DIR" && mise exec -- npx -y skills add datadog-labs/agent-skills \
  --skill dd-pup \
  --skill dd-monitors \
  --skill dd-logs \
  --skill dd-apm \
  --skill dd-docs \
  --full-depth -y)
ok "Datadog agent skills installed"

# --- Install playwright-cli skill (bundled with @playwright/cli npm package) ---
# Materializes .claude/skills/playwright-cli/ inside $DOTFILES_DIR (gitignored).
if mise exec -- bash -c 'command -v playwright-cli' >/dev/null 2>&1; then
  info "Installing playwright-cli skill..."
  (cd "$DOTFILES_DIR" && mise exec -- playwright-cli install --skills)
  ok "playwright-cli skill installed"
else
  warn "playwright-cli not found in mise; skipping skill install"
fi

# --- Prune dangling symlinks in $HOME/.claude (sources removed from dotfiles) ---
# Matches "symlinks whose target does not exist". `test -e` dereferences symlinks,
# so `! -exec test -e {} \;` selects only broken ones. Portable across BSD (macOS) find.
for dir in agents assets commands rules scripts skills; do
  [ -d "$HOME/.claude/$dir" ] || continue
  while IFS= read -r pruned; do
    rm "$pruned"
    ok "Pruned dangling symlink: $pruned"
  done < <(find "$HOME/.claude/$dir" -type l ! -exec test -e {} \; -print)
done

# --- .claude directory (-type l picks up dd-* symlinks at top of skills/) ---
claude_dirs=("agents" "assets" "commands" "rules" "scripts" "skills")
for dir in "${claude_dirs[@]}"; do
  src_dir="$DOTFILES_DIR/.claude/$dir"
  [ -d "$src_dir" ] || continue
  while IFS= read -r -d '' file; do
    rel="${file#"$src_dir/"}"
    link_file "$file" "$HOME/.claude/$dir/$rel"
  done < <(find "$src_dir" \( -type f -o -type l \) -print0)
done
# settings.json (single file)
[ -f "$DOTFILES_DIR/.claude/settings.json" ] && \
  link_file "$DOTFILES_DIR/.claude/settings.json" "$HOME/.claude/settings.json"

# --- .agents directory symlink (required so relative dd-* symlinks resolve in $HOME) ---
if [ -d "$DOTFILES_DIR/.agents" ]; then
  link_file "$DOTFILES_DIR/.agents" "$HOME/.agents"
fi

# --- Legacy ~/.gitconfig cleanup ---
if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
  warn "Found ~/.gitconfig (non-symlink). Git will use ~/.config/git/config (XDG) instead."
  warn "Backing up to ~/.gitconfig.backup"
  mv "$HOME/.gitconfig" "$HOME/.gitconfig.backup"
fi

ok "dotfiles installation complete!"
info "Open a new terminal or run: exec zsh"
