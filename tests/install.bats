#!/usr/bin/env bats

load 'test_helper'

# ---------------------------------------------------------------------------
# Argument parsing (Task 9)
# ---------------------------------------------------------------------------

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
# Vault path resolution (Task 10)
# ---------------------------------------------------------------------------

@test "install.sh --vault flag writes config with that path" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  assert_file_exists "$XDG_CONFIG_HOME/agentic-second-brain/config.json"
  assert_json_eq "$XDG_CONFIG_HOME/agentic-second-brain/config.json" \
    ".vault_path" "$FIXTURE_VAULT"
  assert_json_eq "$XDG_CONFIG_HOME/agentic-second-brain/config.json" \
    ".version" "0.1.0"
}

@test "install.sh uses AGENTIC_SECOND_BRAIN_VAULT env var when no --vault flag" {
  AGENTIC_SECOND_BRAIN_VAULT="$FIXTURE_VAULT" run_install --no-auto-session
  [ "$status" -eq 0 ]
  assert_json_eq "$XDG_CONFIG_HOME/agentic-second-brain/config.json" \
    ".vault_path" "$FIXTURE_VAULT"
}

@test "install.sh prompts for vault path when neither flag nor env set" {
  run bash -c "echo '$FIXTURE_VAULT' | env HOME='$HOME' XDG_CONFIG_HOME='$XDG_CONFIG_HOME' bash '$REPO_ROOT/install.sh' --no-auto-session"
  [ "$status" -eq 0 ]
  assert_json_eq "$XDG_CONFIG_HOME/agentic-second-brain/config.json" \
    ".vault_path" "$FIXTURE_VAULT"
}

@test "install.sh fails when vault path does not exist" {
  run_install --vault "/no/such/dir" --no-auto-session
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a directory"* ]]
}

@test "install.sh config file has 600 permissions" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  local cfg="$XDG_CONFIG_HOME/agentic-second-brain/config.json"
  local mode
  mode=$(stat -f '%Lp' "$cfg" 2>/dev/null || stat -c '%a' "$cfg")
  [ "$mode" = "600" ]
}

# ---------------------------------------------------------------------------
# Vault CLAUDE.md bootstrap (Task 11)
# ---------------------------------------------------------------------------

@test "install.sh copies vault CLAUDE.md when missing and user accepts" {
  run bash -c "echo y | env HOME='$HOME' XDG_CONFIG_HOME='$XDG_CONFIG_HOME' bash '$REPO_ROOT/install.sh' --vault '$FIXTURE_VAULT' --no-auto-session"
  [ "$status" -eq 0 ]
  assert_file_exists "$FIXTURE_VAULT/CLAUDE.md"
  head -1 "$FIXTURE_VAULT/CLAUDE.md" | grep -q "^# CLAUDE.md$"
}

@test "install.sh leaves existing vault CLAUDE.md untouched" {
  echo "# Custom Vault Notes" > "$FIXTURE_VAULT/CLAUDE.md"
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  [ "$(head -1 "$FIXTURE_VAULT/CLAUDE.md")" = "# Custom Vault Notes" ]
}

@test "install.sh skips bootstrap when user declines" {
  run bash -c "echo n | env HOME='$HOME' XDG_CONFIG_HOME='$XDG_CONFIG_HOME' bash '$REPO_ROOT/install.sh' --vault '$FIXTURE_VAULT' --no-auto-session 2>&1"
  [ "$status" -eq 0 ]
  [ ! -f "$FIXTURE_VAULT/CLAUDE.md" ]
  [[ "$output" == *"skipping vault CLAUDE.md bootstrap"* ]]
}

# ---------------------------------------------------------------------------
# Symlink skill and command files (Task 12)
# ---------------------------------------------------------------------------

@test "install.sh symlinks skill dir into ~/.claude/skills" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  local link="$HOME/.claude/skills/agentic-second-brain"
  local target
  target="$(cd "$REPO_ROOT" && pwd)/skills/agentic-second-brain"
  assert_symlink_to "$link" "$target"
}

@test "install.sh symlinks both slash command files under namespaced dir" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  local repo_abs
  repo_abs="$(cd "$REPO_ROOT" && pwd)"
  assert_symlink_to "$HOME/.claude/commands/agentic-second-brain/get-knowledge.md" \
    "$repo_abs/commands/get-knowledge.md"
  assert_symlink_to "$HOME/.claude/commands/agentic-second-brain/save-memory.md" \
    "$repo_abs/commands/save-memory.md"
}

@test "install.sh re-running is idempotent for symlinks" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  local link="$HOME/.claude/skills/agentic-second-brain"
  local target
  target="$(cd "$REPO_ROOT" && pwd)/skills/agentic-second-brain"
  assert_symlink_to "$link" "$target"
}

@test "install.sh fails fast for unsupported target" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session --target cursor
  [ "$status" -ne 0 ]
  [[ "$output" == *"not yet supported"* ]]
}

# ---------------------------------------------------------------------------
# SessionEnd hook injection (Task 13)
# ---------------------------------------------------------------------------

@test "install.sh injects SessionEnd hook into settings.json" {
  run_install --vault "$FIXTURE_VAULT"
  [ "$status" -eq 0 ]
  assert_file_exists "$HOME/.claude/settings.json"
  local hook_count
  hook_count=$(jq '[(.hooks.SessionEnd // [])[] | (.hooks // [])[] | .command | select(contains("session-end-save"))] | length' \
    "$HOME/.claude/settings.json")
  [ "$hook_count" = "1" ]
}

@test "install.sh hook injection is idempotent (no duplicates on re-run)" {
  run_install --vault "$FIXTURE_VAULT"
  run_install --vault "$FIXTURE_VAULT"
  [ "$status" -eq 0 ]
  local hook_count
  hook_count=$(jq '[(.hooks.SessionEnd // [])[] | (.hooks // [])[] | .command | select(contains("session-end-save"))] | length' \
    "$HOME/.claude/settings.json")
  [ "$hook_count" = "1" ]
}

@test "install.sh --no-auto-session does NOT inject hook" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  if [ -f "$HOME/.claude/settings.json" ]; then
    local hook_count
    hook_count=$(jq '[(.hooks.SessionEnd // [])[] | (.hooks // [])[] | .command | select(contains("session-end-save"))] | length' \
      "$HOME/.claude/settings.json")
    [ "$hook_count" = "0" ]
  fi
}

@test "install.sh preserves existing settings.json content during merge" {
  cat > "$HOME/.claude/settings.json" <<'EOF'
{ "theme": "dark", "hooks": { "SessionStart": [{"matcher": "*", "command": "other.md"}] } }
EOF
  run_install --vault "$FIXTURE_VAULT"
  [ "$status" -eq 0 ]
  assert_json_eq "$HOME/.claude/settings.json" ".theme" "dark"
  assert_json_eq "$HOME/.claude/settings.json" \
    '.hooks.SessionStart[0].command' "other.md"
}

# ---------------------------------------------------------------------------
# Uninstall path (Task 14)
# ---------------------------------------------------------------------------

@test "install.sh --uninstall removes symlinks but preserves config" {
  run_install --vault "$FIXTURE_VAULT"
  [ "$status" -eq 0 ]
  run_install --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.claude/skills/agentic-second-brain" ]
  [ ! -e "$HOME/.claude/commands/agentic-second-brain" ]
  assert_file_exists "$XDG_CONFIG_HOME/agentic-second-brain/config.json"
}

@test "install.sh --uninstall removes hook entry from settings.json" {
  run_install --vault "$FIXTURE_VAULT"
  run_install --uninstall
  [ "$status" -eq 0 ]
  if [ -f "$HOME/.claude/settings.json" ]; then
    local hook_count
    hook_count=$(jq '[(.hooks.SessionEnd // [])[] | (.hooks // [])[] | .command | select(contains("session-end-save"))] | length' \
      "$HOME/.claude/settings.json")
    [ "$hook_count" = "0" ]
  fi
}

@test "install.sh --uninstall preserves vault contents" {
  echo "y" | run_install --vault "$FIXTURE_VAULT"
  run_install --uninstall
  [ "$status" -eq 0 ]
  assert_file_exists "$FIXTURE_VAULT/CLAUDE.md"
}

@test "install.sh --uninstall is safe when nothing installed" {
  run_install --uninstall
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# jq missing error path (Task 15)
# ---------------------------------------------------------------------------

@test "install.sh errors loud when jq is missing" {
  local jqshim="$TEST_TMP/nojq"
  mkdir -p "$jqshim"
  run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    PATH="$jqshim:/bin:/usr/local/bin" \
    bash "$REPO_ROOT/install.sh" --vault "$FIXTURE_VAULT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"jq is required"* ]]
}
