#!/usr/bin/env bash
# Test helpers for install.bats. Sourced from each test file.

setup() {
  # Each test gets its own isolated HOME under tests/tmp/.
  TEST_TMP="$BATS_TEST_TMPDIR"
  export HOME="$TEST_TMP/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  mkdir -p "$HOME/.claude"

  # A fixture vault location for each test.
  export FIXTURE_VAULT="$TEST_TMP/vault"
  mkdir -p "$FIXTURE_VAULT/Projects" "$FIXTURE_VAULT/Inbox" "$FIXTURE_VAULT/AI/session"

  # Path to the repo under test.
  export REPO_ROOT="$BATS_TEST_DIRNAME/.."

  # Default: pretend jq is installed (it is — verified in setup_suite).
  unset AGENTIC_SECOND_BRAIN_VAULT
}

teardown() {
  # bats handles BATS_TEST_TMPDIR cleanup automatically.
  :
}

# Run install.sh with a fresh shell, isolated HOME.
run_install() {
  run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    bash "$REPO_ROOT/install.sh" "$@"
}

# Assert a file exists.
assert_file_exists() {
  [ -f "$1" ] || { echo "expected file: $1" >&2; return 1; }
}

# Assert a symlink target.
assert_symlink_to() {
  local link="$1" target="$2"
  [ -L "$link" ] || { echo "not a symlink: $link" >&2; return 1; }
  local actual
  actual=$(readlink "$link")
  [ "$actual" = "$target" ] || { echo "symlink $link → $actual, expected $target" >&2; return 1; }
}

# Assert a JSON file has a specific jq query result.
assert_json_eq() {
  local file="$1" query="$2" expected="$3"
  local actual
  actual=$(jq -r "$query" "$file")
  [ "$actual" = "$expected" ] || { echo "$file $query = $actual, expected $expected" >&2; return 1; }
}
