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
