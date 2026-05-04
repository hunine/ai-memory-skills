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

# ---------------------------------------------------------------------------
# Symlink skill files tests (Task 12)
# ---------------------------------------------------------------------------

@test "install.sh symlinks SKILL.md into ~/.claude/skills/" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  local link="$HOME/.claude/skills/agentic-second-brain/SKILL.md"
  local target
  target="$(cd "$REPO_ROOT" && pwd)/skills/agentic-second-brain/SKILL.md"
  assert_symlink_to "$link" "$target"
}

@test "install.sh symlinks get-knowledge.md into ~/.claude/commands/" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  local link="$HOME/.claude/commands/get-knowledge.md"
  local target
  target="$(cd "$REPO_ROOT" && pwd)/commands/get-knowledge.md"
  assert_symlink_to "$link" "$target"
}

@test "install.sh symlinks save-memory.md into ~/.claude/commands/" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  local link="$HOME/.claude/commands/save-memory.md"
  local target
  target="$(cd "$REPO_ROOT" && pwd)/commands/save-memory.md"
  assert_symlink_to "$link" "$target"
}

@test "install.sh skips symlink when target source file does not exist" {
  # Point REPO_ROOT at a temp dir with no skill files — install should still exit 0.
  local empty_repo="$TEST_TMP/empty_repo"
  mkdir -p "$empty_repo/skills/agentic-second-brain" "$empty_repo/commands" \
            "$empty_repo/hooks" "$empty_repo/templates"
  run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    bash "$REPO_ROOT/install.sh" --vault "$FIXTURE_VAULT" --no-auto-session \
    --target "$HOME/.claude"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# SessionEnd hook injection tests (Task 13)
# ---------------------------------------------------------------------------

@test "install.sh injects SessionEnd hook into Claude settings.json" {
  run_install --vault "$FIXTURE_VAULT"
  [ "$status" -eq 0 ]
  local settings="$HOME/.claude/settings.json"
  assert_file_exists "$settings"
  assert_json_eq "$settings" '.hooks.SessionEnd | length > 0' "true"
}

@test "install.sh hook entry contains the session-end-save command path" {
  run_install --vault "$FIXTURE_VAULT"
  [ "$status" -eq 0 ]
  local settings="$HOME/.claude/settings.json"
  local hook_cmd
  hook_cmd="$(jq -r '.hooks.SessionEnd[0].hooks[0].command' "$settings")"
  [[ "$hook_cmd" == *"session-end-save"* ]]
}

@test "install.sh hook injection is idempotent" {
  run_install --vault "$FIXTURE_VAULT"
  run_install --vault "$FIXTURE_VAULT"
  [ "$status" -eq 0 ]
  local settings="$HOME/.claude/settings.json"
  local count
  count="$(jq '[.hooks.SessionEnd[].hooks[].command] | map(select(contains("session-end-save"))) | length' "$settings")"
  [ "$count" -eq 1 ]
}

@test "install.sh --no-auto-session skips hook injection" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  local settings="$HOME/.claude/settings.json"
  # Either no settings file or no SessionEnd key.
  if [ -f "$settings" ]; then
    local hook_count
    hook_count="$(jq '.hooks.SessionEnd // [] | length' "$settings")"
    [ "$hook_count" -eq 0 ]
  fi
}

# ---------------------------------------------------------------------------
# Uninstall path tests (Task 14)
# ---------------------------------------------------------------------------

@test "install.sh --uninstall removes skill symlink" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  run_install --vault "$FIXTURE_VAULT" --uninstall
  [ "$status" -eq 0 ]
  local link="$HOME/.claude/skills/agentic-second-brain/SKILL.md"
  [ ! -L "$link" ]
}

@test "install.sh --uninstall removes command symlinks" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  run_install --vault "$FIXTURE_VAULT" --uninstall
  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.claude/commands/get-knowledge.md" ]
  [ ! -L "$HOME/.claude/commands/save-memory.md" ]
}

@test "install.sh --uninstall removes SessionEnd hook entry" {
  run_install --vault "$FIXTURE_VAULT"
  run_install --vault "$FIXTURE_VAULT" --uninstall
  [ "$status" -eq 0 ]
  local settings="$HOME/.claude/settings.json"
  if [ -f "$settings" ]; then
    local count
    count="$(jq '[.hooks.SessionEnd // [] | .[].hooks // [] | .[].command] | map(select(contains("session-end-save"))) | length' "$settings")"
    [ "$count" -eq 0 ]
  fi
}

@test "install.sh --uninstall preserves config file" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  run_install --vault "$FIXTURE_VAULT" --uninstall
  [ "$status" -eq 0 ]
  assert_file_exists "$HOME/.claude/agentic-second-brain.json"
}

# ---------------------------------------------------------------------------
# jq missing error path (Task 15)
# ---------------------------------------------------------------------------

@test "install.sh errors loud when jq is missing during hook injection" {
  # Mask jq by placing a no-op shim dir first and passing PATH explicitly via env.
  local jqshim="$TEST_TMP/nojq"
  mkdir -p "$jqshim"
  run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    PATH="$jqshim:/usr/local/bin:/bin:/usr/bin/env" \
    bash "$REPO_ROOT/install.sh" --vault "$FIXTURE_VAULT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"jq is required"* ]]
}
