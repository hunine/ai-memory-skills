# agentic-second-brain

Bridge an AI coding agent (Claude Code or Codex) to your Obsidian vault. Read project context on demand. Write structured session logs, inbox notes, and decision records back to the vault — all per the schema your vault's own `CLAUDE.md` declares.

## What This Is

- Two operations: `get-knowledge <project-or-alias>` and `save-memory [kind] [args]`.
- Pure markdown skill — no runtime, no CLI binary. Agent-specific packages provide Claude Code and Codex variants.
- Vault is the source of truth. Edit `<vault>/CLAUDE.md` to change conventions; the skill picks it up next call.
- Auto session log via Claude Code SessionEnd hook (opt-out at install time). Codex currently uses explicit `save-memory session`.

## Install

### Option A — Claude Code plugin

Recommended for Claude Code users.

```bash
# in your Claude Code session
/plugin install <this-repo-url>
```

This registers the skill, the slash commands, and the SessionEnd hook automatically. You will still need to point the plugin at your vault — see "Configure Vault Path" below.

### Option B — Codex skill

Install the Codex variant into `~/.codex/skills`:

```bash
git clone <this-repo-url> ~/code/ai-memory-skills
cd ~/code/ai-memory-skills
./install.sh --target codex --vault /path/to/your/obsidian-vault
```

Then invoke it by asking Codex naturally, for example:

```text
Use $agentic-second-brain to load todo-app context.
Use $agentic-second-brain to save this session.
Use $agentic-second-brain to save memory for todo.
```

The Codex plugin manifest lives at `.codex-plugin/plugin.json`, and the Codex skill body lives at `codex/skills/agentic-second-brain/SKILL.md`.

### Option C — `install.sh`

For manual installs, dotfile setups, or installing multiple supported agents.

```bash
git clone <this-repo-url> ~/code/ai-memory-skills
cd ~/code/ai-memory-skills
./install.sh --vault /path/to/your/obsidian-vault
```

Flags:
- `--vault <path>` — path to your Obsidian vault.
- `--no-auto-session` — skip the Claude Code SessionEnd hook.
- `--target <agent>` — `claude-code` (default), `codex`, or `all`.
- `--reset-config` — overwrite an existing config file.
- `--uninstall` — remove target symlinks and any Claude hook entry; preserves config and vault.
- `--help` — show usage.

The script:
1. Resolves the vault path (`--vault` → `$AGENTIC_SECOND_BRAIN_VAULT` → prompt).
2. Writes `~/.config/agentic-second-brain/config.json` with permissions 600.
3. Offers to copy `templates/vault-CLAUDE.md` into your vault if it has no `CLAUDE.md` (never overwrites).
4. Symlinks the selected agent assets:
   - Claude Code: skill body and slash commands into `~/.claude/`.
   - Codex: Codex skill body into `~/.codex/skills/`.
5. Injects a Claude Code SessionEnd hook into `~/.claude/settings.json` when installing Claude Code (skip with `--no-auto-session`).

## Configure Vault Path

The skill resolves the vault path in this order:

1. `$AGENTIC_SECOND_BRAIN_VAULT` environment variable.
2. `~/.config/agentic-second-brain/config.json` (`vault_path` key).

`install.sh` writes the config file. The env var is for power users / multi-vault overrides.

## Usage

```
/agentic-second-brain:get-knowledge <project-or-alias>
```

Loads `<vault>/Projects/<project>/index.md`, today's daily note, `#needs-review` notes, recent session logs, and lists decision and research filenames. Project resolution first checks exact case-insensitive folder names, then exact case-insensitive aliases declared in project `index.md` frontmatter as `aliases` or `alias`. Holds the index's wiki-links as a navigation map for follow-up questions.

```
/agentic-second-brain:save-memory
/agentic-second-brain:save-memory <project-or-alias>
/agentic-second-brain:save-memory inbox "<text>"
/agentic-second-brain:save-memory session
/agentic-second-brain:save-memory decision <project> <slug>
/agentic-second-brain:save-memory research <project> <slug>
```

Writes to your vault per the schema in `<vault>/CLAUDE.md`. Bare `save-memory` performs a smart save: it always writes a session log, then also writes inbox, decision, or research notes when the current chat context clearly calls for them. If knowledge is unclear or conflicting, the agent asks for clarification before saving it as durable memory. Append-only for daily notes, session logs, and existing research notes. Refuses to overwrite an existing decision slug.

The skill also auto-triggers when you say things like "load todo-app context" or "save this session" — no slash command required.

For Codex, prefer explicit skill invocation when you want reliable routing:

```text
Use $agentic-second-brain to load todo-app context.
Use $agentic-second-brain to save this session.
Use $agentic-second-brain to save memory for todo.
Use $agentic-second-brain to capture this decision.
```

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

Use `--target codex --uninstall` for only the Codex symlink, or `--target all --uninstall` for both Claude Code and Codex symlinks. If installed via the Claude plugin route, `/plugin disable agentic-second-brain`.

Vault contents and config file are preserved. Delete `~/.config/agentic-second-brain/config.json` manually if you want a fully clean slate.

## Tests

```bash
bats tests/install.bats
```

Manual smoke checklist for skill behavior: `tests/SMOKE.md`.

## License

TBD.
