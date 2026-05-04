#!/usr/bin/env bash
# install.sh — agentic-second-brain installer.
set -euo pipefail

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --vault <path>          Path to your Obsidian vault (overrides env / config)
  --no-auto-session       Skip SessionEnd hook injection
  --target <agent>        Agent target: claude-code (default). cursor / opencode / codex / all are reserved.
  --uninstall             Remove symlinks and hook entry; preserve config + vault
  --reset-config          Overwrite existing config.json
  --help                  Show this help and exit
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
VAULT_PATH=""
NO_AUTO_SESSION=0
TARGET="claude-code"
UNINSTALL=0
RESET_CONFIG=0

while [ $# -gt 0 ]; do
  case "$1" in
    --vault)            VAULT_PATH="${2:?--vault requires a path}"; shift 2 ;;
    --no-auto-session)  NO_AUTO_SESSION=1; shift ;;
    --target)           TARGET="${2:?--target requires a value}"; shift 2 ;;
    --uninstall)        UNINSTALL=1; shift ;;
    --reset-config)     RESET_CONFIG=1; shift ;;
    --help|-h)          usage; exit 0 ;;
    *) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# Core paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/agentic-second-brain"
config_file="$config_dir/config.json"
claude_root="$HOME/.claude"
skills_dir="$claude_root/skills"
commands_dir="$claude_root/commands/agentic-second-brain"
settings_file="$claude_root/settings.json"
hook_command_path="$SCRIPT_DIR/hooks/session-end-save.md"

# ---------------------------------------------------------------------------
# Uninstall — short-circuit before anything else
# ---------------------------------------------------------------------------
if [ "$UNINSTALL" -eq 1 ]; then
  rm -f "$skills_dir/agentic-second-brain"
  rm -rf "$commands_dir"
  if [ -f "$settings_file" ] && command -v jq >/dev/null 2>&1; then
    _uninstall_tmp="$(mktemp)"
    jq --arg cmd "$hook_command_path" '
      if .hooks.SessionEnd then
        .hooks.SessionEnd |= map(select(.command != $cmd and ((.hooks // []) | map(.command) | index($cmd) | not)))
      else . end
    ' "$settings_file" > "$_uninstall_tmp" && mv "$_uninstall_tmp" "$settings_file"
  fi
  echo "uninstalled. config preserved at $config_file" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Target gate
# ---------------------------------------------------------------------------
case "$TARGET" in
  claude-code) ;;
  cursor|opencode|codex|all)
    echo "error: target \"$TARGET\" not yet supported in v1" >&2
    exit 3
    ;;
  *)
    echo "error: unknown target \"$TARGET\"" >&2
    exit 3
    ;;
esac

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------
require_jq() {
  command -v jq >/dev/null 2>&1 || {
    echo "error: jq is required. Install jq:" >&2
    echo "  macOS:  brew install jq" >&2
    echo "  Debian: sudo apt-get install jq" >&2
    exit 4
  }
}

require_jq

# ---------------------------------------------------------------------------
# Vault path resolution
# ---------------------------------------------------------------------------
resolve_vault_path() {
  if [ -n "$VAULT_PATH" ]; then
    return
  fi
  if [ -n "${AGENTIC_SECOND_BRAIN_VAULT:-}" ]; then
    VAULT_PATH="$AGENTIC_SECOND_BRAIN_VAULT"
    return
  fi
  if [ -t 0 ]; then
    printf "Path to your Obsidian vault: " >&2
  fi
  read -r VAULT_PATH || true
}

resolve_vault_path

if [ -z "$VAULT_PATH" ]; then
  echo "error: vault path required. Use --vault PATH or set AGENTIC_SECOND_BRAIN_VAULT." >&2
  exit 1
fi
if [ ! -d "$VAULT_PATH" ]; then
  echo "error: vault path \"$VAULT_PATH\" is not a directory" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Write config
# ---------------------------------------------------------------------------
write_config() {
  mkdir -p "$config_dir"
  if [ -f "$config_file" ] && [ "$RESET_CONFIG" -eq 0 ]; then
    local current
    current=$(jq -r '.vault_path // empty' "$config_file" 2>/dev/null || echo "")
    if [ "$current" = "$VAULT_PATH" ]; then
      chmod 600 "$config_file"
      return
    fi
  fi
  jq -n --arg vault "$VAULT_PATH" --arg version "0.1.0" \
    '{vault_path: $vault, version: $version}' > "$config_file"
  chmod 600 "$config_file"
}

write_config

# ---------------------------------------------------------------------------
# Bootstrap vault CLAUDE.md
# ---------------------------------------------------------------------------
bootstrap_vault_claude_md() {
  local target="$VAULT_PATH/CLAUDE.md"
  local template="$SCRIPT_DIR/templates/vault-CLAUDE.md"
  if [ -f "$target" ]; then
    return
  fi
  local reply=""
  if [ -t 0 ]; then
    printf "Vault has no CLAUDE.md. Copy starter template? [y/N] " >&2
  fi
  read -r reply || true
  case "$reply" in
    y|Y|yes|YES)
      cp "$template" "$target"
      echo "wrote: $target" >&2
      ;;
    *)
      echo "skipping vault CLAUDE.md bootstrap" >&2
      ;;
  esac
}

bootstrap_vault_claude_md

# ---------------------------------------------------------------------------
# Symlink skill and command files into ~/.claude
# ---------------------------------------------------------------------------
install_symlinks() {
  mkdir -p "$skills_dir" "$commands_dir"
  ln -sfn "$SCRIPT_DIR/skills/agentic-second-brain" "$skills_dir/agentic-second-brain"
  ln -sfn "$SCRIPT_DIR/commands/get-knowledge.md" "$commands_dir/get-knowledge.md"
  ln -sfn "$SCRIPT_DIR/commands/save-memory.md"   "$commands_dir/save-memory.md"
}

install_symlinks

# ---------------------------------------------------------------------------
# SessionEnd hook injection (uses Claude Code's nested hook schema)
# ---------------------------------------------------------------------------
inject_session_end_hook() {
  if [ "$NO_AUTO_SESSION" -eq 1 ]; then
    return
  fi
  if [ ! -f "$settings_file" ]; then
    echo '{}' > "$settings_file"
  fi
  local already
  already=$(jq --arg cmd "$hook_command_path" \
    '[(.hooks.SessionEnd // []) | .[] | (.hooks // []) | .[] | .command] | map(select(. == $cmd)) | length' \
    "$settings_file")
  if [ "$already" -gt 0 ]; then
    return
  fi
  local entry
  entry=$(jq -n --arg cmd "$hook_command_path" \
    '{matcher: "*", hooks: [{type: "command", command: $cmd}]}')
  local tmp
  tmp=$(mktemp)
  jq --argjson e "$entry" \
    '.hooks //= {} | .hooks.SessionEnd = ((.hooks.SessionEnd // []) + [$e])' \
    "$settings_file" > "$tmp"
  mv "$tmp" "$settings_file"
}

inject_session_end_hook

exit 0
