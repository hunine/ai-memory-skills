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

The skill also auto-triggers when you say things like "load todo-app context" or "save this session" — no slash command required.

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
