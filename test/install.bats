#!/usr/bin/env bats

load test_helper

setup() {
  setup_sandbox

  # Create a minimal dotfiles tree inside the sandbox
  export DOTFILES_SRC="$SANDBOX/dotfiles"
  mkdir -p "$DOTFILES_SRC"

  # Source only the helper functions from install.sh (skip the execution parts)
  # We extract link_file and the logging helpers
  eval "$(sed -n '1,52p' "$DOTFILES_DIR/install.sh")"
  # Override DOTFILES_DIR to point at our sandbox copy
  DOTFILES_DIR="$DOTFILES_SRC"
}

teardown() {
  teardown_sandbox
}

# ---------------------------------------------------------------
# link_file tests
# ---------------------------------------------------------------

@test "link_file creates a symlink to the source" {
  local src="$DOTFILES_SRC/somefile"
  local dst="$HOME/somefile"
  echo "content" > "$src"

  link_file "$src" "$dst"

  [ -L "$dst" ]
  [ "$(readlink "$dst")" = "$src" ]
}

@test "link_file creates parent directories when they don't exist" {
  local src="$DOTFILES_SRC/a/b/c"
  local dst="$HOME/deep/nested/link"
  mkdir -p "$(dirname "$src")"
  echo "data" > "$src"

  link_file "$src" "$dst"

  [ -d "$HOME/deep/nested" ]
  [ -L "$dst" ]
}

@test "link_file replaces an existing symlink" {
  local src_old="$SANDBOX/old_target"
  local src_new="$DOTFILES_SRC/new_target"
  local dst="$HOME/mylink"
  echo "old" > "$src_old"
  echo "new" > "$src_new"

  ln -s "$src_old" "$dst"
  [ "$(readlink "$dst")" = "$src_old" ]

  link_file "$src_new" "$dst"

  [ "$(readlink "$dst")" = "$src_new" ]
}

@test "link_file backs up an existing regular file" {
  local src="$DOTFILES_SRC/dotfile"
  local dst="$HOME/dotfile"
  echo "source" > "$src"
  echo "existing" > "$dst"

  link_file "$src" "$dst"

  [ -L "$dst" ]
  [ -f "${dst}.backup" ]
  [ "$(cat "${dst}.backup")" = "existing" ]
}

@test "link_file target content is accessible through the symlink" {
  local src="$DOTFILES_SRC/readable"
  local dst="$HOME/readable"
  echo "hello world" > "$src"

  link_file "$src" "$dst"

  [ "$(cat "$dst")" = "hello world" ]
}

# ---------------------------------------------------------------
# Top-level dotfile symlink loop
# ---------------------------------------------------------------

@test "top-level dotfiles loop links .zshrc .zshenv .vimrc" {
  for f in .zshrc .zshenv .vimrc; do
    echo "$f content" > "$DOTFILES_SRC/$f"
  done

  for f in .zshrc .zshenv .vimrc; do
    [ -f "$DOTFILES_SRC/$f" ] && link_file "$DOTFILES_SRC/$f" "$HOME/$f"
  done

  for f in .zshrc .zshenv .vimrc; do
    [ -L "$HOME/$f" ]
    [ "$(readlink "$HOME/$f")" = "$DOTFILES_SRC/$f" ]
  done
}

@test "top-level loop skips files that don't exist" {
  # Only create .zshrc, not .zshenv or .vimrc
  echo "rc" > "$DOTFILES_SRC/.zshrc"

  for f in .zshrc .zshenv .vimrc; do
    [ -f "$DOTFILES_SRC/$f" ] && link_file "$DOTFILES_SRC/$f" "$HOME/$f"
  done

  [ -L "$HOME/.zshrc" ]
  [ ! -e "$HOME/.zshenv" ]
  [ ! -e "$HOME/.vimrc" ]
}

# ---------------------------------------------------------------
# .config directory recursive symlinks
# ---------------------------------------------------------------

@test "config dir loop creates file-level symlinks recursively" {
  local src_dir="$DOTFILES_SRC/.config/git"
  mkdir -p "$src_dir/subdir"
  echo "gitcfg" > "$src_dir/config"
  echo "ignore" > "$src_dir/ignore"
  echo "nested" > "$src_dir/subdir/deep"

  while IFS= read -r -d '' file; do
    rel="${file#"$src_dir/"}"
    link_file "$file" "$HOME/.config/git/$rel"
  done < <(find "$src_dir" -type f -print0)

  [ -L "$HOME/.config/git/config" ]
  [ -L "$HOME/.config/git/ignore" ]
  [ -L "$HOME/.config/git/subdir/deep" ]
}

@test "config dir loop skips non-existent source directories" {
  # Don't create any config dir
  local config_dirs=("ghostty" "git" "hunk" "mise" "sheldon")
  local count=0

  for dir in "${config_dirs[@]}"; do
    src_dir="$DOTFILES_SRC/.config/$dir"
    [ -d "$src_dir" ] || continue
    count=$((count + 1))
  done

  [ "$count" -eq 0 ]
}

# ---------------------------------------------------------------
# .zsh directory symlinks
# ---------------------------------------------------------------

@test "zsh subdir loop creates symlinks for sync and defer" {
  mkdir -p "$DOTFILES_SRC/.zsh/sync" "$DOTFILES_SRC/.zsh/defer"
  echo "sync_content" > "$DOTFILES_SRC/.zsh/sync/zsh_setting.zsh"
  echo "defer_content" > "$DOTFILES_SRC/.zsh/defer/completion.zsh"

  for subdir in sync defer; do
    src_dir="$DOTFILES_SRC/.zsh/$subdir"
    [ -d "$src_dir" ] || continue
    while IFS= read -r -d '' file; do
      rel="${file#"$src_dir/"}"
      link_file "$file" "$HOME/.zsh/$subdir/$rel"
    done < <(find "$src_dir" -type f -print0)
  done

  [ -L "$HOME/.zsh/sync/zsh_setting.zsh" ]
  [ -L "$HOME/.zsh/defer/completion.zsh" ]
  [ "$(cat "$HOME/.zsh/sync/zsh_setting.zsh")" = "sync_content" ]
  [ "$(cat "$HOME/.zsh/defer/completion.zsh")" = "defer_content" ]
}

# ---------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------

@test "info outputs blue [INFO] prefix" {
  run info "test message"
  assert_output --partial "[INFO]"
  assert_output --partial "test message"
}

@test "warn outputs yellow [WARN] prefix" {
  run warn "warning text"
  assert_output --partial "[WARN]"
  assert_output --partial "warning text"
}

@test "ok outputs green [ OK ] prefix" {
  run ok "success note"
  assert_output --partial "[ OK ]"
  assert_output --partial "success note"
}

# ---------------------------------------------------------------
# Legacy gitconfig cleanup logic
# ---------------------------------------------------------------

@test "legacy gitconfig: regular file is backed up" {
  echo "legacy" > "$HOME/.gitconfig"

  # Simulate the cleanup logic from install.sh
  if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
    mv "$HOME/.gitconfig" "$HOME/.gitconfig.backup"
  fi

  [ ! -f "$HOME/.gitconfig" ]
  [ -f "$HOME/.gitconfig.backup" ]
  [ "$(cat "$HOME/.gitconfig.backup")" = "legacy" ]
}

@test "legacy gitconfig: symlink is left alone" {
  local target="$SANDBOX/git_target"
  echo "target" > "$target"
  ln -s "$target" "$HOME/.gitconfig"

  if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
    mv "$HOME/.gitconfig" "$HOME/.gitconfig.backup"
  fi

  # Symlink should still exist
  [ -L "$HOME/.gitconfig" ]
  [ ! -f "$HOME/.gitconfig.backup" ]
}

# ---------------------------------------------------------------
# Dangling symlink pruning
# ---------------------------------------------------------------

@test "dangling symlink pruning removes broken symlinks" {
  mkdir -p "$HOME/.claude/scripts"
  # Create a dangling symlink (target does not exist)
  ln -s "$SANDBOX/nonexistent" "$HOME/.claude/scripts/broken_link"
  # Create a valid symlink
  local valid_target="$SANDBOX/valid_target"
  echo "valid" > "$valid_target"
  ln -s "$valid_target" "$HOME/.claude/scripts/good_link"

  # Simulate the pruning logic
  for dir in scripts; do
    [ -d "$HOME/.claude/$dir" ] || continue
    while IFS= read -r pruned; do
      rm "$pruned"
    done < <(find "$HOME/.claude/$dir" -type l ! -exec test -e {} \; -print)
  done

  [ ! -e "$HOME/.claude/scripts/broken_link" ]
  [ -L "$HOME/.claude/scripts/good_link" ]
}
