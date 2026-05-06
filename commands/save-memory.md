---
description: Write to Obsidian vault — smart save, inbox append, session log, decision, or research note
argument-hint: "[kind: inbox|session|decision|research] [project-or-alias] [args]"
---

Invoke the `agentic-second-brain` skill: `save-memory` with arguments "$ARGUMENTS".

Parse `$ARGUMENTS` as either `<kind> [args]`, `<project-or-alias>`, or empty arguments. The kind words `inbox`, `session`, `decision`, and `research` are reserved and must be parsed as kinds, not project aliases.

When arguments are empty or only a project/alias is supplied, run the skill's smart save behavior:
- Always save a session log.
- Also save inbox, decision, or research notes when the current chat context clearly calls for them.
- If any knowledge is unclear, conflicting, or underspecified, ask the user to clarify before saving it as inbox, decision, or research memory.
- Resolve project names and aliases using the skill's Project Resolution rules before writing project-scoped notes.

- `inbox <text>` → append `<text>` to `<vault>/Inbox/<today>.md` (create from vault CLAUDE.md template if missing).
- `session` → write `<vault>/AI/session/<YYYY-MM-DD-HH>.md` using the Agent Output Format from vault CLAUDE.md. If file exists for this hour, append `## Continued`.
- `decision <project> <slug>` → write `<vault>/Projects/<project>/decisions/<slug>.md` with `#decision` tag and full frontmatter. Refuse to overwrite existing slug; suggest `<slug>-2`.
- `research <project> <slug>` → create or append `<vault>/Projects/<project>/research/<slug>.md` with `#research` tag. Append a timestamped update when the file exists.

Always run the boot sequence first. Refuse on path traversal, missing vault, ambiguous alias, or overwrite of an existing decision slug.
