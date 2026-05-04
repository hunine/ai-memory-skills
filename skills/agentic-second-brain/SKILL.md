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
