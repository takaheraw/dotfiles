#!/usr/bin/env bash

# Load bats helper libraries
load '/usr/local/lib/bats-support/load'
load '/usr/local/lib/bats-assert/load'

# Project root
export DOTFILES_DIR
DOTFILES_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"

# Create a temporary sandbox for each test
setup_sandbox() {
  export SANDBOX
  SANDBOX="$(mktemp -d)"
  export HOME="$SANDBOX/home"
  mkdir -p "$HOME"
}

teardown_sandbox() {
  [ -d "${SANDBOX:-}" ] && rm -rf "$SANDBOX"
}
