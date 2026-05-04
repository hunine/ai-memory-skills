# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repo packages **Agentic Second Brain** as an installable skill/plugin set for multiple AI coding agents (Claude Code, opencode, Cursor, Codex, etc.). The skill turns a user's Obsidian vault into a shared, project-aware memory layer — agents read project knowledge from the vault and write structured memories back into it.

The vault itself (the "second brain") lives outside this repo. This repo only ships the agent-side skills, templates, and installer that point agents at the vault.

## Two Core Skill Surfaces

Every distribution target (Claude Code skill, Cursor rule, opencode/codex equivalent) must expose at least these two surfaces with consistent semantics:

1. **get-knowledge** — Load project context from the vault on demand.
   - Trigger: `<plugin>:get-knowledge <project-folder-name>` (e.g. `praio` → reads `/Projects/praio/`).
   - Resolution order: `index.md` first, then `decisions/`, then `research/`. Never deep-scan blindly.
   - Also surface: today's daily note (`/Inbox/YYYY-MM-DD.md`), any `#needs-review` notes for that project, latest `/AI/session/*` entries that link to the project.

2. **save-memory** — Write back to the vault using the conventions defined in the vault's own `CLAUDE.md` (the "vault CLAUDE.md"). Targets:
   - `/Inbox/YYYY-MM-DD.md` for daily captures (append, don't overwrite).
   - `/AI/session/YYYY-MM-DD-HH.md` for session logs (24-hour `HH`, one file per session).
   - `/Projects/<name>/decisions/<slug>.md` for `#decision` notes.
   - All new files must include the YAML frontmatter block specified in the vault CLAUDE.md (`title`, `date`, `tags`, `status`, `project`, `processed`, `related`).

The vault's `CLAUDE.md` is the source of truth for note format, tag vocabulary (`#needs-review`, `#decision`, `#action`), commit message format (`memo(<scope>): ...`), and session protocol. Skills must read it at runtime rather than hard-coding the schema — the user can evolve their vault conventions without re-releasing skills.

## Vault Layout Contract (assumed)

Skills assume the vault matches this shape. If absent, prompt the user to point at a different vault path, do not guess.

| Path | Role |
| --- | --- |
| `/Inbox/` | Raw captures. Daily notes at `/Inbox/YYYY-MM-DD.md`. |
| `/Projects/<name>/` | Active projects. Each has `index.md`, `decisions/`, `research/`. |
| `/Archive/` | Read-only for agents. Do not write here. |
| `/AI/session/` | Agent session logs at `YYYY-MM-DD-HH.md`. |
| `/Templates/` | Reusable note templates referenced by `save-memory`. |

## Multi-Agent Distribution

Same logical skill must ship in target-specific shapes:

- **Claude Code** — `skills/<name>/SKILL.md` with frontmatter (`name`, `description`); installable via plugin or symlink into `~/.claude/skills/`.
- **Cursor** — `.cursor/rules/*.mdc` rule files mapping to the same triggers.
- **opencode / codex / others** — equivalent prompt or tool-definition format per their docs.

Keep the prose body of every variant generated from a single source-of-truth document so behavior stays identical across agents. Diverge only on the metadata header that each tool requires.

## Vault Path Configuration

Skills must not hard-code the vault location. Read it from (in order):

1. Environment variable `AGENTIC_SECOND_BRAIN_VAULT`.
2. A config file at `~/.config/agentic-second-brain/config.json` (key: `vault_path`).
3. Prompt the user once and persist their answer to (2).

## Repository State

Repo is currently empty (no commits, no source files yet). When adding the first skill, scaffold:

- `skills/<name>/SKILL.md` for the Claude Code variant.
- `install.sh` (or equivalent) that symlinks/copies the skill into the right per-agent global directory.
- `README.md` describing supported agents and install steps.

Build, lint, and test commands will be added once a toolchain is chosen — do not invent commands until the scaffold lands.
