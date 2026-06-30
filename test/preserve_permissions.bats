#!/usr/bin/env bats

load test_helper

setup() {
  setup_sandbox

  export SCRIPT="$DOTFILES_DIR/.claude/scripts/preserve-file-permissions.sh"
  export PERMISSIONS_CACHE="$SANDBOX/permissions_cache.txt"
  export DEBUG_LOG="$SANDBOX/debug.log"

  # Override the cache/log paths used by the script
  export PATCHED_SCRIPT="$SANDBOX/preserve-patched.sh"
  sed \
    -e "s|/tmp/claude_file_permissions.txt|$PERMISSIONS_CACHE|g" \
    -e "s|/tmp/claude_permissions_debug.log|$DEBUG_LOG|g" \
    "$SCRIPT" > "$PATCHED_SCRIPT"
  chmod +x "$PATCHED_SCRIPT"
}

teardown() {
  teardown_sandbox
}

make_input() {
  local hook="$1" tool="$2" file="$3"
  cat <<JSON
{"hook_event_name":"$hook","tool_name":"$tool","tool_input":{"file_path":"$file"}}
JSON
}

# ---------------------------------------------------------------
# Non-file-operation tools should pass through
# ---------------------------------------------------------------

@test "preserve-permissions: non-Write/Edit tool passes through unchanged" {
  local input
  input=$(make_input "PreToolUse" "Read" "/some/path")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success
  assert_output "$input"
}

@test "preserve-permissions: Bash tool passes through unchanged" {
  local input
  input=$(make_input "PreToolUse" "Bash" "/some/path")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success
  assert_output "$input"
}

# ---------------------------------------------------------------
# Empty file_path passes through
# ---------------------------------------------------------------

@test "preserve-permissions: empty file_path passes through" {
  local input
  input=$(make_input "PreToolUse" "Write" "")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success
  assert_output "$input"
}

# ---------------------------------------------------------------
# PreToolUse: saves file permissions
# ---------------------------------------------------------------

@test "preserve-permissions: PreToolUse saves permissions of existing file" {
  local test_file="$SANDBOX/testfile.sh"
  echo "#!/bin/bash" > "$test_file"
  chmod 755 "$test_file"

  local input
  input=$(make_input "PreToolUse" "Write" "$test_file")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success

  # Check that the permissions were saved to cache
  [ -f "$PERMISSIONS_CACHE" ]
  run grep "$test_file" "$PERMISSIONS_CACHE"
  assert_success
  # Verify permissions value is stored (platform-dependent format)
  run grep "755" "$PERMISSIONS_CACHE"
  assert_success
}

@test "preserve-permissions: PreToolUse skips non-existent file" {
  local input
  input=$(make_input "PreToolUse" "Write" "$SANDBOX/nonexistent")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success

  # Cache file should not be created (or not contain the path)
  if [ -f "$PERMISSIONS_CACHE" ]; then
    run grep "nonexistent" "$PERMISSIONS_CACHE"
    assert_failure
  fi
}

@test "preserve-permissions: PreToolUse handles Edit tool as well" {
  local test_file="$SANDBOX/editable.txt"
  echo "content" > "$test_file"
  chmod 644 "$test_file"

  local input
  input=$(make_input "PreToolUse" "Edit" "$test_file")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success

  [ -f "$PERMISSIONS_CACHE" ]
  run grep "$test_file" "$PERMISSIONS_CACHE"
  assert_success
  # Verify permissions value is stored (platform-dependent format)
  run grep "644" "$PERMISSIONS_CACHE"
  assert_success
}

# ---------------------------------------------------------------
# PostToolUse: restores file permissions
# ---------------------------------------------------------------

@test "preserve-permissions: PostToolUse restores permissions from cache" {
  local test_file="$SANDBOX/script.sh"
  echo "#!/bin/bash" > "$test_file"
  chmod 755 "$test_file"

  # Simulate a pre-existing cache entry
  echo "${test_file}:755" > "$PERMISSIONS_CACHE"

  # Simulate the file being written with default perms
  chmod 644 "$test_file"
  [ "$(stat -c '%a' "$test_file")" = "644" ]

  local input
  input=$(make_input "PostToolUse" "Write" "$test_file")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success

  # Permissions should be restored
  [ "$(stat -c '%a' "$test_file")" = "755" ]
}

@test "preserve-permissions: PostToolUse removes cache entry after restoring" {
  local test_file="$SANDBOX/cleaned.sh"
  echo "data" > "$test_file"
  chmod 755 "$test_file"

  echo "${test_file}:755" > "$PERMISSIONS_CACHE"
  echo "/other/file:644" >> "$PERMISSIONS_CACHE"

  local input
  input=$(make_input "PostToolUse" "Write" "$test_file")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success

  # The entry for test_file should be removed, but /other/file remains
  run grep "$test_file" "$PERMISSIONS_CACHE"
  assert_failure
  run grep "/other/file" "$PERMISSIONS_CACHE"
  assert_success
}

@test "preserve-permissions: PostToolUse with no cache does nothing" {
  local test_file="$SANDBOX/nocache.txt"
  echo "content" > "$test_file"
  chmod 644 "$test_file"

  local input
  input=$(make_input "PostToolUse" "Write" "$test_file")

  # No cache file exists
  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success

  # Permissions unchanged
  [ "$(stat -c '%a' "$test_file")" = "644" ]
}

# ---------------------------------------------------------------
# Output: script always echoes the input JSON back
# ---------------------------------------------------------------

@test "preserve-permissions: PreToolUse echoes input JSON" {
  local test_file="$SANDBOX/echo_test.txt"
  echo "data" > "$test_file"
  chmod 644 "$test_file"

  local input
  input=$(make_input "PreToolUse" "Write" "$test_file")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success
  assert_output --partial "PreToolUse"
  assert_output --partial "Write"
}

@test "preserve-permissions: PostToolUse echoes input JSON" {
  local test_file="$SANDBOX/echo_post.txt"
  echo "data" > "$test_file"
  chmod 644 "$test_file"

  local input
  input=$(make_input "PostToolUse" "Write" "$test_file")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success
  assert_output --partial "PostToolUse"
  assert_output --partial "Write"
}

# ---------------------------------------------------------------
# Debug log
# ---------------------------------------------------------------

@test "preserve-permissions: writes debug log entries" {
  local test_file="$SANDBOX/debugged.sh"
  echo "data" > "$test_file"
  chmod 755 "$test_file"

  local input
  input=$(make_input "PreToolUse" "Write" "$test_file")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success

  [ -f "$DEBUG_LOG" ]
  run grep "PreToolUse" "$DEBUG_LOG"
  assert_success
}
