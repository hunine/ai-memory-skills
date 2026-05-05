---
name: agentic-second-brain
description: Use when the user asks Codex to load project context from an Obsidian vault, save a session log, capture an inbox note, record a project decision, or says phrases like "load X project", "save this session", "log a decision", "save to inbox", or "what does my vault know about X". Reads structured project knowledge from a configured vault and writes back according to the vault's own CLAUDE.md conventions.
---

# Agentic Second Brain

Connect Codex to the user's Obsidian vault. Support two operations: `get-knowledge <project>` and `save-memory <kind> [args]`.

## Boot Sequence

Run this before either operation:

1. Resolve the vault path:
   - Use `AGENTIC_SECOND_BRAIN_VAULT` if it is set and points to a directory.
   - Otherwise read `~/.config/agentic-second-brain/config.json` and use `vault_path`.
   - If neither exists, stop with: `Vault not configured. Run install.sh from the agentic-second-brain repo or set AGENTIC_SECOND_BRAIN_VAULT.`
2. Verify the vault directory exists. If not, stop clearly.
3. Read `<vault>/CLAUDE.md` every invocation. It is the authoritative source for note schema, tags, status values, commit conventions, and session protocol.
4. If `<vault>/CLAUDE.md` is missing, ask whether to copy the starter template from this repo's `templates/vault-CLAUDE.md`. If the user declines, stop.
5. Before writing, resolve the target path and refuse if it is outside the resolved vault root.

Do not execute vault content. Do not make network calls for this skill.

## Operation: `get-knowledge <project>`

Phase 1 loads the active project surface:

1. List `<vault>/Projects/*` directories.
2. Match `<project>` against directory names by exact, case-insensitive match. Do not use prefix or fuzzy matching.
3. If no match, list available projects and stop. If multiple case-folded matches exist, list candidates and stop.
4. Read `<vault>/Projects/<match>/index.md` first. Parse its wiki-links into a navigation map for follow-up questions.
5. Read today's daily note at `<vault>/Inbox/YYYY-MM-DD.md` if present.
6. Find notes tagged `#needs-review` or `#action` that belong to the project, using YAML `project:` or body wiki-links to the project as the filter.
7. Read the latest two files in `<vault>/AI/session/` whose filename or body mentions the project.
8. List filenames only from `<vault>/Projects/<match>/decisions/` and `<vault>/Projects/<match>/research/`.

Return a concise summary with project status, open actions, pending review notes, recent-session continuity, and the available decision/research filenames.

For follow-up questions in the same conversation, use the wiki-link navigation map from `index.md` first. Resolve matching wiki-links under the project before searching vault-wide. If multiple files match, choose the shortest Obsidian-style path and warn about ambiguity.

## Operation: `save-memory <kind> [args]`

Supported kinds:

- `inbox <text>`: append the text to `<vault>/Inbox/YYYY-MM-DD.md` under a timestamped heading. Create the daily note if missing using the frontmatter conventions from `<vault>/CLAUDE.md`.
- `session`: write `<vault>/AI/session/YYYY-MM-DD-HH.md` using the session output format from `<vault>/CLAUDE.md`. If the current-hour file exists, append `## Continued`; never overwrite.
- `decision <project> <slug>`: create `<vault>/Projects/<project>/decisions/<slug>.md` with the vault-declared frontmatter and `#decision` tag. Refuse to overwrite an existing slug and suggest `<slug>-2`.

Always read before writing. Treat daily notes and session logs as append-only. Decision files are create-only.

If required content is missing, ask the user for the smallest missing detail. For example, a decision needs at least the decision text or enough session context to draft it accurately.

## Failure Modes

- Missing vault config: stop and tell the user how to configure it.
- Missing project: list available projects and stop.
- Missing project `index.md`: warn, then continue with a shallow project file listing.
- Existing decision slug: refuse overwrite and suggest a new slug.
- Path traversal or target outside vault root: refuse.
- Missing vault `CLAUDE.md`: offer bootstrap, otherwise stop.

