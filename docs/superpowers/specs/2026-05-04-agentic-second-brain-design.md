# Agentic Second Brain — Claude Code Skill (v1) Design Spec

**Date:** 2026-05-04
**Status:** Approved (awaiting user review of written spec)
**Scope:** v1 ships for Claude Code only. Cursor / opencode / codex ports are follow-up specs.

## 1. Goal

Package the user's Obsidian vault ("Agentic Second Brain") as an installable Claude Code plugin that exposes two operations to AI agents:

1. **`get-knowledge <project>`** — load project context from the vault on demand.
2. **`save-memory <kind> [args]`** — write structured notes back to the vault (inbox, session log, decision record).

The vault's own `CLAUDE.md` is the runtime source of truth for note schema, tags, scopes, and session protocol. The skill reads it at runtime and obeys it; users evolve their conventions without re-releasing the skill.

## 2. Non-Goals (v1)

- No Cursor, opencode, or codex distribution. Future spec.
- No automated agent test harness. Manual smoke checklist only.
- No CLI binary. No Node/Python runtime. Pure markdown skill body using built-in agent tools.
- No fuzzy / prefix project name matching. Exact case-insensitive only.
- No multi-vault routing. Single configured vault per machine in v1.

## 3. Repository Layout

```
ai-memory-skills/
├── CLAUDE.md                              # this repo's agent guide
├── README.md                              # install + usage docs
├── .claude-plugin/
│   └── plugin.json                        # Claude Code plugin manifest
├── skills/
│   └── agentic-second-brain/
│       └── SKILL.md                       # auto-trigger skill body — single source of truth
├── commands/
│   ├── get-knowledge.md                   # /agentic-second-brain:get-knowledge
│   └── save-memory.md                     # /agentic-second-brain:save-memory
├── hooks/
│   └── session-end-save.md                # body invoked by SessionEnd hook
├── templates/
│   └── vault-CLAUDE.md                    # starter vault CLAUDE.md (copied on bootstrap)
├── install.sh                             # non-plugin install path
├── tests/
│   ├── install.bats                       # bash test harness for install.sh
│   ├── SMOKE.md                           # manual smoke test checklist
│   └── fixtures/
│       └── vault/                         # fixture Obsidian vault for smoke tests
└── docs/
    └── superpowers/
        └── specs/
            └── 2026-05-04-agentic-second-brain-design.md
```

**Single source of truth:** `skills/agentic-second-brain/SKILL.md` holds operational logic. `commands/*.md` are thin wrappers that delegate to the skill body — they exist only because Claude Code's slash command and skill systems are separate registration surfaces.

## 4. Skill Behavior

### 4.1 Boot sequence (every invocation)

1. **Resolve vault path:**
   - `$AGENTIC_SECOND_BRAIN_VAULT` if set → use.
   - Else read `~/.config/agentic-second-brain/config.json` (`vault_path` key).
   - Else error loud: "Vault not configured. Run `install.sh` or set `AGENTIC_SECOND_BRAIN_VAULT`."
2. **Read `<vault>/CLAUDE.md`.** Missing → offer to copy `templates/vault-CLAUDE.md` into vault root. Refuse to proceed if declined.
3. **Inject vault `CLAUDE.md` content** into agent context as authoritative schema (frontmatter, tags, scopes, session protocol). No caching across calls — re-read each invocation so user edits take effect immediately.

### 4.2 `get-knowledge <project>` — two-phase read

**Phase 1 — initial call, load active surface:**

1. Glob `<vault>/Projects/*` directories. Match `<project>` case-insensitively against directory names.
2. No match → list available projects, exit.
3. Match → load in this order:
   - `<vault>/Projects/<match>/index.md` (the menu).
   - Parse all wiki-links `[[...]]` from `index.md`. Build navigation map (link target → file path candidates) and hold in agent context.
   - `<vault>/Inbox/<today>.md` (today's daily note, if exists).
   - Grep `#needs-review` across vault, filter to notes whose frontmatter `project:` field references `<match>` or whose body wiki-links the project.
   - Open `#action` items linking to project (same filter).
   - Last 2 `<vault>/AI/session/*.md` mentioning `<match>` (filename or content).
   - List filenames (no content) of `<vault>/Projects/<match>/decisions/` and `<vault>/Projects/<match>/research/`.
4. Return structured summary: project status from index, open actions, pending reviews, last-session continuity.

**Phase 2 — follow-up navigation:**

- User asks about specific business area in same conversation.
- Agent looks up matching wiki-link in navigation map from Phase 1.
- Resolve wiki-link to vault file path:
  - `[[Auth Strategy]]` → search `<vault>/Projects/<match>/**/Auth Strategy.md` first, then vault-wide.
  - Honor Obsidian shortest-path resolution.
- Read that file. Recurse into its outbound wiki-links only if user pushes deeper.
- Do **not** re-glob the project. Index is the directory.

**Index hygiene assumption:** project's `index.md` keeps wiki-links current. If a file isn't linked from index, agent falls back to Glob — but skill body warns user to maintain the index.

### 4.3 `save-memory <kind> [args]`

| Kind | Target | Behavior |
| --- | --- | --- |
| `inbox <text>` | `<vault>/Inbox/<today>.md` | Append. Create from template if missing (frontmatter from vault CLAUDE.md). |
| `session` | `<vault>/AI/session/<YYYY-MM-DD-HH>.md` | Write using "Agent Output Format" from vault CLAUDE.md. If file exists for hour → append `## Continued` block, never overwrite. |
| `decision <project> <slug>` | `<vault>/Projects/<project>/decisions/<slug>.md` | Write with `#decision` tag and full frontmatter. Refuse to overwrite existing slug; suggest `<slug>-2`. |

**Idempotency rules:**

- All writes use Read-then-Write (no blind overwrite).
- Daily note + session log → append-only.
- Decision file → refuse to overwrite.

### 4.4 Failure modes (loud, no silent fallbacks)

- Vault path missing → error with fix command.
- Vault CLAUDE.md missing → offer bootstrap, refuse otherwise.
- Project not found → list available projects.
- Write target outside vault root → refuse (path traversal guard via `realpath` prefix check).

## 5. Plugin Manifest

`.claude-plugin/plugin.json`:

```json
{
  "name": "agentic-second-brain",
  "version": "0.1.0",
  "description": "Obsidian vault as project-aware memory for AI agents — read project context and write structured session/decision/inbox notes back to your vault.",
  "author": "<github-handle-or-display-name>",
  "skills": ["skills/agentic-second-brain"],
  "commands": ["commands/get-knowledge.md", "commands/save-memory.md"],
  "hooks": {
    "SessionEnd": [
      { "matcher": "*", "command": "hooks/session-end-save.md" }
    ]
  }
}
```

Plugin install path handles symlinks, slash command registration, and hook injection automatically. Users opting out of the auto-session log disable via `/plugin disable` or remove the hook block from their `~/.claude/settings.json`.

## 6. Slash Commands

Both files are thin delegates to the skill body. Logic lives in `SKILL.md`.

`commands/get-knowledge.md`:

```markdown
---
description: Load Obsidian vault context for a project (index, daily note, needs-review, recent sessions)
argument-hint: <project-folder-name>
---

Invoke the agentic-second-brain skill with: get-knowledge for project "$ARGUMENTS".
Follow the skill's get-knowledge flow exactly. Resolve vault path from config first.
On no project match, list available projects and stop.
```

`commands/save-memory.md`:

```markdown
---
description: Write to Obsidian vault — inbox append, session log, or decision record
argument-hint: <kind: inbox|session|decision> [args]
---

Invoke the agentic-second-brain skill with: save-memory kind "$ARGUMENTS".

Parse $ARGUMENTS:
- "inbox <text>" → append to today's daily note
- "session" → write /AI/session/<YYYY-MM-DD-HH>.md
- "decision <project> <slug>" → write project decision file

Follow skill's save-memory flow. Refuse on path traversal, missing vault, or overwrite of existing decision slug.
```

## 7. SessionEnd Hook

`hooks/session-end-save.md` body:

```markdown
SessionEnd hook for agentic-second-brain.

1. Resolve vault path (env → config). If missing, exit 0 silently — never block exit.
2. If transcript has no user/assistant messages since last session log, exit 0.
3. Invoke skill: save-memory session.
4. Use the "Agent Output Format" template from vault CLAUDE.md (Session Summary, Actions Taken, Notes Processed, Open Items).
5. Populate from current session transcript:
   - Session Summary: 2-3 sentences of what was accomplished.
   - Actions Taken: file edits, commands run, decisions made.
   - Notes Processed: any /Inbox notes touched.
   - Open Items: unresolved threads, follow-ups.
6. Write file. On write failure, log to stderr, exit 0 (do not block exit).
```

**Failure policy — never block session exit:**

- Vault unconfigured → exit silently.
- Vault unreachable → log to stderr, exit 0.
- Empty transcript → skip write, exit 0.
- Hour-file collision → append `## Continued`, never overwrite.

**Opt-out:** `/plugin disable agentic-second-brain`, or edit `~/.claude/settings.json`, or `install.sh --no-auto-session` flag.

## 8. `install.sh` (non-plugin path)

```
./install.sh [--vault <path>] [--no-auto-session] [--target claude-code|cursor|all] [--uninstall] [--reset-config]
```

**Flow:**

1. Detect agent target. v1: only `claude-code` supported; others stub-error.
2. Resolve vault path: `--vault` flag → env var → prompt. Validate dir exists.
3. Write `~/.config/agentic-second-brain/config.json` (`{ "vault_path": ..., "version": "0.1.0" }`). `mkdir -p` parent. `chmod 600`.
4. Bootstrap vault `CLAUDE.md` if missing — prompt to copy `templates/vault-CLAUDE.md`. Never overwrite existing.
5. Install skill files (symlinks, not copies, so `git pull` updates skill body):
   - `skills/agentic-second-brain/` → `~/.claude/skills/agentic-second-brain/`
   - `commands/get-knowledge.md` → `~/.claude/commands/agentic-second-brain/get-knowledge.md`
   - `commands/save-memory.md` → `~/.claude/commands/agentic-second-brain/save-memory.md`
6. Inject SessionEnd hook into `~/.claude/settings.json` via `jq` merge (idempotent — marker comment dedupe). Skip if `--no-auto-session`. Loud error if `jq` missing with install hint.
7. Print summary: vault path, install location, hook status.

**Uninstall:** `--uninstall` removes symlinks + hook entry. Leaves config + vault untouched.

**Idempotency:** safe to re-run — symlinks recreated, config preserved (`--reset-config` overwrites), hook deduped via marker.

## 9. Testing

### 9.1 `install.sh` — bash test harness (`tests/install.bats`)

Fixture: temp `$HOME` with empty `~/.claude/`, fake vault dir.

Cases:

- Fresh install end-to-end.
- Repeat install is idempotent (no duplicate hook entries).
- `--vault` flag bypasses prompt.
- `$AGENTIC_SECOND_BRAIN_VAULT` env bypasses prompt.
- Missing vault path → prompt path mocked → file written.
- `--no-auto-session` skips hook injection.
- `--uninstall` removes symlinks and hook entry, preserves config.
- Missing `jq` errors loud with install hint.
- Vault CLAUDE.md present → not overwritten on bootstrap.
- Vault CLAUDE.md missing + decline bootstrap → loud message, no file copied.

Assertions: config file written and chmod 600, symlinks exist and point at repo, `~/.claude/settings.json` contains hook entry exactly once.

### 9.2 Skill behavior — manual smoke checklist (`tests/SMOKE.md`)

Fixture vault under `tests/fixtures/vault/` with: `CLAUDE.md`, `Projects/praio/index.md` (with wiki-links to `[[Auth Strategy]]`, `[[Onboarding]]`), `Projects/Praio-Mobile/index.md`, `Inbox/<today>.md`, `AI/session/<recent>.md`, a `#needs-review` note linking `praio`.

Steps:

1. `/agentic-second-brain:get-knowledge praio` → loads index, lists open actions, surfaces needs-review note, lists decisions/research filenames without content. Holds nav map in context.
2. Follow-up "what's the auth strategy" → agent navigates `[[Auth Strategy]]` from nav map, reads file, answers.
3. `/agentic-second-brain:save-memory inbox "test capture"` → appends to today's daily note with timestamp.
4. `/agentic-second-brain:save-memory decision praio auth-jwt` → writes `Projects/praio/decisions/auth-jwt.md` with `#decision` tag and frontmatter populated from vault CLAUDE.md schema.
5. Re-run same decision slug → refuses, suggests `auth-jwt-2`.
6. `/agentic-second-brain:get-knowledge PRAIO` → matches `praio` (case-insensitive).
7. `/agentic-second-brain:get-knowledge pra` → no exact match. Lists `praio`, `Praio-Mobile`. No partial match.
8. `/exit` → SessionEnd hook fires → `AI/session/<today-hour>.md` written with full template structure.
9. Run another short session same hour → `## Continued` block appended, original content preserved.

No automated agent harness in v1.

## 10. Error & Edge-Case Matrix

| Condition | Behavior |
| --- | --- |
| `$AGENTIC_SECOND_BRAIN_VAULT` unset and config missing | Loud error with fix command. No silent default. |
| Vault dir does not exist | Loud error: "Vault path X is not a directory." |
| `<vault>/CLAUDE.md` missing | Offer bootstrap, refuse to proceed if declined. |
| `/Projects/<name>/` not found | Loud error, list available projects (case-folded). |
| `/Projects/<name>/index.md` missing | Warn, fall back to Glob-listing project files. Continue. |
| Wiki-link in index resolves to multiple files | Pick shortest path (Obsidian default), warn user of ambiguity. |
| Wiki-link unresolvable | Skip that link, note in summary. Don't error out the whole call. |
| Decision slug exists | Refuse, suggest `<slug>-2` or prompt for new slug. |
| Daily note hour file exists | Append `## Continued` block. Never overwrite. |
| Path traversal attempt (`../`, absolute path outside vault) | Refuse hard. Log attempt to stderr. |
| SessionEnd hook fails | Log to stderr, exit 0. Never block session exit. |
| `jq` missing during install | Loud error with OS-specific install hint. |
| Vault CLAUDE.md changed schema mid-session | Re-read on next call. No caching across calls. |

## 11. Security

- Config file `chmod 600` (path may reveal personal directory layout).
- Path traversal guard on every write: `realpath` of target must start with `realpath` of vault root.
- Skill never executes vault contents — Read/Write/Glob/Grep only, no `eval`, no shell out.
- No network calls. Plugin operates entirely on local filesystem.
- SessionEnd hook scoped to vault only — does not read or write outside `<vault>/AI/session/`.

## 11.1 Privacy note

`plugin.json`'s `author` field is published with the plugin. v1 uses a placeholder — user replaces with GitHub handle or display name before public release, not personal email.

## 12. Open Questions / Future Work

- **Cursor port:** `.cursor/rules/*.mdc` rule format. Same skill body, different metadata header.
- **opencode / codex ports:** research their plugin formats once primary ships.
- **Multi-vault routing:** v2 — accept `--vault` per-call, profile-based config.
- **Templated note creation:** read `<vault>/Templates/` and let user pick template for `save-memory inbox` and `decision`. v1 uses inline frontmatter from vault CLAUDE.md only.
- **Brand-name alias:** `/asb:` as short prefix once `/agentic-second-brain:` proves long in practice.
- **Automated agent harness:** integrate with Claude Code SDK for replayable behavioral tests once stable.

## 13. Approval Trail

| Decision | Choice | Rationale |
| --- | --- | --- |
| MVP target | Claude Code only | Daily driver, fastest dogfood; SKILL.md becomes source-of-truth for ports. |
| MVP surfaces | Both `get-knowledge` and `save-memory` | Same primitives; building one means 80% of building both. |
| Invocation model | Slash commands + auto-trigger skill | User example used slash syntax; skill layer adds hands-free path. |
| Vault path | Install-time config + env override | Single source of truth, no mid-conversation prompts. |
| Save targets | Inbox, session, decision (all three) | Shared primitives; ship full feature parity. |
| Session log trigger | SessionEnd hook + explicit command | Right event (not Stop, which spams); explicit useful for mid-session flush. |
| Execution model | Pure markdown skill body | Native to Claude Code; zero install footprint; portable to other agents. |
| Read strategy | Index + active surface, two-phase | Matches vault CLAUDE.md Session Start protocol; preserves token budget. |
| Project name match | Case-insensitive exact | Matches macOS / Obsidian default; loud errors beat silent wrong-vault writes. |
| Distribution | Plugin manifest + `install.sh` | Plugin for native UX; script for opt-out and future ports. |
| Plugin name | `agentic-second-brain` | Matches product name. Short alias deferred. |
| Vault CLAUDE.md handling | Required + bootstrap + runtime inject | Single schema source, user controls evolution, no drift. |
