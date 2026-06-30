#!/usr/bin/env bats

load test_helper

setup() {
  setup_sandbox

  export SCRIPT="$DOTFILES_DIR/.claude/scripts/statusline.sh"
  export CACHE_FILE="$SANDBOX/cost_cache"

  # Create a patched version that uses our sandbox cache and Linux-compatible stat
  export PATCHED_SCRIPT="$SANDBOX/statusline-patched.sh"
  sed \
    -e "s|/tmp/claude_statusline_cost_cache|$CACHE_FILE|g" \
    -e 's|stat -f %m|stat -c %Y|g' \
    "$SCRIPT" > "$PATCHED_SCRIPT"
  chmod +x "$PATCHED_SCRIPT"
}

teardown() {
  teardown_sandbox
}

make_session_input() {
  local model="${1:-claude-sonnet-4-20250514}"
  local display="${2:-Claude Sonnet}"
  local pct="${3:-42.5}"
  cat <<JSON
{
  "model": {"display_name": "$display"},
  "context_window": {"used_percentage": $pct},
  "cost": {"total_cost_usd": 1.23}
}
JSON
}

make_session_input_with_limits() {
  local display="${1:-Claude Sonnet}"
  local pct="${2:-50}"
  local five_h="${3:-30}"
  local week="${4:-10}"
  cat <<JSON
{
  "model": {"display_name": "$display"},
  "context_window": {"used_percentage": $pct},
  "cost": {"total_cost_usd": 1.23},
  "rate_limits": {
    "five_hour": {"used_percentage": $five_h},
    "seven_day": {"used_percentage": $week}
  }
}
JSON
}

# ---------------------------------------------------------------
# calculate_daily_cost (isolated)
# ---------------------------------------------------------------

@test "statusline: calculate_daily_cost returns 0 when npx is unavailable" {
  # Extract and test calculate_daily_cost in isolation
  run bash -c "
    source <(sed -n '/^calculate_daily_cost()/,/^}/p' '$SCRIPT')
    # Override PATH to remove npx
    PATH=/usr/bin:/bin
    calculate_daily_cost
  "
  assert_success
  assert_output "0"
}

# ---------------------------------------------------------------
# get_cached_cost
# ---------------------------------------------------------------

@test "statusline: get_cached_cost returns cached value when cache is fresh" {
  local today
  today=$(date +%Y%m%d)

  # Write a fresh cache
  printf '%s\n%s\n' "$today" "5.67" > "$CACHE_FILE"

  run bash -c "
    CACHE_FILE='$CACHE_FILE'
    readonly CACHE_TTL=60
    source <(sed -n '/^calculate_daily_cost()/,/^}/p' '$PATCHED_SCRIPT')
    source <(sed -n '/^get_cached_cost()/,/^}/p' '$PATCHED_SCRIPT')
    get_cached_cost
  "
  assert_success
  assert_output "5.67"
}

@test "statusline: get_cached_cost recalculates when cache date differs" {
  # Write a stale cache with yesterday's date
  printf '%s\n%s\n' "19700101" "99.99" > "$CACHE_FILE"

  run bash -c "
    CACHE_FILE='$CACHE_FILE'
    readonly CACHE_TTL=60
    # Stub calculate_daily_cost to return known value
    calculate_daily_cost() { echo '0'; }
    source <(sed -n '/^get_cached_cost()/,/^}/p' '$PATCHED_SCRIPT')
    get_cached_cost
  "
  assert_success
  assert_output "0"
}

@test "statusline: get_cached_cost creates cache file when none exists" {
  [ ! -f "$CACHE_FILE" ]

  run bash -c "
    CACHE_FILE='$CACHE_FILE'
    readonly CACHE_TTL=60
    calculate_daily_cost() { echo '3.14'; }
    source <(sed -n '/^get_cached_cost()/,/^}/p' '$PATCHED_SCRIPT')
    get_cached_cost
  "
  assert_success
  assert_output "3.14"
  [ -f "$CACHE_FILE" ]
}

# ---------------------------------------------------------------
# Full script output format
# ---------------------------------------------------------------

@test "statusline: outputs model name in status line" {
  # Stub get_cached_cost by pre-seeding a fresh cache
  local today
  today=$(date +%Y%m%d)
  printf '%s\n%s\n' "$today" "0" > "$CACHE_FILE"

  local input
  input=$(make_session_input "claude-sonnet" "Claude Sonnet" "42.5")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success
  assert_output --partial "Claude Sonnet"
}

@test "statusline: outputs context percentage as integer" {
  local today
  today=$(date +%Y%m%d)
  printf '%s\n%s\n' "$today" "0" > "$CACHE_FILE"

  local input
  input=$(make_session_input "model" "TestModel" "67.8")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success
  assert_output --partial "67%"
}

@test "statusline: outputs cost formatted as dollars" {
  local today
  today=$(date +%Y%m%d)
  printf '%s\n%s\n' "$today" "12.5" > "$CACHE_FILE"

  local input
  input=$(make_session_input "model" "TestModel" "50")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success
  assert_output --partial '$12.50'
}

@test "statusline: includes rate limits when present" {
  local today
  today=$(date +%Y%m%d)
  printf '%s\n%s\n' "$today" "0" > "$CACHE_FILE"

  local input
  input=$(make_session_input_with_limits "TestModel" "50" "30" "10")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success
  assert_output --partial "5h 30%"
  assert_output --partial "7d 10%"
}

@test "statusline: omits rate limits when absent" {
  local today
  today=$(date +%Y%m%d)
  printf '%s\n%s\n' "$today" "0" > "$CACHE_FILE"

  local input
  input=$(make_session_input "model" "TestModel" "50")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success
  # Should not contain rate limit indicators
  refute_output --partial "5h"
  refute_output --partial "7d"
}

@test "statusline: handles unknown model gracefully" {
  local today
  today=$(date +%Y%m%d)
  printf '%s\n%s\n' "$today" "0" > "$CACHE_FILE"

  local input='{"model":{},"context_window":{"used_percentage":10}}'

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success
  assert_output --partial "unknown"
}

@test "statusline: output contains all expected sections separated by pipes" {
  local today
  today=$(date +%Y%m%d)
  printf '%s\n%s\n' "$today" "1" > "$CACHE_FILE"

  local input
  input=$(make_session_input "model" "MyModel" "25")

  run bash -c "echo '$input' | bash '$PATCHED_SCRIPT'"
  assert_success
  # Check for the pipe-separated format
  assert_output --partial "|"
  # Count pipes: should have at least 2 (model | cost | context)
  local pipe_count
  pipe_count=$(echo "$output" | tr -cd '|' | wc -c)
  [ "$pipe_count" -ge 2 ]
}
