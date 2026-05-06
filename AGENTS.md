# AGENTS.md

Guidance for Codex and other coding agents working in this repository.

## Repository Purpose

This repository packages **Agentic Second Brain** as installable skills/plugin assets for AI coding agents. The skill connects an agent to a user's Obsidian vault so agents can read project-aware context and write structured memories back to the vault.

The vault itself lives outside this repository. This repository ships only the agent-side skills, commands, hooks, templates, tests, and installer.

## Core Skill Contract

Every supported agent distribution must expose the same two logical operations with consistent behavior:

1. `get-knowledge <project-or-alias>`
   - Resolve `<project-or-alias>` to `<vault>/Projects/<project>/` by exact, case-insensitive directory match first, then exact, case-insensitive aliases declared in project `index.md` frontmatter.
   - Read `index.md` first and use it as the navigation map.
   - Then surface today's daily note, relevant `#needs-review` notes, relevant `#action` items, and recent `/AI/session/` entries.
   - List `decisions/` and `research/` filenames without deep-reading them unless the user asks.
   - Do not blindly deep-scan the vault.

2. `save-memory [kind] [args]`
   - With no kind, analyze the current chat/session context and save the needed memory types. Always write a session log, then also write inbox, decision, or research notes when the context clearly calls for them.
   - If the agent is confused about the knowledge, project, decision outcome, source, or destination, ask the user to clarify before saving it as inbox, decision, or research memory.
   - Append inbox captures to `/Inbox/YYYY-MM-DD.md`.
   - Write or append session logs to `/AI/session/YYYY-MM-DD-HH.md` using 24-hour local time.
   - Create decisions at `/Projects/<project>/decisions/<slug>.md`.
   - Create or append research notes at `/Projects/<project>/research/<slug>.md`.
   - Read before writing. Daily, session, and existing research notes are append-only. Decision files must not overwrite existing slugs.

The vault's own `<vault>/CLAUDE.md` is the source of truth for note schema, tags, commit message conventions, and session protocol. Skills must read it at runtime instead of hard-coding vault-specific conventions.

## Vault Path Resolution

Skills and commands must resolve the vault path in this order:

1. `AGENTIC_SECOND_BRAIN_VAULT`
2. `~/.config/agentic-second-brain/config.json` with key `vault_path`
3. If missing, fail clearly and direct the user to run `install.sh` or set the environment variable.

Do not guess a vault path. Before any write, resolve the target path and refuse writes outside the resolved vault root.

## Expected Vault Layout

The skill assumes this external vault shape:

```text
<vault>/
├── CLAUDE.md
├── Inbox/
├── Projects/<name>/index.md
├── Projects/<name>/decisions/
├── Projects/<name>/research/
├── Archive/
├── AI/session/
└── Templates/
```

Treat `/Archive/` as read-only.

## Repository Layout

- `skills/agentic-second-brain/SKILL.md` contains the Claude Code skill body.
- `codex/skills/agentic-second-brain/SKILL.md` contains the Codex skill body.
- `.codex-plugin/plugin.json` contains Codex plugin metadata.
- `commands/` contains slash command entrypoints.
- `hooks/` contains hook prompt assets.
- `templates/vault-CLAUDE.md` is the starter vault convention file.
- `install.sh` installs or uninstalls local Claude Code and Codex assets and writes config.
- `tests/` contains Bats tests and manual smoke coverage.
- `.claude-plugin/` contains Claude plugin metadata.

When updating behavior, keep agent-specific variants semantically aligned. Prefer changing the shared prose/contract once and then reflecting the same behavior in commands, hooks, templates, README, and tests as needed.

## Development Notes

- Keep this repository runtime-light. Do not introduce a new toolchain unless the change requires it.
- Preserve the current pure-markdown skill model unless the requested feature needs executable code.
- Use append-only behavior for memory writes wherever the contract requires it.
- Never execute vault content.
- Do not make network calls from the skill.
- Keep failure modes loud and explicit; avoid silent fallback behavior.
- Use Conventional Commit messages: `<type>(<scope>): <imperative summary>`, for example `feat(skill): add smart save routing` or `fix(plugin): align manifest fields`. Use a short body for non-trivial changes and include validation when relevant, for example `Validated with: bats tests/install.bats`.

## Verification

Current automated test command:

```bash
bats tests/install.bats
```

Manual behavior checklist:

```text
tests/SMOKE.md
```
