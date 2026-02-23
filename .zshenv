# ============================================
# .zshenv - Environment variables, PATH, aliases
# Loaded for ALL zsh sessions (interactive + non-interactive)
# ============================================

# --- Locale ---
export LANG="en_US.UTF-8"

# --- Editor ---
export EDITOR=vim

# --- XDG ---
export XDG_CONFIG_HOME="$HOME/.config"

# --- Colors ---
export CLICOLOR=true
export LSCOLORS='exfxcxdxbxGxDxabagacad'
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=36;01:cd=33;01:su=31;40;07:sg=36;40;07:tw=32;40;07:ow=33;40;07:'

# --- PATH ---
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/opt/curl/bin:$PATH"

# --- Aliases ---
alias ll='eza -la --icons --git'
alias g='cd $(ghq list -p | fzf)'

# --- Local overrides (secrets, machine-specific) ---
[ -f "$HOME/.zshenv.local" ] && source "$HOME/.zshenv.local"
