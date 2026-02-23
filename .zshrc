# ============================================
# .zshrc - Interactive shell setup (minimal)
# ============================================

# --- Homebrew ---
eval "$(/opt/homebrew/bin/brew shellenv)"

# --- mise ---
eval "$(mise activate zsh)"

# --- sheldon ---
if [ ! $commands[sheldon] ]; then
  curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh \
    | bash -s -- --repo rossmacarthur/sheldon --to ~/.local/bin
fi
eval "$(sheldon source)"

# --- Local overrides (secrets, machine-specific) ---
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
