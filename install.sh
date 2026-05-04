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

echo "install.sh stub — not yet implemented"; exit 0
