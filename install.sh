#!/usr/bin/env bash
# install.sh — agentic-second-brain installer
set -euo pipefail

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: install.sh [OPTIONS]

Install the agentic-second-brain plugin into ~/.claude.

Options:
  --vault PATH        Path to your Obsidian vault (or set AGENTIC_SECOND_BRAIN_VAULT)
  --no-auto-session   Skip injecting the SessionEnd hook into Claude settings
  --target DIR        Override the target ~/.claude directory (default: ~/.claude)
  --uninstall         Remove all installed symlinks and hooks
  --reset-config      Delete ~/.claude/agentic-second-brain.json before installing
  -h, --help          Show this help message and exit
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
VAULT_FLAG=""
NO_AUTO_SESSION=false
TARGET_DIR="${HOME}/.claude"
UNINSTALL=false
RESET_CONFIG=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)
      VAULT_FLAG="$2"
      shift 2
      ;;
    --no-auto-session)
      NO_AUTO_SESSION=true
      shift
      ;;
    --target)
      TARGET_DIR="$2"
      shift 2
      ;;
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    --reset-config)
      RESET_CONFIG=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown flag: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Core paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_root="${TARGET_DIR}"
config_file="${claude_root}/agentic-second-brain.json"

# ---------------------------------------------------------------------------
# Vault resolution
# ---------------------------------------------------------------------------
resolve_vault() {
  # Priority: flag > env var > existing config > interactive prompt
  local vault=""

  if [[ -n "${VAULT_FLAG:-}" ]]; then
    vault="$VAULT_FLAG"
  elif [[ -n "${AGENTIC_SECOND_BRAIN_VAULT:-}" ]]; then
    vault="$AGENTIC_SECOND_BRAIN_VAULT"
  elif [[ -f "$config_file" ]]; then
    vault="$(jq -r '.vault // empty' "$config_file" 2>/dev/null || true)"
  fi

  if [[ -z "$vault" ]]; then
    # Interactive prompt — will EOF/fail in non-tty environments
    if [[ -t 0 ]]; then
      read -r -p "Enter path to your Obsidian vault: " vault
    fi
  fi

  if [[ -z "$vault" ]]; then
    echo "Error: vault path is required. Use --vault PATH or set AGENTIC_SECOND_BRAIN_VAULT." >&2
    exit 1
  fi

  echo "$vault"
}

# ---------------------------------------------------------------------------
# Write config
# ---------------------------------------------------------------------------
write_config() {
  local vault="$1"

  if [[ "$RESET_CONFIG" == true && -f "$config_file" ]]; then
    rm -f "$config_file"
  fi

  mkdir -p "$claude_root"
  printf '{\n  "vault": "%s"\n}\n' "$vault" > "$config_file"
  chmod 600 "$config_file"
}

# ---------------------------------------------------------------------------
# Bootstrap vault CLAUDE.md
# ---------------------------------------------------------------------------
bootstrap_vault_claude_md() {
  local vault="$1"
  local dest="${vault}/CLAUDE.md"
  local template="${SCRIPT_DIR}/templates/vault-CLAUDE.md"

  if [[ -f "$dest" ]]; then
    return 0
  fi

  if [[ -f "$template" ]]; then
    cp "$template" "$dest"
  else
    echo "Warning: template not found at $template — skipping CLAUDE.md bootstrap." >&2
  fi
}

# ---------------------------------------------------------------------------
# Symlink skill and command files into ~/.claude
# ---------------------------------------------------------------------------
install_symlinks() {
  # skill directory
  local skills_dir="${claude_root}/skills/agentic-second-brain"
  local skill_src="${SCRIPT_DIR}/skills/agentic-second-brain/SKILL.md"
  if [[ -f "$skill_src" ]]; then
    mkdir -p "$skills_dir"
    ln -sf "$skill_src" "${skills_dir}/SKILL.md"
  fi

  # command files
  local commands_dir="${claude_root}/commands"
  mkdir -p "$commands_dir"
  for cmd_src in "${SCRIPT_DIR}/commands/"*.md; do
    [[ -f "$cmd_src" ]] || continue
    local cmd_name
    cmd_name="$(basename "$cmd_src")"
    ln -sf "$cmd_src" "${commands_dir}/${cmd_name}"
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
VAULT="$(resolve_vault)"
write_config "$VAULT"
bootstrap_vault_claude_md "$VAULT"
install_symlinks

exit 0
