#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

info() { printf '\033[34m[INFO]\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$1"; }
ok()   { printf '\033[32m[ OK ]\033[0m %s\n' "$1"; }

# --- Shared helpers ---

# link_file <src> <dst>
# Creates a symlink, backing up existing non-symlink files.
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

# ensure_cmd <cmd> <label> <install_body>
# Installs <cmd> if missing, otherwise reports it already present.
ensure_cmd() {
  local cmd="$1" label="$2"
  shift 2
  if ! command -v "$cmd" &>/dev/null; then
    info "Installing $label..."
    "$@"
    ok "$label installed"
  else
    ok "$label already installed"
  fi
}

# link_dir <src_base> <dst_base> <dirs_array_name> [find_extra_args...]
# Recursively symlinks files from <src_base>/<dir> to <dst_base>/<dir>.
link_dir() {
  local src_base="$1" dst_base="$2" dirs_var="$3"
  shift 3
  local find_types=("$@")
  [[ ${#find_types[@]} -eq 0 ]] && find_types=(-type f)
  local -n _dirs="$dirs_var"
  for dir in "${_dirs[@]}"; do
    local src_dir="$src_base/$dir"
    [ -d "$src_dir" ] || continue
    while IFS= read -r -d '' file; do
      local rel="${file#"$src_dir/"}"
      link_file "$file" "$dst_base/$dir/$rel"
    done < <(find "$src_dir" "${find_types[@]}" -print0)
  done
}

# install_skills <label> <repo> <skills...>
# Wraps the `npx skills add` pattern used for agent skill bundles.
install_skills() {
  local label="$1" repo="$2"
  shift 2
  local skill_args=()
  for s in "$@"; do
    skill_args+=(--skill "$s")
  done
  info "Installing $label..."
  (cd "$DOTFILES_DIR" && mise exec -- npx -y skills add "$repo" \
    "${skill_args[@]}" --full-depth -y)
  ok "$label installed"
}

SHELDON_INSTALL_URL="${SHELDON_INSTALL_URL:-https://rossmacarthur.github.io/install/crate.sh}"

# --- Install prerequisites ---
_install_brew()    { /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; eval "$(/opt/homebrew/bin/brew shellenv)"; }
_install_mise()    { curl -fsSL https://mise.run | sh; export PATH="$HOME/.local/bin:$PATH"; }
_install_sheldon() { curl --proto '=https' -fLsS "$SHELDON_INSTALL_URL" | bash -s -- --repo rossmacarthur/sheldon --to "$HOME/.local/bin"; }

ensure_cmd brew    Homebrew _install_brew
ensure_cmd mise    mise     _install_mise
ensure_cmd sheldon sheldon  _install_sheldon

# --- Dotfiles (top-level) ---
for f in .zshrc .zshenv .vimrc; do
  [ -f "$DOTFILES_DIR/$f" ] && link_file "$DOTFILES_DIR/$f" "$HOME/$f"
done

# --- .config directories (file-level recursive symlinks) ---
config_dirs=("ghostty" "git" "hunk" "mise" "sheldon")
link_dir "$DOTFILES_DIR/.config" "$HOME/.config" config_dirs

# --- .zsh directory ---
zsh_dirs=("sync" "defer")
link_dir "$DOTFILES_DIR/.zsh" "$HOME/.zsh" zsh_dirs

# --- Install mise tools (must run before skills install; needs symlinked mise config) ---
info "Installing mise tools..."
mise install --yes

# --- Install agent skills ---
# skills-lock.json is the audit trail; `skills add` is re-run directly
# because `skills experimental_install` ignores --full-depth state.
install_skills "Datadog agent skills"      datadog-labs/agent-skills   dd-pup dd-monitors dd-logs dd-apm dd-docs
install_skills "Planetscale database skills" planetscale/database-skills postgres

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
link_dir "$DOTFILES_DIR/.claude" "$HOME/.claude" claude_dirs \( -type f -o -type l \)
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
