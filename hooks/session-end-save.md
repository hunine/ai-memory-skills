SessionEnd hook for the agentic-second-brain plugin. Auto-saves the session log when Claude Code exits.

Behavior:

1. Resolve vault path: env var `AGENTIC_SECOND_BRAIN_VAULT` or `~/.config/agentic-second-brain/config.json`. **If unset, exit silently with status 0 — never block session exit.**
2. If the transcript has no user/assistant messages since the last session log, exit 0.
3. Invoke the `agentic-second-brain` skill: `save-memory session`.
4. Use the "Agent Output Format" template from the vault's `CLAUDE.md` (Session Summary, Actions Taken, Notes Processed, Open Items).
5. Populate from the current session transcript:
   - **Session Summary:** 2-3 sentences, what was accomplished.
   - **Actions Taken:** file edits, commands run, decisions made.
   - **Notes Processed:** any `/Inbox` files touched.
   - **Open Items:** unresolved threads, follow-ups.
6. Write to `<vault>/AI/session/<YYYY-MM-DD-HH>.md`. If a file already exists for this hour, append `## Continued` — never overwrite.
7. On any write failure, log to stderr and exit 0. **Never block session exit.**
