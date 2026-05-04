---
description: Load Obsidian vault context for a project (index, daily note, needs-review, recent sessions)
argument-hint: <project-folder-name>
---

Invoke the `agentic-second-brain` skill: `get-knowledge` for project "$ARGUMENTS".

Follow the skill's `get-knowledge` flow exactly:

1. Run the boot sequence (resolve vault path, read vault CLAUDE.md).
2. Match `$ARGUMENTS` case-insensitively against `<vault>/Projects/*` directory names.
3. On no match, list available projects and stop.
4. On match, run Phase 1 — load `index.md`, parse wiki-links into a nav map, pull active surface (today's daily, `#needs-review`, open `#action`, last 2 sessions, list decisions/research filenames).
5. Return a structured summary. Do not deep-read decisions or research files yet — wait for follow-up questions and use the nav map.
