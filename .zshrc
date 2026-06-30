# ============================================
# .zshrc - Interactive shell setup (minimal)
# ============================================

# --- Homebrew ---
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "[WARN] Homebrew not found at /opt/homebrew/bin/brew" >&2
fi

# --- mise ---
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
else
  echo "[WARN] mise not found in PATH" >&2
fi

# --- sheldon ---
if [ ! $commands[sheldon] ]; then
  curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh \
    | bash -s -- --repo rossmacarthur/sheldon --to ~/.local/bin \
    || echo "[WARN] sheldon installation failed" >&2
fi
if command -v sheldon >/dev/null 2>&1; then
  eval "$(sheldon source)"
else
  echo "[WARN] sheldon not found in PATH; plugins not loaded" >&2
fi

# --- Local overrides (secrets, machine-specific) ---
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
