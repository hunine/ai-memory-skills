# Smoke Test — agentic-second-brain v1

Manual checklist run in Claude Code after `./install.sh --vault $(pwd)/tests/fixtures/vault`.

Each step lists the input and the assertion. Run in a single Claude Code session unless noted.

## Setup

```bash
./install.sh --vault "$(pwd)/tests/fixtures/vault"
```

Expected: config written, vault CLAUDE.md untouched (fixture already has one), symlinks present, SessionEnd hook in `~/.claude/settings.json`.

## 1. Phase 1 read — exact match

Input: `/agentic-second-brain:get-knowledge todo-app`

Assertions:
- Skill loads `Projects/todo-app/index.md`.
- Lists `[[Auth Strategy]]` and `[[Onboarding Flow]]` as known wiki-links.
- Surfaces today's daily note (`Inbox/2026-05-04.md`) capture.
- Surfaces `needs-review-todo-app` note.
- Surfaces last session summary (`2026-05-03-15.md`).
- Lists `auth-existing.md` filename in `decisions/` but does NOT read its content.

## 2. Phase 2 follow-up — wiki-link navigation

Input (same conversation): "what's the auth strategy?"

Assertions:
- Skill resolves `[[Auth Strategy]]` from the nav map.
- Reads `Notes/Auth Strategy.md`.
- Answers about JWT vs cookies and rotation cadence question.

## 3. save-memory inbox

Input: `/agentic-second-brain:save-memory inbox "smoke test capture"`

Assertions:
- `Inbox/<today>.md` has a new entry containing "smoke test capture".
- Existing content preserved.

## 4. save-memory smart save

Input: `/agentic-second-brain:save-memory todo`

Assertions:
- Resolves alias `todo` to `todo-app`.
- Writes or appends `AI/session/<today-hour>.md`.
- Writes a decision or research note only if the conversation contains clear decision/research content.
- If the knowledge is unclear or conflicting, asks for clarification before saving it as inbox, decision, or research memory.
- If project-scoped content is present but ambiguous, asks for the smallest missing detail instead of guessing.

## 5. save-memory decision (new slug)

Input: `/agentic-second-brain:save-memory decision todo-app auth-jwt`

Assertions:
- `Projects/todo-app/decisions/auth-jwt.md` created.
- Frontmatter populated per vault CLAUDE.md schema (`title`, `date`, `tags`, `status`, `project`, `processed`, `related`).
- Body contains `#decision` tag.

## 6. save-memory decision (collision)

Input: `/agentic-second-brain:save-memory decision todo-app auth-jwt`

Assertions:
- Skill refuses to overwrite.
- Suggests `auth-jwt-2`.
- File from step 4 unchanged.

## 7. Case-insensitive project match

Input: `/agentic-second-brain:get-knowledge TODO-APP`

Assertions:
- Matches `todo-app` (case-folded).
- Behaves identically to step 1.

## 8. Case-insensitive alias match

Input: `/agentic-second-brain:get-knowledge TODO`

Assertions:
- Matches alias `todo` from `Projects/todo-app/index.md`.
- Behaves identically to step 1.

## 9. Ambiguous prefix is not a match

Input: `/agentic-second-brain:get-knowledge tod`

Assertions:
- Skill returns "no project matches `tod`" (no partial / prefix matching).
- Lists available projects: `todo-app`, `Todo-App-Mobile`.
- Does NOT load any project.

## 10. SessionEnd auto-save

Action: `/exit` from Claude Code.

Assertions:
- `tests/fixtures/vault/AI/session/<today-hour>.md` created.
- Contains the four sections from the Agent Output Format.

## 11. Same-hour collision append

Action: open a new Claude Code session in the same hour, do trivial work, `/exit`.

Assertions:
- Same `<today-hour>.md` file gains a `## Continued` section.
- Original content untouched.

## 12. Cleanup

```bash
./install.sh --uninstall
```

Assertions:
- Symlinks gone.
- Hook entry removed from settings.json.
- Config and vault contents untouched.
