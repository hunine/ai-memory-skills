# Agentic Second Brain — v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the v1 Claude Code plugin "agentic-second-brain" that lets AI agents read project context from a user's Obsidian vault and write structured notes back (inbox, session logs, decisions).

**Architecture:** Pure markdown skill + slash commands + SessionEnd hook delegate to a single `SKILL.md` body. Distribution via `.claude-plugin/plugin.json` (native install) and `install.sh` (manual / future ports). Vault path resolved at runtime via env var → `~/.config/agentic-second-brain/config.json`. Vault's own `CLAUDE.md` is the schema source of truth, re-read every call. install.sh is the only executable code surface; tested with `bats`.

**Tech Stack:** Bash 4+, `jq` for JSON merging, `bats-core` for shell testing. No runtime dependencies for the skill itself — uses Claude Code's built-in Read/Write/Glob/Grep tools.

---

## File Map

**Created:**
- `.claude-plugin/plugin.json` — plugin manifest (skills, commands, hooks)
- `skills/agentic-second-brain/SKILL.md` — skill body, sole source of operational logic
- `commands/get-knowledge.md` — slash command delegate
- `commands/save-memory.md` — slash command delegate
- `hooks/session-end-save.md` — SessionEnd hook body
- `templates/vault-CLAUDE.md` — starter vault `CLAUDE.md` for bootstrap
- `install.sh` — non-plugin install / uninstall
- `tests/install.bats` — install.sh test suite
- `tests/test_helper.bash` — bats test helpers (temp HOME, fixture vault setup)
- `tests/SMOKE.md` — manual smoke checklist for skill behavior
- `tests/fixtures/vault/CLAUDE.md` — fixture vault config
- `tests/fixtures/vault/Projects/praio/index.md` — fixture project with wiki-links
- `tests/fixtures/vault/Projects/Praio-Mobile/index.md` — second project for case-insensitive match test
- `tests/fixtures/vault/Inbox/.gitkeep` — empty inbox dir
- `tests/fixtures/vault/AI/session/.gitkeep` — empty session dir
- `tests/fixtures/vault/Templates/.gitkeep` — empty templates dir
- `README.md` — install + usage docs
- `.gitignore` — bats test artifacts, OS junk

**Not modified:**
- `CLAUDE.md` — stays as-is (committed in spec phase)

Each file has one responsibility:
- `SKILL.md` owns logic — commands and hook bodies are thin delegates.
- `install.sh` is split internally into shell functions (one per concern: parse args, resolve vault, write config, bootstrap, symlink, hook-inject) — tested per function.

---

## Task 1: Scaffold Directories and `.gitignore`

**Files:**
- Create: `.gitignore`
- Create: `.claude-plugin/`, `skills/agentic-second-brain/`, `commands/`, `hooks/`, `templates/`, `tests/fixtures/vault/Projects/`, `tests/fixtures/vault/Inbox/`, `tests/fixtures/vault/AI/session/`, `tests/fixtures/vault/Templates/`

- [ ] **Step 1: Create directory tree**

```bash
mkdir -p .claude-plugin skills/agentic-second-brain commands hooks templates \
  tests/fixtures/vault/Projects/praio \
  tests/fixtures/vault/Projects/Praio-Mobile \
  tests/fixtures/vault/Inbox \
  tests/fixtures/vault/AI/session \
  tests/fixtures/vault/Templates
```

- [ ] **Step 2: Add `.gitkeep` to empty dirs that must persist**

```bash
touch tests/fixtures/vault/Inbox/.gitkeep \
      tests/fixtures/vault/AI/session/.gitkeep \
      tests/fixtures/vault/Templates/.gitkeep
```

- [ ] **Step 3: Create `.gitignore`**

```
# bats test artifacts
tests/tmp/
*.bats.log

# OS junk
.DS_Store
Thumbs.db

# Editor
*.swp
.vscode/
.idea/
```

- [ ] **Step 4: Commit**

```bash
git add .gitignore tests/fixtures/vault/
git commit -m "chore(scaffold): create plugin directory tree and gitignore"
```

---

## Task 2: Write Vault CLAUDE.md Template

**Files:**
- Create: `templates/vault-CLAUDE.md`

This is the starter copied into a vault that has no `CLAUDE.md`. Content matches the schema the skill expects (frontmatter format, tags `#needs-review`/`#decision`/`#action`, commit scopes, session protocol, Agent Output Format).

- [ ] **Step 1: Write `templates/vault-CLAUDE.md`**

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About This Vault

This is a personal knowledge management system (second brain) built in Obsidian. The owner is a software engineer managing multiple active projects simultaneously. The primary use cases are: synthesizing research, drafting documents, tracking decisions, and querying project context.

## Vault Structure

| Folder       | Purpose                                                     |
| ------------ | ----------------------------------------------------------- |
| `/Inbox`     | Raw captures, quick notes, unprocessed material             |
| `/Projects`  | Active project folders — one subfolder per project          |
| `/Archive`   | Completed projects, old notes no longer actively referenced |
| `/AI`        | Agent outputs, session logs, summaries                      |
| `/Templates` | Reusable note templates                                     |

Daily notes live at `/Inbox/YYYY-MM-DD.md`.
Session logs live at `/AI/session/YYYY-MM-DD-HH.md` (24-hour hour).

## Session Protocol

### Session Start
1. Read today's daily note at `/Inbox/YYYY-MM-DD.md` (create from template if missing).
2. Scan `/Inbox` for unprocessed notes — files without `processed: true` or destination folder.
3. Check for any notes tagged `#needs-review` across the vault.

### Session End
1. Write a session summary to `/AI/session/YYYY-MM-DD-HH.md`.
2. Append an "Agent Log" section to today's daily note summarizing what was done.

## Note Conventions

**Frontmatter (YAML, supported by Properties core plugin):**

```yaml
---
title:
date: YYYY-MM-DD
tags: []
status: draft | active | archived
project:        # links to /Projects/<name>
processed: false
related:
  - "[[Meeting Notes - Jan 10]]"
  - "[[Project Brief]]"
---
```

**Tags with special meaning:**
- `#needs-review` — flags a note for human review
- `#decision` — records a project decision (context, options, outcome)
- `#action` — a task or follow-up

**Linking:** use `[[Note Title]]` wiki-links. Prefer linking to project index notes (`/Projects/<name>/index.md`) rather than deeply nested files.

## Working with Projects

Each active project lives under `/Projects/<project-name>/`:

- `index.md` — overview, status, links to key decisions and resources
- `decisions/` — one file per major decision, tagged `#decision`
- `research/` — synthesized notes (raw captures go to `/Inbox` first)

## Commit Message Format

```
memo(<scope>): <short imperative summary>

<what was captured and why it matters>
```

| Scope | When to use |
|---|---|
| `vault` | Vault-wide config, CLAUDE.md, templates |
| `project/<name>` | Changes scoped to a specific project folder |
| `inbox` | Processing or adding raw captures |
| `session` | AI session logs |
| `decision` | Recording a project decision |

## Agent Output Format

When writing to `/AI/session/YYYY-MM-DD-HH.md`:

```markdown
---
date: YYYY-MM-DD
hour: HH
tags: [ai-session]
---

## Session Summary
<!-- 2-3 sentence overview -->

## Actions Taken
-

## Notes Processed
-

## Open Items
-
```
```

- [ ] **Step 2: Commit**

```bash
git add templates/vault-CLAUDE.md
git commit -m "memo(vault): add starter vault CLAUDE.md template for bootstrap"
```

---

## Task 3: Write `SKILL.md` — Skill Body

**Files:**
- Create: `skills/agentic-second-brain/SKILL.md`

This is the single source of truth for skill logic. Slash commands and hook body delegate here.

- [ ] **Step 1: Write `skills/agentic-second-brain/SKILL.md`**

```markdown
---
name: agentic-second-brain
description: Use when the user asks to load project context from their Obsidian vault, save a session log, capture an inbox note, record a project decision, or any phrase like "load X project", "save session", "log decision", "save to inbox", "what's in my vault for X". Reads structured project knowledge from a configured vault and writes back per the vault's own CLAUDE.md schema.
---

# Agentic Second Brain

Bridges an AI agent to a user's Obsidian vault. Two operations: `get-knowledge` (load project context) and `save-memory` (write back inbox / session / decision notes).

## Boot Sequence — Run Every Invocation

1. **Resolve vault path** in this order:
   1. If env var `AGENTIC_SECOND_BRAIN_VAULT` is set and points at a directory → use it.
   2. Else read `~/.config/agentic-second-brain/config.json`. Use the `vault_path` key.
   3. Else error loud: "Vault not configured. Run `install.sh` from the agentic-second-brain repo or set `AGENTIC_SECOND_BRAIN_VAULT`." Stop.
2. **Verify vault dir exists.** If not → loud error: "Vault path `<path>` is not a directory." Stop.
3. **Read `<vault>/CLAUDE.md`.**
   - Missing → ask user: "Vault has no CLAUDE.md. Copy starter template from the plugin? [y/N]". On `y`, copy `templates/vault-CLAUDE.md` from the plugin install dir into vault root. On `N` → refuse to proceed, stop.
   - Present → read full content into context. This is the authoritative schema for note format, tags, scopes, session protocol. Re-read every invocation; do not cache across calls.
4. **Path traversal guard:** before any write, resolve target via `realpath`. Refuse if it does not start with `realpath` of vault root. No writes outside the vault.

## Operation: `get-knowledge <project>`

Two-phase read.

### Phase 1 — Initial Call: Load Active Surface

1. Glob `<vault>/Projects/*` directories. Match `<project>` against directory names case-insensitively (lowercase both sides, exact match).
2. **No match** → list available projects (case-folded), stop.
3. **Multiple matches** → impossible (filesystem prevents duplicate dirs differing only in case on macOS APFS default; on case-sensitive filesystems, list candidates and stop).
4. **Match** → load in this exact order:
   - `<vault>/Projects/<match>/index.md` — the menu. Always read.
   - Parse all wiki-links `[[...]]` from `index.md`. Build a navigation map (link target → resolved file path candidates) and hold in working context.
   - `<vault>/Inbox/<today>.md` — today's daily note (`YYYY-MM-DD.md` in local time). Read if exists.
   - Notes tagged `#needs-review` referencing this project. Use Grep to find files containing `#needs-review`, filter to those whose YAML frontmatter `project:` field equals `<match>` or whose body wiki-links the project.
   - Open `#action` items (same filter as above with `#action` tag).
   - Last 2 files in `<vault>/AI/session/` whose filename or body mentions `<match>`. Sort by filename descending.
   - List filenames only (Glob, not Read) of `<vault>/Projects/<match>/decisions/` and `<vault>/Projects/<match>/research/`.
5. Return a structured summary to the user:
   - Project status (from index.md).
   - Open `#action` items.
   - Pending `#needs-review` notes.
   - Last-session continuity (1-line per recent session).
   - Note that `decisions/` and `research/` filenames are listed for follow-up.

### Phase 2 — Follow-Up Navigation

When the user asks about a specific business area in the same conversation:

1. Look up the topic in the navigation map built in Phase 1. Match wiki-link target text case-insensitively.
2. **Match** → resolve to file path:
   - First check `<vault>/Projects/<match>/**/<link-target>.md` (Glob).
   - Then check vault-wide if not found.
   - Honor Obsidian shortest-path resolution. If multiple results, pick the shortest path; warn user of ambiguity.
3. Read that file. If it has outbound wiki-links and the user pushes deeper, follow them recursively. Otherwise, stop reading.
4. **No match in nav map** → fall back to vault-wide Glob. Warn the user that `index.md` does not link this topic — they should update the index for next time.

**Do not re-glob the project on every follow-up.** The Phase 1 navigation map is the directory; rely on it.

## Operation: `save-memory <kind> [args]`

| Kind | Target file | Behavior |
| --- | --- | --- |
| `inbox <text>` | `<vault>/Inbox/<YYYY-MM-DD>.md` (today, local time) | Append `<text>` with a timestamped subheading. Create file from vault CLAUDE.md frontmatter template if missing. |
| `session` | `<vault>/AI/session/<YYYY-MM-DD-HH>.md` (current local hour, 24-hour) | Write using the "Agent Output Format" structure from vault CLAUDE.md. If file exists for this hour, append a `## Continued` section — never overwrite. |
| `decision <project> <slug>` | `<vault>/Projects/<project>/decisions/<slug>.md` | Write with `#decision` tag and full frontmatter (title, date, tags, status, project, processed, related). Refuse to overwrite an existing slug — suggest `<slug>-2`. |

**Idempotency rules:**
- Always Read before Write. Never blind-overwrite.
- Daily note + session log: append-only.
- Decision file: refuse to overwrite, propose new slug.

**Frontmatter source:** read the YAML schema from `<vault>/CLAUDE.md` "Note Conventions" section. Do not hard-code field names — use what the vault declares.

## Failure Modes (loud, no silent fallbacks)

| Condition | Action |
| --- | --- |
| Vault path missing / unset | Loud error with fix command. Stop. |
| Vault dir does not exist | Loud error: "Vault path X is not a directory." Stop. |
| Vault `CLAUDE.md` missing | Offer bootstrap. Refuse to proceed if declined. |
| `/Projects/<name>/` not found | Loud error, list available projects (case-folded). Stop. |
| `/Projects/<name>/index.md` missing | Warn, fall back to Glob-listing project files. Continue. |
| Wiki-link resolves to multiple files | Pick shortest path, warn user. |
| Wiki-link unresolvable | Skip, note in summary. Don't error the whole call. |
| Decision slug exists | Refuse, suggest `<slug>-2`. |
| Session-hour file exists | Append `## Continued` section. Never overwrite. |
| Path traversal attempt | Refuse hard, log to user. |

## What This Skill Does Not Do

- Does not execute vault contents (Read/Write/Glob/Grep only — no shell-out, no `eval`).
- Does not make network calls.
- Does not cache vault `CLAUDE.md` across calls — re-reads each invocation.
- Does not write outside the vault root.
- Does not auto-process inbox notes — that is the user's job.
```

- [ ] **Step 2: Commit**

```bash
git add skills/agentic-second-brain/SKILL.md
git commit -m "memo(vault): add agentic-second-brain SKILL.md body with get-knowledge and save-memory flows"
```

---

## Task 4: Write `commands/get-knowledge.md`

**Files:**
- Create: `commands/get-knowledge.md`

Thin slash-command delegate. Logic stays in SKILL.md.

- [ ] **Step 1: Write `commands/get-knowledge.md`**

```markdown
---
description: Load Obsidian vault context for a project (index, daily note, needs-review, recent sessions)
argument-hint: <project-folder-name>
---

Invoke the `agentic-second-brain` skill: `get-knowledge` for project "$ARGUMENTS".

Follow the skill's `get-knowledge` flow exactly:

1. Run the boot sequence (resolve vault path, read vault CLAUDE.md).
2. Match `$ARGUMENTS` case-insensitively against `<vault>/Projects/*` directory names.
3. On no match, list available projects and stop.
4. On match, run Phase 1 — load `index.md`, parse wiki-links into a nav map, pull active surface (today's daily, `#needs-review`, open `#action`, last 2 sessions, list decisions/research filenames).
5. Return a structured summary. Do not deep-read decisions or research files yet — wait for follow-up questions and use the nav map.
```

- [ ] **Step 2: Commit**

```bash
git add commands/get-knowledge.md
git commit -m "memo(vault): add /agentic-second-brain:get-knowledge slash command"
```

---

## Task 5: Write `commands/save-memory.md`

**Files:**
- Create: `commands/save-memory.md`

- [ ] **Step 1: Write `commands/save-memory.md`**

```markdown
---
description: Write to Obsidian vault — inbox append, session log, or decision record
argument-hint: <kind: inbox|session|decision> [args]
---

Invoke the `agentic-second-brain` skill: `save-memory` with arguments "$ARGUMENTS".

Parse `$ARGUMENTS` as `<kind> [args]`:

- `inbox <text>` → append `<text>` to `<vault>/Inbox/<today>.md` (create from vault CLAUDE.md template if missing).
- `session` → write `<vault>/AI/session/<YYYY-MM-DD-HH>.md` using the Agent Output Format from vault CLAUDE.md. If file exists for this hour, append `## Continued`.
- `decision <project> <slug>` → write `<vault>/Projects/<project>/decisions/<slug>.md` with `#decision` tag and full frontmatter. Refuse to overwrite existing slug; suggest `<slug>-2`.

Always run the boot sequence first. Refuse on path traversal, missing vault, or overwrite of an existing decision slug.
```

- [ ] **Step 2: Commit**

```bash
git add commands/save-memory.md
git commit -m "memo(vault): add /agentic-second-brain:save-memory slash command"
```

---

## Task 6: Write `hooks/session-end-save.md`

**Files:**
- Create: `hooks/session-end-save.md`

- [ ] **Step 1: Write `hooks/session-end-save.md`**

```markdown
SessionEnd hook for the agentic-second-brain plugin. Auto-saves the session log when Claude Code exits.

Behavior:

1. Resolve vault path: env var `AGENTIC_SECOND_BRAIN_VAULT` or `~/.config/agentic-second-brain/config.json`. **If unset, exit silently with status 0 — never block session exit.**
2. If the transcript has no user/assistant messages since the last session log, exit 0.
3. Invoke the `agentic-second-brain` skill: `save-memory session`.
4. Use the "Agent Output Format" template from the vault's `CLAUDE.md` (Session Summary, Actions Taken, Notes Processed, Open Items).
5. Populate from the current session transcript:
   - **Session Summary:** 2-3 sentences, what was accomplished.
   - **Actions Taken:** file edits, commands run, decisions made.
   - **Notes Processed:** any `/Inbox` files touched.
   - **Open Items:** unresolved threads, follow-ups.
6. Write to `<vault>/AI/session/<YYYY-MM-DD-HH>.md`. If a file already exists for this hour, append `## Continued` — never overwrite.
7. On any write failure, log to stderr and exit 0. **Never block session exit.**
```

- [ ] **Step 2: Commit**

```bash
git add hooks/session-end-save.md
git commit -m "memo(vault): add SessionEnd hook body for auto session log"
```

---

## Task 7: Write `.claude-plugin/plugin.json`

**Files:**
- Create: `.claude-plugin/plugin.json`

- [ ] **Step 1: Write `.claude-plugin/plugin.json`**

```json
{
  "name": "agentic-second-brain",
  "version": "0.1.0",
  "description": "Obsidian vault as project-aware memory for AI agents — read project context and write structured session/decision/inbox notes back to your vault.",
  "author": "<github-handle-or-display-name>",
  "skills": ["skills/agentic-second-brain"],
  "commands": [
    "commands/get-knowledge.md",
    "commands/save-memory.md"
  ],
  "hooks": {
    "SessionEnd": [
      { "matcher": "*", "command": "hooks/session-end-save.md" }
    ]
  }
}
```

- [ ] **Step 2: Validate JSON**

Run: `jq empty .claude-plugin/plugin.json`
Expected: no output, exit 0.

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/plugin.json
git commit -m "memo(vault): add Claude Code plugin manifest"
```

---

## Task 8: Set Up Bats Test Harness

**Files:**
- Create: `tests/test_helper.bash`

bats-core test helpers: temp HOME, fixture vault staging, teardown. Tests in subsequent tasks `source` this file.

- [ ] **Step 1: Verify bats-core is available**

Run: `bats --version`
Expected: prints version (e.g. `Bats 1.10.0`). If missing, install:
- macOS: `brew install bats-core jq`
- Debian/Ubuntu: `sudo apt-get install bats jq`

If still unavailable, fail loudly — do not skip tests.

- [ ] **Step 2: Write `tests/test_helper.bash`**

```bash
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
```

- [ ] **Step 3: Commit**

```bash
git add tests/test_helper.bash
git commit -m "test(install): add bats test helpers with isolated HOME and fixture vault"
```

---

## Task 9: install.sh — Argument Parsing (TDD)

**Files:**
- Create: `install.sh`
- Create: `tests/install.bats`

Start install.sh as an empty shell + the smallest test that drives parsing.

- [ ] **Step 1: Write the failing test**

Create `tests/install.bats` with the first cases:

```bash
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
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats tests/install.bats`
Expected: FAIL — `install.sh: No such file or directory`.

- [ ] **Step 3: Write minimal `install.sh` to pass**

```bash
#!/usr/bin/env bash
# install.sh — agentic-second-brain non-plugin installer.
set -euo pipefail

VAULT_PATH=""
NO_AUTO_SESSION=0
TARGET="claude-code"
UNINSTALL=0
RESET_CONFIG=0

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --vault <path>          Path to your Obsidian vault (overrides env / config)
  --no-auto-session       Skip SessionEnd hook injection
  --target <agent>        Agent target: claude-code (default). cursor / opencode / all are reserved.
  --uninstall             Remove symlinks and hook entry; preserve config + vault
  --reset-config          Overwrite existing ~/.config/agentic-second-brain/config.json
  --help                  Show this help and exit
EOF
}

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

# Stop here for now — implementation continues in later tasks.
echo "install.sh stub — full flow not yet implemented" >&2
exit 0
```

- [ ] **Step 4: Make it executable**

```bash
chmod +x install.sh
```

- [ ] **Step 5: Run tests, verify they pass**

Run: `bats tests/install.bats`
Expected: 2 tests, 2 PASS.

- [ ] **Step 6: Commit**

```bash
git add install.sh tests/install.bats
git commit -m "feat(install): add argument parsing with --help and unknown-flag handling"
```

---

## Task 10: install.sh — Vault Path Resolution (TDD)

**Files:**
- Modify: `install.sh`
- Modify: `tests/install.bats`

Resolve vault path from `--vault` flag → env var → prompt. v1 prompt is non-interactive in tests via stdin redirection.

- [ ] **Step 1: Add failing tests to `tests/install.bats`**

Append:

```bash
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
  echo "$FIXTURE_VAULT" | run_install --no-auto-session
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
  local mode
  mode=$(stat -f '%Lp' "$XDG_CONFIG_HOME/agentic-second-brain/config.json" 2>/dev/null \
       || stat -c '%a' "$XDG_CONFIG_HOME/agentic-second-brain/config.json")
  [ "$mode" = "600" ]
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats tests/install.bats`
Expected: 5 of the new 5 FAIL (config not written; stub script).

- [ ] **Step 3: Replace the stub in `install.sh` with vault resolution**

Replace the final `echo` + `exit 0` with:

```bash
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/agentic-second-brain"
config_file="$config_dir/config.json"

resolve_vault_path() {
  if [ -n "$VAULT_PATH" ]; then
    return
  fi
  if [ -n "${AGENTIC_SECOND_BRAIN_VAULT:-}" ]; then
    VAULT_PATH="$AGENTIC_SECOND_BRAIN_VAULT"
    return
  fi
  printf "Path to your Obsidian vault: "
  read -r VAULT_PATH
}

resolve_vault_path

if [ ! -d "$VAULT_PATH" ]; then
  echo "error: vault path \"$VAULT_PATH\" is not a directory" >&2
  exit 1
fi

write_config() {
  mkdir -p "$config_dir"
  if [ -f "$config_file" ] && [ "$RESET_CONFIG" -eq 0 ]; then
    # Existing config preserved unless --reset-config; still update if vault path changed.
    local current
    current=$(jq -r '.vault_path' "$config_file" 2>/dev/null || echo "")
    if [ "$current" = "$VAULT_PATH" ]; then
      return
    fi
  fi
  jq -n --arg vault "$VAULT_PATH" --arg version "0.1.0" \
    '{vault_path: $vault, version: $version}' > "$config_file"
  chmod 600 "$config_file"
}

write_config

echo "config written: $config_file" >&2
# Continued in later tasks.
exit 0
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `bats tests/install.bats`
Expected: 7 tests, 7 PASS (2 from Task 9 + 5 new).

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install.bats
git commit -m "feat(install): resolve vault path from flag/env/prompt and write config with chmod 600"
```

---

## Task 11: install.sh — Vault CLAUDE.md Bootstrap (TDD)

**Files:**
- Modify: `install.sh`
- Modify: `tests/install.bats`

If the vault has no `CLAUDE.md`, prompt to copy `templates/vault-CLAUDE.md`. Never overwrite existing.

- [ ] **Step 1: Add failing tests**

Append to `tests/install.bats`:

```bash
@test "install.sh copies vault CLAUDE.md when missing and user accepts" {
  echo "y" | run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  assert_file_exists "$FIXTURE_VAULT/CLAUDE.md"
  # Compare first line for sanity — template starts with "# CLAUDE.md".
  head -1 "$FIXTURE_VAULT/CLAUDE.md" | grep -q "^# CLAUDE.md$"
}

@test "install.sh leaves existing vault CLAUDE.md untouched" {
  echo "# Custom Vault Notes" > "$FIXTURE_VAULT/CLAUDE.md"
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  [ "$(head -1 "$FIXTURE_VAULT/CLAUDE.md")" = "# Custom Vault Notes" ]
}

@test "install.sh skips bootstrap when user declines" {
  echo "n" | run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  [ ! -f "$FIXTURE_VAULT/CLAUDE.md" ]
  [[ "$output" == *"skipping vault CLAUDE.md bootstrap"* ]]
}
```

- [ ] **Step 2: Run tests, verify the new ones fail**

Run: `bats tests/install.bats`
Expected: 3 of the new 3 FAIL.

- [ ] **Step 3: Add bootstrap logic to `install.sh`**

After `write_config`, before the trailing `exit 0`, insert:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bootstrap_vault_claude_md() {
  local target="$VAULT_PATH/CLAUDE.md"
  if [ -f "$target" ]; then
    return
  fi
  printf "Vault has no CLAUDE.md. Copy starter template? [y/N] "
  local reply
  read -r reply
  case "$reply" in
    y|Y|yes|YES)
      cp "$SCRIPT_DIR/templates/vault-CLAUDE.md" "$target"
      echo "wrote: $target" >&2
      ;;
    *)
      echo "skipping vault CLAUDE.md bootstrap" >&2
      ;;
  esac
}

bootstrap_vault_claude_md
```

- [ ] **Step 4: Run tests, verify all pass**

Run: `bats tests/install.bats`
Expected: 10 tests, 10 PASS.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install.bats
git commit -m "feat(install): bootstrap vault CLAUDE.md from template when missing"
```

---

## Task 12: install.sh — Symlink Skill Files (TDD)

**Files:**
- Modify: `install.sh`
- Modify: `tests/install.bats`

Symlink (not copy) so `git pull` updates skill body live.

- [ ] **Step 1: Add failing tests**

Append:

```bash
@test "install.sh symlinks skill dir into ~/.claude/skills" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  assert_symlink_to "$HOME/.claude/skills/agentic-second-brain" \
    "$REPO_ROOT/skills/agentic-second-brain"
}

@test "install.sh symlinks both slash command files" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  assert_symlink_to "$HOME/.claude/commands/agentic-second-brain/get-knowledge.md" \
    "$REPO_ROOT/commands/get-knowledge.md"
  assert_symlink_to "$HOME/.claude/commands/agentic-second-brain/save-memory.md" \
    "$REPO_ROOT/commands/save-memory.md"
}

@test "install.sh re-running is idempotent for symlinks" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  assert_symlink_to "$HOME/.claude/skills/agentic-second-brain" \
    "$REPO_ROOT/skills/agentic-second-brain"
}

@test "install.sh fails fast for unsupported target" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session --target cursor
  [ "$status" -ne 0 ]
  [[ "$output" == *"target not yet supported"* ]]
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats tests/install.bats`
Expected: new tests FAIL.

- [ ] **Step 3: Add symlink logic and target gate to `install.sh`**

After the bootstrap section, add:

```bash
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

claude_root="$HOME/.claude"
skills_dir="$claude_root/skills"
commands_dir="$claude_root/commands/agentic-second-brain"

install_symlinks() {
  mkdir -p "$skills_dir" "$commands_dir"
  ln -sfn "$SCRIPT_DIR/skills/agentic-second-brain" "$skills_dir/agentic-second-brain"
  ln -sfn "$SCRIPT_DIR/commands/get-knowledge.md" "$commands_dir/get-knowledge.md"
  ln -sfn "$SCRIPT_DIR/commands/save-memory.md"   "$commands_dir/save-memory.md"
}

install_symlinks
```

`ln -sfn` overwrites existing symlinks atomically — safe for re-run.

- [ ] **Step 4: Run tests, verify all pass**

Run: `bats tests/install.bats`
Expected: 14 tests, 14 PASS.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install.bats
git commit -m "feat(install): symlink skill and slash command files into ~/.claude with target gate"
```

---

## Task 13: install.sh — SessionEnd Hook Injection (TDD)

**Files:**
- Modify: `install.sh`
- Modify: `tests/install.bats`

Merge a SessionEnd hook block into `~/.claude/settings.json` via `jq`. Idempotent.

- [ ] **Step 1: Add failing tests**

Append:

```bash
@test "install.sh injects SessionEnd hook into settings.json" {
  run_install --vault "$FIXTURE_VAULT"
  [ "$status" -eq 0 ]
  assert_file_exists "$HOME/.claude/settings.json"
  local hook_count
  hook_count=$(jq '[.hooks.SessionEnd[]? | select(.command | contains("agentic-second-brain"))] | length' \
    "$HOME/.claude/settings.json")
  [ "$hook_count" = "1" ]
}

@test "install.sh hook injection is idempotent (no duplicates on re-run)" {
  run_install --vault "$FIXTURE_VAULT"
  run_install --vault "$FIXTURE_VAULT"
  [ "$status" -eq 0 ]
  local hook_count
  hook_count=$(jq '[.hooks.SessionEnd[]? | select(.command | contains("agentic-second-brain"))] | length' \
    "$HOME/.claude/settings.json")
  [ "$hook_count" = "1" ]
}

@test "install.sh --no-auto-session does NOT inject hook" {
  run_install --vault "$FIXTURE_VAULT" --no-auto-session
  [ "$status" -eq 0 ]
  if [ -f "$HOME/.claude/settings.json" ]; then
    local hook_count
    hook_count=$(jq '[.hooks.SessionEnd[]? | select(.command | contains("agentic-second-brain"))] | length' \
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
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats tests/install.bats`
Expected: new tests FAIL.

- [ ] **Step 3: Add hook injection logic**

After `install_symlinks`, insert:

```bash
settings_file="$claude_root/settings.json"
hook_command_path="$SCRIPT_DIR/hooks/session-end-save.md"

inject_session_end_hook() {
  if [ "$NO_AUTO_SESSION" -eq 1 ]; then
    return
  fi
  command -v jq >/dev/null 2>&1 || {
    echo "error: jq is required to merge ~/.claude/settings.json. Install jq:" >&2
    echo "  macOS:  brew install jq" >&2
    echo "  Debian: sudo apt-get install jq" >&2
    exit 4
  }
  if [ ! -f "$settings_file" ]; then
    echo '{}' > "$settings_file"
  fi
  local tmp
  tmp=$(mktemp)
  jq --arg cmd "$hook_command_path" '
    .hooks //= {}
    | .hooks.SessionEnd //= []
    | if any(.hooks.SessionEnd[]?; .command == $cmd)
      then .
      else .hooks.SessionEnd += [{"matcher": "*", "command": $cmd}]
      end
  ' "$settings_file" > "$tmp"
  mv "$tmp" "$settings_file"
}

inject_session_end_hook
```

- [ ] **Step 4: Run tests, verify all pass**

Run: `bats tests/install.bats`
Expected: 18 tests, 18 PASS.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install.bats
git commit -m "feat(install): inject SessionEnd hook via jq merge with idempotency guard"
```

---

## Task 14: install.sh — Uninstall Path (TDD)

**Files:**
- Modify: `install.sh`
- Modify: `tests/install.bats`

Remove symlinks and hook entry. Preserve config and vault.

- [ ] **Step 1: Add failing tests**

Append:

```bash
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
    hook_count=$(jq '[.hooks.SessionEnd[]? | select(.command | contains("agentic-second-brain"))] | length' \
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
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats tests/install.bats`
Expected: new tests FAIL.

- [ ] **Step 3: Add uninstall path**

Restructure `install.sh` so that after argument parsing, the uninstall branch short-circuits. Insert near the top, right after the `while` loop:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
claude_root="$HOME/.claude"
settings_file="$claude_root/settings.json"
hook_command_path="$SCRIPT_DIR/hooks/session-end-save.md"

if [ "$UNINSTALL" -eq 1 ]; then
  rm -f "$claude_root/skills/agentic-second-brain"
  rm -rf "$claude_root/commands/agentic-second-brain"
  if [ -f "$settings_file" ] && command -v jq >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq --arg cmd "$hook_command_path" '
      if .hooks.SessionEnd then
        .hooks.SessionEnd |= map(select(.command != $cmd))
      else . end
    ' "$settings_file" > "$tmp"
    mv "$tmp" "$settings_file"
  fi
  echo "uninstalled. config preserved at \$XDG_CONFIG_HOME/agentic-second-brain/config.json" >&2
  exit 0
fi
```

Move the existing `SCRIPT_DIR` definition and any other duplicate computations from later in the file up to this block; remove duplicates downstream.

- [ ] **Step 4: Run tests, verify all pass**

Run: `bats tests/install.bats`
Expected: 22 tests, 22 PASS.

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install.bats
git commit -m "feat(install): add --uninstall removing symlinks and hook entry, preserving config"
```

---

## Task 15: install.sh — `jq` Missing Error Path (TDD)

**Files:**
- Modify: `install.sh` (no change — already implemented in Task 13; just add coverage)
- Modify: `tests/install.bats`

Verify the loud error when `jq` is unavailable.

- [ ] **Step 1: Add failing test**

Append:

```bash
@test "install.sh errors loud when jq is missing during hook injection" {
  # Mask jq by prepending an empty PATH dir.
  local jqshim="$TEST_TMP/nojq"
  mkdir -p "$jqshim"
  PATH="$jqshim:/usr/bin:/bin" run env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    bash "$REPO_ROOT/install.sh" --vault "$FIXTURE_VAULT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"jq is required"* ]]
}
```

- [ ] **Step 2: Run test, verify**

Run: `bats tests/install.bats`
Expected: 23 tests, 23 PASS (the loud error is already wired in Task 13).

If the test fails because `write_config` runs before hook injection and depends on `jq` (it does), update `write_config` to also error loud when `jq` is missing — same `command -v jq` guard, surfaced before the config write attempt:

```bash
require_jq() {
  command -v jq >/dev/null 2>&1 || {
    echo "error: jq is required. Install jq:" >&2
    echo "  macOS:  brew install jq" >&2
    echo "  Debian: sudo apt-get install jq" >&2
    exit 4
  }
}

require_jq
```

Insert `require_jq` call at the top of `install.sh` after argument parsing (before the uninstall branch — uninstall also uses `jq` if available but tolerates absence).

Re-run: `bats tests/install.bats` → 23 PASS.

- [ ] **Step 3: Commit**

```bash
git add install.sh tests/install.bats
git commit -m "test(install): cover jq-missing error path with loud message"
```

---

## Task 16: Fixture Vault for Smoke Tests

**Files:**
- Create: `tests/fixtures/vault/CLAUDE.md`
- Create: `tests/fixtures/vault/Projects/praio/index.md`
- Create: `tests/fixtures/vault/Projects/praio/decisions/auth-existing.md`
- Create: `tests/fixtures/vault/Projects/praio/research/.gitkeep`
- Create: `tests/fixtures/vault/Projects/Praio-Mobile/index.md`
- Create: `tests/fixtures/vault/Inbox/2026-05-04.md`
- Create: `tests/fixtures/vault/AI/session/2026-05-03-15.md`
- Create: `tests/fixtures/vault/Notes/Auth Strategy.md`
- Create: `tests/fixtures/vault/Notes/needs-review-praio.md`

Realistic fixture for Phase 1 / Phase 2 manual smoke test in `tests/SMOKE.md`.

- [ ] **Step 1: Copy starter as fixture vault CLAUDE.md**

```bash
cp templates/vault-CLAUDE.md tests/fixtures/vault/CLAUDE.md
```

- [ ] **Step 2: Write `tests/fixtures/vault/Projects/praio/index.md`**

```markdown
---
title: praio
date: 2026-05-04
tags: [project]
status: active
---

# praio

Research project on adaptive caching for distributed APIs.

## Status
Active. Auth path under review.

## Key Areas
- [[Auth Strategy]]
- [[Onboarding Flow]]

## Open Actions
- #action Confirm JWT vs session cookie with security review
```

- [ ] **Step 3: Write `tests/fixtures/vault/Projects/praio/decisions/auth-existing.md`**

```markdown
---
title: Use HTTP-only cookies for v0
date: 2026-04-20
tags: [decision]
status: archived
project: praio
---

# Use HTTP-only cookies for v0

#decision

Earlier decision before JWT review opened. Kept for history.
```

- [ ] **Step 4: Write `tests/fixtures/vault/Projects/Praio-Mobile/index.md`**

```markdown
---
title: Praio-Mobile
date: 2026-04-15
tags: [project]
status: active
---

# Praio-Mobile

Mobile companion to praio. Separate codebase, shared API.
```

- [ ] **Step 5: Write `tests/fixtures/vault/Inbox/2026-05-04.md`**

```markdown
---
title: Daily Note 2026-05-04
date: 2026-05-04
tags: []
status: active
processed: false
---

# 2026-05-04

## Captures
- Need to revisit JWT vs cookies for praio.
```

- [ ] **Step 6: Write `tests/fixtures/vault/AI/session/2026-05-03-15.md`**

```markdown
---
date: 2026-05-03
hour: 15
tags: [ai-session]
---

## Session Summary
Reviewed praio caching layer. Discussed adaptive TTL.

## Actions Taken
- Read Projects/praio/index.md
- Skimmed praio/decisions/

## Notes Processed
- (none)

## Open Items
- Decide on auth strategy for praio.
```

- [ ] **Step 7: Write `tests/fixtures/vault/Notes/Auth Strategy.md`**

```markdown
---
title: Auth Strategy
date: 2026-05-01
tags: [research]
status: active
project: praio
related:
  - "[[praio/index]]"
---

# Auth Strategy

Comparing JWT vs session cookies. Open question: rotation cadence.
```

- [ ] **Step 8: Write `tests/fixtures/vault/Notes/needs-review-praio.md`**

```markdown
---
title: needs-review-praio
date: 2026-05-02
tags: [needs-review]
status: draft
project: praio
---

# Pending Review

#needs-review

Should the cache layer use ETags or Last-Modified for invalidation?
```

- [ ] **Step 9: Commit**

```bash
git add tests/fixtures/vault/
git commit -m "test(fixtures): add fixture Obsidian vault with two projects, daily, session, needs-review"
```

---

## Task 17: SMOKE.md Manual Checklist

**Files:**
- Create: `tests/SMOKE.md`

Manual steps a human runs in Claude Code after install to confirm skill behavior.

- [ ] **Step 1: Write `tests/SMOKE.md`**

```markdown
# Smoke Test — agentic-second-brain v1

Manual checklist run in Claude Code after `./install.sh --vault $(pwd)/tests/fixtures/vault`.

Each step lists the input and the assertion. Run in a single Claude Code session unless noted.

## Setup

```bash
./install.sh --vault "$(pwd)/tests/fixtures/vault"
```

Expected: config written, vault CLAUDE.md untouched (fixture already has one), symlinks present, SessionEnd hook in `~/.claude/settings.json`.

## 1. Phase 1 read — exact match

Input: `/agentic-second-brain:get-knowledge praio`

Assertions:
- Skill loads `Projects/praio/index.md`.
- Lists `[[Auth Strategy]]` and `[[Onboarding Flow]]` as known wiki-links.
- Surfaces today's daily note (`Inbox/2026-05-04.md`) capture.
- Surfaces `needs-review-praio` note.
- Surfaces last session summary (`2026-05-03-15.md`).
- Lists `auth-existing.md` filename in `decisions/` but does NOT read its content.

## 2. Phase 2 follow-up — wiki-link navigation

Input (same conversation): "what's the auth strategy?"

Assertions:
- Skill resolves `[[Auth Strategy]]` from the nav map.
- Reads `Notes/Auth Strategy.md`.
- Answers about JWT vs cookies and rotation cadence question.

## 3. save-memory inbox

Input: `/agentic-second-brain:save-memory inbox "smoke test capture"`

Assertions:
- `Inbox/<today>.md` has a new entry containing "smoke test capture".
- Existing content preserved.

## 4. save-memory decision (new slug)

Input: `/agentic-second-brain:save-memory decision praio auth-jwt`

Assertions:
- `Projects/praio/decisions/auth-jwt.md` created.
- Frontmatter populated per vault CLAUDE.md schema (`title`, `date`, `tags`, `status`, `project`, `processed`, `related`).
- Body contains `#decision` tag.

## 5. save-memory decision (collision)

Input: `/agentic-second-brain:save-memory decision praio auth-jwt`

Assertions:
- Skill refuses to overwrite.
- Suggests `auth-jwt-2`.
- File from step 4 unchanged.

## 6. Case-insensitive project match

Input: `/agentic-second-brain:get-knowledge PRAIO`

Assertions:
- Matches `praio` (case-folded).
- Behaves identically to step 1.

## 7. Ambiguous prefix is not a match

Input: `/agentic-second-brain:get-knowledge pra`

Assertions:
- Skill returns "no project matches `pra`".
- Lists available projects: `praio`, `Praio-Mobile`.
- Does NOT load any project.

## 8. SessionEnd auto-save

Action: `/exit` from Claude Code.

Assertions:
- `tests/fixtures/vault/AI/session/<today-hour>.md` created.
- Contains the four sections from the Agent Output Format.

## 9. Same-hour collision append

Action: open a new Claude Code session in the same hour, do trivial work, `/exit`.

Assertions:
- Same `<today-hour>.md` file gains a `## Continued` section.
- Original content untouched.

## 10. Cleanup

```bash
./install.sh --uninstall
```

Assertions:
- Symlinks gone.
- Hook entry removed from settings.json.
- Config and vault contents untouched.
```

- [ ] **Step 2: Commit**

```bash
git add tests/SMOKE.md
git commit -m "test(smoke): add manual checklist for skill behavior covering both phases and SessionEnd"
```

---

## Task 18: README.md

**Files:**
- Create: `README.md`

User-facing install + usage docs.

- [ ] **Step 1: Write `README.md`**

```markdown
# agentic-second-brain

Bridge an AI coding agent (Claude Code) to your Obsidian vault. Read project context on demand. Write structured session logs, inbox notes, and decision records back to the vault — all per the schema your vault's own `CLAUDE.md` declares.

## What This Is

- Two operations: `get-knowledge <project>` and `save-memory <kind> [args]`.
- Pure markdown skill — no runtime, no CLI binary. Uses Claude Code's built-in Read/Write/Glob/Grep.
- Vault is the source of truth. Edit `<vault>/CLAUDE.md` to change conventions; the skill picks it up next call.
- Auto session log via SessionEnd hook (opt-out at install time).

## Install

### Option A — Claude Code plugin

Recommended for Claude Code users.

```bash
# in your Claude Code session
/plugin install <this-repo-url>
```

This registers the skill, the slash commands, and the SessionEnd hook automatically. You will still need to point the plugin at your vault — see "Configure Vault Path" below.

### Option B — `install.sh`

For manual installs, dotfile setups, or future ports to other agents.

```bash
git clone <this-repo-url> ~/code/ai-memory-skills
cd ~/code/ai-memory-skills
./install.sh --vault /path/to/your/obsidian-vault
```

Flags:
- `--vault <path>` — path to your Obsidian vault.
- `--no-auto-session` — skip the SessionEnd hook.
- `--target <agent>` — `claude-code` (default; others reserved).
- `--reset-config` — overwrite an existing config file.
- `--uninstall` — remove symlinks and hook entry; preserves config and vault.
- `--help` — show usage.

The script:
1. Resolves the vault path (`--vault` → `$AGENTIC_SECOND_BRAIN_VAULT` → prompt).
2. Writes `~/.config/agentic-second-brain/config.json` with permissions 600.
3. Offers to copy `templates/vault-CLAUDE.md` into your vault if it has no `CLAUDE.md` (never overwrites).
4. Symlinks the skill body and slash commands into `~/.claude/`.
5. Injects a SessionEnd hook into `~/.claude/settings.json` (skip with `--no-auto-session`).

## Configure Vault Path

The skill resolves the vault path in this order:

1. `$AGENTIC_SECOND_BRAIN_VAULT` environment variable.
2. `~/.config/agentic-second-brain/config.json` (`vault_path` key).

`install.sh` writes the config file. The env var is for power users / multi-vault overrides.

## Usage

```
/agentic-second-brain:get-knowledge <project>
```

Loads `<vault>/Projects/<project>/index.md` (case-insensitive match), today's daily note, `#needs-review` notes, recent session logs, and lists decision and research filenames. Holds the index's wiki-links as a navigation map for follow-up questions.

```
/agentic-second-brain:save-memory inbox "<text>"
/agentic-second-brain:save-memory session
/agentic-second-brain:save-memory decision <project> <slug>
```

Writes to your vault per the schema in `<vault>/CLAUDE.md`. Append-only for daily notes and session logs. Refuses to overwrite an existing decision slug.

The skill also auto-triggers when you say things like "load praio context" or "save this session" — no slash command required.

## Vault Layout Expected

```
<your-vault>/
├── CLAUDE.md          # schema source of truth (skill bootstraps this if missing)
├── Inbox/             # daily notes: YYYY-MM-DD.md
├── Projects/          # one folder per project; each has index.md, decisions/, research/
├── Archive/           # read-only for the skill
├── AI/session/        # session logs: YYYY-MM-DD-HH.md
└── Templates/         # reusable note templates
```

## Uninstall

```bash
./install.sh --uninstall
```

Or, if installed via the plugin route, `/plugin disable agentic-second-brain`.

Vault contents and config file are preserved. Delete `~/.config/agentic-second-brain/config.json` manually if you want a fully clean slate.

## Tests

```bash
bats tests/install.bats
```

Manual smoke checklist for skill behavior: `tests/SMOKE.md`.

## License

TBD.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with install paths, usage, and vault layout"
```

---

## Task 19: Run Full Test Suite + Manual Smoke

**Files:**
- No new files. Verification step.

- [ ] **Step 1: Run bats**

```bash
bats tests/install.bats
```

Expected: all tests PASS (23 tests across Tasks 9–15).

- [ ] **Step 2: Validate plugin manifest**

```bash
jq empty .claude-plugin/plugin.json
```

Expected: exit 0, no output.

- [ ] **Step 3: Sanity-check install on a throwaway HOME**

```bash
TMP_HOME=$(mktemp -d)
HOME="$TMP_HOME" XDG_CONFIG_HOME="$TMP_HOME/.config" \
  ./install.sh --vault "$(pwd)/tests/fixtures/vault" --no-auto-session
test -L "$TMP_HOME/.claude/skills/agentic-second-brain"
test -f "$TMP_HOME/.config/agentic-second-brain/config.json"
HOME="$TMP_HOME" XDG_CONFIG_HOME="$TMP_HOME/.config" \
  ./install.sh --uninstall
test ! -e "$TMP_HOME/.claude/skills/agentic-second-brain"
rm -rf "$TMP_HOME"
```

Expected: all `test` calls succeed (exit 0).

- [ ] **Step 4: Run the SMOKE.md checklist manually in Claude Code**

Follow `tests/SMOKE.md`. Mark steps that pass.

- [ ] **Step 5: Commit any fixes uncovered by smoke testing**

If smoke testing reveals issues, fix them as separate small commits scoped to the failing case, then re-run the full suite.

---

## Self-Review

**Spec coverage check:**

| Spec section | Task(s) implementing it |
| --- | --- |
| §3 Repository Layout | Task 1 (scaffolding); Tasks 2–7 (file creation) |
| §4.1 Boot sequence | Task 3 (SKILL.md) |
| §4.2 get-knowledge two-phase | Task 3 (SKILL.md), Task 17 (SMOKE.md cases 1, 2, 6, 7) |
| §4.3 save-memory three kinds | Task 3 (SKILL.md), Task 5 (slash command), Task 17 (cases 3, 4, 5) |
| §4.4 Failure modes | Task 3 (Failure Modes table); covered behaviorally in Task 17 |
| §5 Plugin manifest | Task 7 |
| §6 Slash commands | Tasks 4, 5 |
| §7 SessionEnd hook | Task 6 (body), Task 13 (install injection), Task 17 (cases 8, 9) |
| §8 install.sh | Tasks 9–15 |
| §9.1 install.bats | Tasks 9–15 (TDD with bats) |
| §9.2 Smoke checklist | Tasks 16–17 |
| §10 Error matrix | Tasks 3, 13, 14, 15 + spec excerpt in Task 3 |
| §11 Security (chmod 600, path traversal, no exec) | Task 10 (chmod), Task 3 (path traversal in skill); no-exec is structural (no shell-out in skill) |
| §11.1 Privacy note (author placeholder) | Task 7 |

No spec section is unrepresented.

**Placeholder scan:** README has one `License: TBD` line — kept intentionally so the user picks a license. All other placeholders refer to user-provided values (e.g. `<your-vault>`, `<github-handle-or-display-name>`) and are deliberate, not gaps.

**Type / identifier consistency:**

- Skill operation names: `get-knowledge`, `save-memory` — used identically across SKILL.md, slash commands, hook body, README, smoke tests.
- Argument shape: `save-memory <kind> [args]` with `kind ∈ {inbox, session, decision}` consistent across §4.3 of spec, Task 5, Task 17, README.
- Config file path: `~/.config/agentic-second-brain/config.json` (with `XDG_CONFIG_HOME` honored in tests) consistent across SKILL.md boot sequence, install.sh, hook body, README.
- Env var name: `AGENTIC_SECOND_BRAIN_VAULT` consistent everywhere.
- Hook command path: `<repo>/hooks/session-end-save.md` consistent in plugin.json, install.sh injection, install.sh uninstall removal.

No drift.
