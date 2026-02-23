# ============================================
# zsh_setting.zsh - History, options, colors, prompt
# Loaded synchronously via sheldon
# ============================================

# --- History ---
HISTFILE=~/.zsh_history
export HISTSIZE=50000
export SAVEHIST=100000
setopt hist_ignore_dups
setopt EXTENDED_HISTORY
setopt share_history
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt hist_save_no_dups
setopt hist_no_store
setopt hist_expand
setopt inc_append_history
function history-all { history -E 1 }

# --- Key bindings ---
bindkey -v

# --- Options ---
setopt correct
setopt no_beep
unsetopt nomatch

# --- Colors ---
autoload -Uz colors
colors

# --- Completion colors ---
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
