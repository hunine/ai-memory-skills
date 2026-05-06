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
- `#research` — synthesized project knowledge or investigation results
- `#action` — a task or follow-up

**Linking:** use `[[Note Title]]` wiki-links. Prefer linking to project index notes (`/Projects/<name>/index.md`) rather than deeply nested files.

## Working with Projects

Each active project lives under `/Projects/<project-name>/`:

- `index.md` — overview, status, links to key decisions and resources
- `decisions/` — one file per major decision, tagged `#decision`
- `research/` — synthesized notes (raw captures go to `/Inbox` first)

Project `index.md` files may declare aliases in frontmatter so agents can resolve short names case-insensitively:

```yaml
aliases:
  - short-name
  - team shorthand
```

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
