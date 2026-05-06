---
name: agentic-second-brain
description: Use when the user asks Codex to load project context from an Obsidian vault, save memory from the current chat, save a session log, capture an inbox note, record a project decision or research note, or says phrases like "load X project", "save memory for X", "save this session", "log a decision", "save to inbox", or "what does my vault know about X". Reads structured project knowledge from a configured vault and writes back according to the vault's own CLAUDE.md conventions.
---

# Agentic Second Brain

Connect Codex to the user's Obsidian vault. Support two operations: `get-knowledge <project-or-alias>` and `save-memory [kind] [args]`.

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

## Operation: `get-knowledge <project-or-alias>`

Phase 1 loads the active project surface:

1. Resolve `<project-or-alias>` with Project Resolution.
2. If no match, list available projects and aliases, then stop. If multiple matches exist, list candidates and stop.
3. Read `<vault>/Projects/<match>/index.md` first. Parse its wiki-links into a navigation map for follow-up questions.
4. Read today's daily note at `<vault>/Inbox/YYYY-MM-DD.md` if present.
5. Find notes tagged `#needs-review` or `#action` that belong to the project, using YAML `project:` or body wiki-links to the project as the filter.
6. Read the latest two files in `<vault>/AI/session/` whose filename or body mentions the project.
7. List filenames only from `<vault>/Projects/<match>/decisions/` and `<vault>/Projects/<match>/research/`.

Return a concise summary with project status, open actions, pending review notes, recent-session continuity, and the available decision/research filenames.

For follow-up questions in the same conversation, use the wiki-link navigation map from `index.md` first. Resolve matching wiki-links under the project before searching vault-wide. If multiple files match, choose the shortest Obsidian-style path and warn about ambiguity.

## Project Resolution

Use this for every project argument, including `get-knowledge`, `save-memory decision`, `save-memory research`, and smart saves with a project hint.

1. List `<vault>/Projects/*` directories.
2. Match the supplied project text against directory names by exact, case-insensitive match.
3. If no directory matches, read each project's `index.md` frontmatter only and match exact, case-insensitive aliases from `aliases: [short-name]` or `alias: short-name`.
4. If one alias matches, use that directory as the canonical project name.
5. If multiple aliases match, stop and list candidates. Do not guess.
6. If no alias matches, list available canonical project names and aliases, then stop.

Do not use prefix, substring, or fuzzy matching. Aliases must be declared in project metadata.

## Operation: `save-memory [kind] [args]`

If the user says only `save-memory`, `save memory`, `save this`, or `save-memory <project-or-alias>` without a kind, run a smart save. The kind words `inbox`, `session`, `decision`, and `research` are reserved and must be parsed as kinds, not project aliases.

1. Resolve the optional project hint through Project Resolution. If no hint was provided, use the latest project loaded in this conversation only when unambiguous.
2. Analyze the current chat/session context and identify any unclear, conflicting, or underspecified knowledge before choosing durable write targets.
   - If the agent is confused about meaning, project, decision outcome, source, confidence, or where the knowledge belongs, ask the user to clarify before saving that knowledge to inbox, decision, or research notes.
   - Do not turn uncertain content into durable memory as fact. If needed, write only the session log with an open item that clarification is pending.
3. Choose the needed write targets:
   - Always write a session log to `<vault>/AI/session/YYYY-MM-DD-HH.md`.
   - Use `inbox` for raw captures, partial thoughts, or information that should be reviewed before filing.
   - Use `decision` only when the conversation contains a clear project decision: context, considered options or tradeoff, and chosen outcome.
   - Use `research` when the conversation contains synthesized project knowledge, investigation results, implementation notes, or findings that should become durable project reference material.
4. Before writing decision or research notes, resolve the project. If no project can be determined safely, write the session log and ask for the smallest missing project/detail instead of guessing.
5. For each selected target, read before writing and follow the target-specific rules below.

Supported kinds:

- `inbox <text>`: append the text to `<vault>/Inbox/YYYY-MM-DD.md` under a timestamped heading. Create the daily note if missing using the frontmatter conventions from `<vault>/CLAUDE.md`.
- `session`: write `<vault>/AI/session/YYYY-MM-DD-HH.md` using the session output format from `<vault>/CLAUDE.md`. If the current-hour file exists, append `## Continued`; never overwrite.
- `decision <project> <slug>`: create `<vault>/Projects/<project>/decisions/<slug>.md` with the vault-declared frontmatter and `#decision` tag. Refuse to overwrite an existing slug and suggest `<slug>-2`.
- `research <project> <slug>`: create or append `<vault>/Projects/<project>/research/<slug>.md` with the vault-declared frontmatter and `#research` tag. If the slug exists, append a timestamped update section; never overwrite.

Always read before writing. Treat daily notes, session logs, and existing research notes as append-only. Decision files are create-only.

If required content is missing, ask the user for the smallest missing detail. For example, a decision needs at least the decision text or enough session context to draft it accurately.

## Failure Modes

- Missing vault config: stop and tell the user how to configure it.
- Missing project: list available projects and stop.
- Ambiguous project alias: list matching projects and stop.
- Missing project `index.md`: warn, then continue with a shallow project file listing.
- Existing decision slug: refuse overwrite and suggest a new slug.
- Path traversal or target outside vault root: refuse.
- Missing vault `CLAUDE.md`: offer bootstrap, otherwise stop.
