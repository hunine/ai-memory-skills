#!/usr/bin/env bats

load 'test_helper'

@test "install.sh --help prints usage and exits 0" {
  run_install --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: install.sh"* ]]
  [[ "$output" == *"--vault"* ]]
  [[ "$output" == *"--no-auto-session"* ]]
  [[ "$output" == *"--target"* ]]
  [[ "$output" == *"--uninstall"* ]]
  [[ "$output" == *"--reset-config"* ]]
}

@test "install.sh with unknown flag exits non-zero with error" {
  run_install --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown"* || "$output" == *"--bogus"* ]]
}

# ---------------------------------------------------------------------------
# Vault path resolution tests (Task 10)
# ---------------------------------------------------------------------------

@test "install.sh --vault writes config with vault path" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  local cfg="$HOME/.claude/agentic-second-brain.json"
  assert_file_exists "$cfg"
  assert_json_eq "$cfg" '.vault' "$FIXTURE_VAULT"
}

@test "install.sh reads vault from AGENTIC_SECOND_BRAIN_VAULT env" {
  AGENTIC_SECOND_BRAIN_VAULT="$FIXTURE_VAULT" run_install --no-auto-session
  [ "$status" -eq 0 ]
  assert_json_eq "$HOME/.claude/agentic-second-brain.json" '.vault' "$FIXTURE_VAULT"
}

@test "install.sh config file has mode 600" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  local cfg="$HOME/.claude/agentic-second-brain.json"
  local mode
  mode=$(stat -f '%Lp' "$cfg" 2>/dev/null || stat -c '%a' "$cfg")
  [ "$mode" = "600" ]
}

@test "install.sh --reset-config removes existing config before writing" {
  # Pre-seed a config with a different vault.
  echo '{"vault":"/old/path"}' > "$HOME/.claude/agentic-second-brain.json"
  run_install --vault "$FIXTURE_VAULT" --reset-config --no-auto-session
  [ "$status" -eq 0 ]
  assert_json_eq "$HOME/.claude/agentic-second-brain.json" '.vault' "$FIXTURE_VAULT"
}

@test "install.sh exits non-zero when no vault provided and not interactive" {
  # No --vault, no env var, stdin is /dev/null so read prompt gets EOF.
  run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    bash "$REPO_ROOT/install.sh" --no-auto-session < /dev/null
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Vault CLAUDE.md bootstrap tests (Task 11)
# ---------------------------------------------------------------------------

@test "install.sh copies vault CLAUDE.md template when missing" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  assert_file_exists "$FIXTURE_VAULT/CLAUDE.md"
}

@test "install.sh does not overwrite existing vault CLAUDE.md" {
  echo "# My existing notes" > "$FIXTURE_VAULT/CLAUDE.md"
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  grep -q "My existing notes" "$FIXTURE_VAULT/CLAUDE.md"
}

@test "install.sh bootstrapped CLAUDE.md contains expected sections" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  grep -q "Project" "$FIXTURE_VAULT/CLAUDE.md"
}
