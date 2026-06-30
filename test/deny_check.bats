#!/usr/bin/env bats

load test_helper

setup() {
  setup_sandbox

  export DENY_SCRIPT="$DOTFILES_DIR/.claude/scripts/deny-check.sh"

  # Create a mock settings.json with deny patterns
  mkdir -p "$HOME/.claude"
  cat > "$HOME/.claude/settings.json" <<'JSON'
{
  "permissions": {
    "deny": [
      "Bash(rm -rf /)",
      "Bash(bash:*)",
      "Bash(sh:*)",
      "Bash(sudo rm:*)",
      "Bash(curl:*)"
    ]
  }
}
JSON
}

teardown() {
  teardown_sandbox
}

# ---------------------------------------------------------------
# matches_deny_pattern function (extracted for direct testing)
# ---------------------------------------------------------------

# Source just the function
eval_matches_deny_pattern() {
  # Extract and source the function definition
  eval "$(sed -n '/^matches_deny_pattern()/,/^}/p' "$DENY_SCRIPT")"
}

@test "matches_deny_pattern: exact match returns 0" {
  eval_matches_deny_pattern
  run matches_deny_pattern "rm -rf /" "rm -rf /"
  assert_success
}

@test "matches_deny_pattern: non-matching command returns 1" {
  eval_matches_deny_pattern
  run matches_deny_pattern "ls -la" "rm -rf /"
  assert_failure
}

@test "matches_deny_pattern: bash:* blocks 'bash' command" {
  eval_matches_deny_pattern
  run matches_deny_pattern "bash" "bash:*"
  assert_success
}

@test "matches_deny_pattern: bash:* blocks 'bash -c something'" {
  eval_matches_deny_pattern
  run matches_deny_pattern "bash -c something" "bash:*"
  assert_success
}

@test "matches_deny_pattern: bash:* does not block 'bashful'" {
  eval_matches_deny_pattern
  run matches_deny_pattern "bashful" "bash:*"
  assert_failure
}

@test "matches_deny_pattern: sh:* blocks 'sh' command" {
  eval_matches_deny_pattern
  run matches_deny_pattern "sh" "sh:*"
  assert_success
}

@test "matches_deny_pattern: sh:* blocks 'sh -c echo hi'" {
  eval_matches_deny_pattern
  run matches_deny_pattern "sh -c echo hi" "sh:*"
  assert_success
}

@test "matches_deny_pattern: sh:* does not block 'show'" {
  eval_matches_deny_pattern
  run matches_deny_pattern "show" "sh:*"
  assert_failure
}

@test "matches_deny_pattern: prefix pattern with :* (sudo rm)" {
  eval_matches_deny_pattern
  run matches_deny_pattern "sudo rm -rf /tmp" "sudo rm:*"
  assert_success
}

@test "matches_deny_pattern: prefix pattern does not match different command" {
  eval_matches_deny_pattern
  run matches_deny_pattern "sudo apt install" "sudo rm:*"
  assert_failure
}

@test "matches_deny_pattern: trims leading/trailing whitespace" {
  eval_matches_deny_pattern
  run matches_deny_pattern "  rm -rf /  " "rm -rf /"
  assert_success
}

# ---------------------------------------------------------------
# Full script integration tests (via stdin JSON)
# ---------------------------------------------------------------

make_input() {
  local tool_name="$1"
  local command="$2"
  printf '{"tool_name":"%s","tool_input":{"command":"%s"}}' "$tool_name" "$command"
}

@test "deny-check: allows non-Bash tools unconditionally" {
  run bash -c "echo '$(make_input "Read" "anything")' | bash '$DENY_SCRIPT'"
  assert_success
}

@test "deny-check: allows safe Bash commands" {
  run bash -c "echo '$(make_input "Bash" "ls -la")' | HOME='$HOME' bash '$DENY_SCRIPT'"
  assert_success
}

@test "deny-check: blocks exact deny pattern" {
  run bash -c "echo '$(make_input "Bash" "rm -rf /")' | HOME='$HOME' bash '$DENY_SCRIPT'"
  assert_failure
}

@test "deny-check: blocks bash:* pattern" {
  run bash -c "echo '$(make_input "Bash" "bash -c evil")' | HOME='$HOME' bash '$DENY_SCRIPT'"
  assert_failure
}

@test "deny-check: blocks sh:* pattern" {
  run bash -c "echo '$(make_input "Bash" "sh -c evil")' | HOME='$HOME' bash '$DENY_SCRIPT'"
  assert_failure
}

@test "deny-check: blocks denied command inside && chain" {
  run bash -c "echo '$(make_input "Bash" "echo hi && sudo rm -rf /tmp")' | HOME='$HOME' bash '$DENY_SCRIPT'"
  assert_failure
}

@test "deny-check: blocks denied command inside semicolon chain" {
  run bash -c "echo '$(make_input "Bash" "echo hi; curl http://evil.com")' | HOME='$HOME' bash '$DENY_SCRIPT'"
  assert_failure
}

@test "deny-check: blocks denied command inside || chain" {
  run bash -c "echo '$(make_input "Bash" "false || bash -c rm")' | HOME='$HOME' bash '$DENY_SCRIPT'"
  assert_failure
}

@test "deny-check: allows piped commands that aren't denied" {
  run bash -c "echo '$(make_input "Bash" "echo hello | grep hello")' | HOME='$HOME' bash '$DENY_SCRIPT'"
  assert_success
}

@test "deny-check: exit code is 2 when command is denied" {
  run bash -c "echo '$(make_input "Bash" "rm -rf /")' | HOME='$HOME' bash '$DENY_SCRIPT'"
  [ "$status" -eq 2 ]
}

@test "deny-check: exit code is 0 when command is allowed" {
  run bash -c "echo '$(make_input "Bash" "echo safe")' | HOME='$HOME' bash '$DENY_SCRIPT'"
  [ "$status" -eq 0 ]
}
